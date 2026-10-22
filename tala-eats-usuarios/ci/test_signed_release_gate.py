"""No Flutter, Java, secrets or live services. CI-only signing safeguards."""
from pathlib import Path
import os
import importlib.util
import tempfile
import zipfile
import subprocess
import struct
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "ci/build_signed_play_bundle.py"

class PlayReleaseGateTest(unittest.TestCase):
    def test_preflight_verifies_package_and_version_without_credentials(self):
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), "--check"],
            cwd=ROOT / "app", capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertIn("RELEASE_SOURCE_GATE_PASS", completed.stdout)

    def test_missing_release_credentials_must_fail_without_building(self):
        env = os.environ.copy()
        for name in (
            "TALAEATS_UPLOAD_KEYSTORE",
            "TALAEATS_UPLOAD_STORE_PASSWORD",
            "TALAEATS_UPLOAD_KEY_ALIAS",
            "TALAEATS_UPLOAD_KEY_PASSWORD",
            "TALAEATS_FCM_API_KEY",
            "TALAEATS_FCM_APP_ID",
            "TALAEATS_FCM_SENDER_ID",
            "TALAEATS_FCM_PROJECT_ID",
        ):
            env.pop(name, None)
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--build"],
            cwd=ROOT / "app", capture_output=True, text=True, env=env)
        self.assertEqual(result.returncode, 2)
        self.assertIn("RELEASE_BLOCKED", result.stderr)
        self.assertIn("Faltan variables locales", result.stderr)
        self.assertFalse((ROOT / "app/android/app/build.gradle.kts").exists(),
                         "Sin secretos no debe generar ni modificar Android.")

    def test_build_refuses_missing_original_brand_media(self):
        script = SCRIPT.read_text(encoding="utf-8")
        self.assertIn('ci/verify_landing_assets.py', script)

    def test_aab_zip_structure_rejects_fake_apk_and_missing_arm64(self):
        spec = importlib.util.spec_from_file_location("tala_play_bundle", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "app-release.aab"
            path.write_bytes(b"not-an-aab")
            with self.assertRaisesRegex(RuntimeError, "AAB ZIP"):
                module.verify_aab_structure(path)

            with zipfile.ZipFile(path, "w") as out:
                out.writestr("BundleConfig.pb", b"config")
                out.writestr("base/manifest/AndroidManifest.xml", b"manifest")
                out.writestr("base/assets/flutter_assets/AssetManifest.bin", b"asset")
            with self.assertRaisesRegex(RuntimeError, "ARM64"):
                module.verify_aab_structure(path)

            with zipfile.ZipFile(path, "a") as out:
                out.writestr("base/lib/arm64-v8a/libapp.so", b"fake-so-for-structure-test")
            module.verify_aab_structure(path)

    def test_arm64_elf_load_segments_require_16kb_alignment(self):
        spec = importlib.util.spec_from_file_location("tala_play_bundle", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        def fixture(align):
            elf = bytearray(128)
            elf[:4] = bytes((127, 69, 76, 70))  # ELF magic
            elf[4] = 2  # ELF64
            elf[5] = 1  # little endian
            struct.pack_into("<Q", elf, 32, 64)  # e_phoff
            struct.pack_into("<H", elf, 54, 56)  # e_phentsize
            struct.pack_into("<H", elf, 56, 1)   # e_phnum
            struct.pack_into("<I", elf, 64, 1)   # PT_LOAD
            struct.pack_into("<Q", elf, 112, align)
            return elf

        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "app-release.aab"
            with zipfile.ZipFile(path, "w") as out:
                out.writestr("base/lib/arm64-v8a/libapp.so", fixture(4096))
            with self.assertRaisesRegex(RuntimeError, "16 KB"):
                module.verify_arm64_native_alignment(path)
            with zipfile.ZipFile(path, "w") as out:
                out.writestr("base/lib/arm64-v8a/libapp.so", fixture(16384))
            module.verify_arm64_native_alignment(path)

    def test_flutter_path_resolution_exposes_missing_binary_and_uses_resolved_shim(self):
        spec = importlib.util.spec_from_file_location("tala_play_bundle", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        shim = r"C:\\flutter\\bin\\flutter.bat"
        with mock.patch.object(module.shutil, "which", return_value=shim):
            self.assertEqual(module.locate_flutter(), shim)
        with mock.patch.object(module.shutil, "which", return_value=None):
            with self.assertRaisesRegex(RuntimeError, "Flutter en PATH"):
                module.locate_flutter()
        build = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("subprocess.run([flutter_exe, \"pub\", \"get\"]", build)
        self.assertIn("cmd = [flutter_exe, \"build\", \"appbundle\"", build)

    def test_release_build_always_removes_stale_output(self):
        source = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("BUNDLE.unlink()", source)
        self.assertIn("verify_aab_structure(BUNDLE)", source)

    def test_preflight_blocks_private_pkcs12_inside_repository(self):
        source = SCRIPT.read_text(encoding="utf-8")
        for extension in (".p12", ".pfx", ".pkcs12", ".jks", ".keystore"):
            self.assertIn(extension, source)
        self.assertIn("No guardar claves en el repositorio", source)

    def test_release_signing_must_not_fallback_to_debug(self):
        text = SCRIPT.read_text(encoding="utf-8")
        self.assertIn('signingConfigs.getByName("talaUpload")', text)
        self.assertIn('jarsigner", "-verify"', text)
        self.assertIn('"targetSdk = 36"', text)
        self.assertIn('"compileSdk = 36"', text)
        self.assertIn('RELEASE_BLOCKED', text)

if __name__ == "__main__":
    unittest.main()
