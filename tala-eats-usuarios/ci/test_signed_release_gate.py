"""No Flutter, Java, secrets or live services. CI-only signing safeguards."""
from pathlib import Path
import os
import subprocess
import sys
import unittest

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

    def test_release_signing_must_not_fallback_to_debug(self):
        text = SCRIPT.read_text(encoding="utf-8")
        self.assertIn('signingConfigs.getByName("talaUpload")', text)
        self.assertIn('jarsigner", "-verify"', text)
        self.assertIn('"targetSdk = 36"', text)
        self.assertIn('"compileSdk = 36"', text)
        self.assertIn('RELEASE_BLOCKED', text)

if __name__ == "__main__":
    unittest.main()
