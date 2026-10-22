"""Offline import tests; synthetic fixtures never replace the approved SHA256."""

import hashlib
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import import_original_hd_assets as importer
import verify_landing_assets as gate


def fake_png(transparent: bool) -> bytes:
    # Sufficient signature/IHDR for deterministic contract tests only.
    header = b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR"
    header += struct.pack(">II", 900, 320) + bytes([8, 6 if transparent else 2])
    return header + b"\x00" * 70


def fake_webp() -> bytes:
    body = b"WEBP" + b"VP8 " + b"\x00" * 52
    return b"RIFF" + struct.pack("<I", len(body)) + body


class HDImportTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.files = {
            "food_fiesta.webp": fake_webp(),
            "food_tala.webp": fake_webp() + b"extra",
            "tala_eats_original_wordmark.png": fake_png(False),
            "tala_eats_wordmark_transparent.png": fake_png(True),
        }
        # Adjust riff length on the second fixture.
        file = self.files["food_tala.webp"]
        self.files["food_tala.webp"] = file[:4] + struct.pack("<I", len(file) - 8) + file[8:]
        expected = {name: (hashlib.sha256(value).hexdigest(), 28)
                    for name, value in self.files.items()}
        patch_expect = patch.object(gate, "EXPECTED", expected)
        patch_assets = patch.object(gate, "ASSETS", self.root / "assets")
        patch_expect.start()
        patch_assets.start()
        self.addCleanup(patch_expect.stop)
        self.addCleanup(patch_assets.stop)

    def make_zip(self, names=None) -> Path:
        path = self.root / "official.zip"
        names = names or [(f"originales/{name}", data) for name, data in self.files.items()]
        with zipfile.ZipFile(path, "w") as zip_file:
            for name, data in names:
                zip_file.writestr(name, data)
        return path

    def test_valid_approved_zip_can_be_installed_without_byte_changes(self):
        asset_map = importer.read_approved_media(self.make_zip())
        self.assertEqual(asset_map, self.files)
        self.assertFalse(gate.ASSETS.exists(), "Dry run must never create files")
        importer.install_media(asset_map)
        for name, data in self.files.items():
            self.assertEqual((gate.ASSETS / name).read_bytes(), data)

    def test_tampering_one_byte_prevents_all_asset_writes(self):
        items = list(self.files.items())
        name, data = items[0]
        zip_path = self.make_zip([(f"folder/{name}", data + b"x")] +
                                 [(name, value) for name, value in items[1:]])
        with self.assertRaisesRegex(ValueError, "no coincide|truncado"):
            importer.read_approved_media(zip_path)
        self.assertFalse(gate.ASSETS.exists())

    def test_missing_or_duplicate_file_is_rejected(self):
        items = list(self.files.items())
        with self.assertRaisesRegex(ValueError, "Faltan"):
            importer.read_approved_media(self.make_zip(items[:3]))
        with self.assertRaisesRegex(ValueError, "repetido"):
            importer.read_approved_media(self.make_zip(items + [(f"dup/{items[0][0]}", items[0][1])]))

    def test_zip_slip_and_symlink_entries_are_denied(self):
        items = list(self.files.items())
        path = self.make_zip(items + [("../outside.txt", b"blocked")])
        with self.assertRaisesRegex(ValueError, "ruta insegura"):
            importer.read_approved_media(path)
        path = self.root / "symlink.zip"
        with zipfile.ZipFile(path, "w") as z:
            for name, data in items:
                z.writestr(name, data)
            link = zipfile.ZipInfo("fake-link")
            link.create_system = 3
            link.external_attr = (0o120777 << 16)
            z.writestr(link, b"/tmp/secrets")
        with self.assertRaisesRegex(ValueError, "enlace simbólico"):
            importer.read_approved_media(path)


if __name__ == "__main__":
    unittest.main()
