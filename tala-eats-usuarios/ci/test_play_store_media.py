"""No Pillow required: mock Play PNG inputs for the separate listing gate."""
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

from verify_play_store_media import inspect_listing, png_dimensions


def chunk(kind: bytes, payload: bytes) -> bytes:
    return (struct.pack(">I", len(payload)) + kind + payload +
            struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff))


def make_png(width: int, height: int, *, rgba: bool = False) -> bytes:
    channels = 4 if rgba else 3
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6 if rgba else 2,
                       0, 0, 0)
    row = b"\x00" + b"\x88" * (channels * width)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) +
            chunk(b"IDAT", zlib.compress(row * height, level=6)) +
            chunk(b"IEND", b""))


class PlayStoreMediaGateTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        shots = self.root / "screenshots"
        shots.mkdir()
        (self.root / "icon-512.png").write_bytes(make_png(512, 512, rgba=True))
        (self.root / "feature-1024x500.png").write_bytes(make_png(1024, 500))
        (shots / "01-home.png").write_bytes(make_png(1080, 1920))
        (shots / "02-checkout.png").write_bytes(make_png(1080, 1920))

    def test_correct_real_png_shapes_pass_listing_gate(self):
        self.assertEqual(inspect_listing(self.root), [])

    def test_wrong_feature_size_and_alpha_fail_closed(self):
        path = self.root / "feature-1024x500.png"
        path.write_bytes(make_png(1024, 501, rgba=True))
        errors = inspect_listing(self.root)
        self.assertTrue(any("tamaño requerido" in e for e in errors))
        self.assertTrue(any("sin transparencia" in e for e in errors))

    def test_corrupt_crc_and_missing_capture_fail(self):
        path = self.root / "icon-512.png"
        raw = bytearray(path.read_bytes())
        raw[20] ^= 1
        path.write_bytes(raw)
        (self.root / "screenshots/01-home.png").unlink()
        problems = inspect_listing(self.root)
        self.assertTrue(any("CRC PNG" in e for e in problems))
        self.assertTrue(any("2–8 capturas" in e for e in problems))

    def test_truncated_png_rejected(self):
        path = self.root / "icon-512.png"
        path.write_bytes(path.read_bytes()[:28])
        with self.assertRaises(ValueError):
            png_dimensions(path)


if __name__ == "__main__":
    unittest.main()
