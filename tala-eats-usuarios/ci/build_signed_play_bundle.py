#!/usr/bin/env python3
"""TALA EATS Usuarios: local-only, fail-closed Play App Bundle build.
Never uploads keys or artifacts and never writes release credentials to git.
Usage: python ci/build_signed_play_bundle.py --check
       python ci/build_signed_play_bundle.py --build
"""
from __future__ import annotations
import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "app"
GRADLE = APP / "android/app/build.gradle.kts"
BUNDLE = APP / "build/app/outputs/bundle/release/app-release.aab"
API = 36
PACKAGE = "com.talaeats.app"
PUBLIC_FIREBASE = (
    "TALAEATS_FCM_API_KEY",
    "TALAEATS_FCM_APP_ID",
    "TALAEATS_FCM_SENDER_ID",
    "TALAEATS_FCM_PROJECT_ID",
)
PRIVATE_SIGNING = (
    "TALAEATS_UPLOAD_KEYSTORE",
    "TALAEATS_UPLOAD_STORE_PASSWORD",
    "TALAEATS_UPLOAD_KEY_ALIAS",
    "TALAEATS_UPLOAD_KEY_PASSWORD",
)


def check_source() -> None:
    pubspec = (APP / "pubspec.yaml").read_text(encoding="utf-8")
    assert re.search(r"^version: 1\.0\.41\+52$", pubspec, re.MULTILINE), (
        "La versión de Play RC debe ser 1.0.41+52")
    bootstrap = (ROOT / "ci/bootstrap_android.py").read_text(encoding="utf-8")
    assert "'package':'com.talaeats.app'" in bootstrap, "Paquete Android inesperado"
    assert (APP / "tools/native/MainActivity.java").is_file()
    assert (APP / "lib/customer_native_push.dart").is_file()
    # Reject all common private keystore formats (including Windows PKCS#12).
    forbidden = {".jks", ".keystore", ".p12", ".pfx", ".pkcs12"}
    assert not any(p.is_file() and p.suffix.lower() in forbidden
                   for p in ROOT.rglob("*")), "No guardar claves en el repositorio"
    print("RELEASE_SOURCE_GATE_PASS: v1.0.41+52, paquete com.talaeats.app, sin llaves")


def require_local_configuration() -> Path:
    missing = [k for k in PRIVATE_SIGNING + PUBLIC_FIREBASE if not os.environ.get(k)]
    if missing:
        raise RuntimeError("Faltan variables locales (no imprimir valores): " + ", ".join(missing))
    keystore = Path(os.environ["TALAEATS_UPLOAD_KEYSTORE"]).expanduser().resolve()
    if not keystore.is_file():
        raise RuntimeError("No existe el archivo de clave de subida.")
    if keystore == ROOT or ROOT in keystore.parents or APP in keystore.parents:
        raise RuntimeError("La clave debe permanecer FUERA del repositorio.")
    firebase_project = os.environ["TALAEATS_FCM_PROJECT_ID"]
    firebase_sender = os.environ["TALAEATS_FCM_SENDER_ID"]
    firebase_app = os.environ["TALAEATS_FCM_APP_ID"]
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{3,80}", firebase_project):
        raise RuntimeError("ID de proyecto Firebase inválido.")
    if not re.fullmatch(r"[0-9]{6,25}", firebase_sender):
        raise RuntimeError("Firebase Sender ID inválido.")
    if not re.fullmatch(r"1:[0-9]{6,25}:android:[0-9a-fA-F]+", firebase_app):
        raise RuntimeError("Firebase App ID Android inválido.")
    os.environ["TALAEATS_UPLOAD_KEYSTORE"] = str(keystore)
    # No activate Push just by having public config. Server also requires FCM
    # credential, encryption key, enabled flag and a matching project.
    return keystore


def configure_ephemeral_gradle() -> None:
    if not GRADLE.is_file():
        subprocess.run([
            sys.executable, str(ROOT / "ci/bootstrap_android.py"), "--role", "usuarios"
        ], cwd=APP, check=True)
    raw = GRADLE.read_text(encoding="utf-8")
    if PACKAGE not in raw:
        raise RuntimeError("Application ID diferente de com.talaeats.app")
    if "signingConfig = signingConfigs.getByName(\"talaUpload\")" in raw:
        raise RuntimeError("El gradle ya está parcheado: usar scaffold nuevo")
    replacements = (
        (r"compileSdk\s*=\s*flutter\.compileSdkVersion", "compileSdk = 36"),
        (r"targetSdk\s*=\s*flutter\.targetSdkVersion", "targetSdk = 36"),
        (r"signingConfig\s*=\s*signingConfigs\.getByName\(\"debug\"\)",
         'signingConfig = signingConfigs.getByName("talaUpload")'),
    )
    for regex, replacement in replacements:
        raw, count = re.subn(regex, replacement, raw)
        if count != 1:
            raise RuntimeError("Gradle cambió; abortado antes de firmar: " + regex)
    signer = """
    // Local release only. Credentials are read at build time from the
    // developer's environment; NEVER from git, CI artifacts or gradle.properties.
    signingConfigs {
        create("talaUpload") {
            storeFile = file(System.getenv("TALAEATS_UPLOAD_KEYSTORE")
                ?: error("Falta la clave de subida"))
            storePassword = System.getenv("TALAEATS_UPLOAD_STORE_PASSWORD")
                ?: error("Falta store password")
            keyAlias = System.getenv("TALAEATS_UPLOAD_KEY_ALIAS")
                ?: error("Falta alias")
            keyPassword = System.getenv("TALAEATS_UPLOAD_KEY_PASSWORD")
                ?: error("Falta key password")
        }
    }
"""
    raw, count = re.subn(r"(?m)^    buildTypes\s*\{", signer + "    buildTypes {", raw, count=1)
    if count != 1:
        raise RuntimeError("No se encontró la sección buildTypes")
    if 'signingConfigs.getByName("debug")' in raw:
        raise RuntimeError("No puede publicarse usando firma debug")
    GRADLE.write_text(raw, encoding="utf-8")
    print("ANDROID_RELEASE_GATE_PASS: API 36, firma upload obligatoria")


def verify_aab_structure(path: Path) -> None:
    """Reject misnamed ZIP/APK or incomplete bundles before reporting signature PASS.

    Structural checks do not replace bundletool, Google Play Console, or
    physical testing on devices with 16 KB memory pages.
    """
    try:
        with zipfile.ZipFile(path, "r") as bundle:
            entries = set(bundle.namelist())
            if bundle.testzip() is not None:
                raise RuntimeError("AAB ZIP dañado (CRC inválido)")
    except (zipfile.BadZipFile, OSError) as exc:
        raise RuntimeError("El archivo no es un AAB ZIP válido") from exc
    expected = {"BundleConfig.pb", "base/manifest/AndroidManifest.xml"}
    if not expected.issubset(entries):
        raise RuntimeError("AAB incompleto: faltan manifest o BundleConfig.pb")
    if not any(name.startswith("base/lib/arm64-v8a/") and name.endswith(".so")
               for name in entries):
        raise RuntimeError("AAB sin librerías Android ARM64; revisar Flutter release")
    if not any(name.startswith("base/assets/flutter_assets/") for name in entries):
        raise RuntimeError("AAB sin recursos Flutter; revisar el empaquetado")
    print("ANDROID_APP_BUNDLE_STRUCTURE_PASS: base, manifest, Flutter assets y ARM64")


def verify_arm64_native_alignment(path: Path) -> None:
    """Check AArch64 ELF PT_LOAD alignment; Play/device checks are still required.

    ELF page compatibility is only one 16 KB prerequisite. Google Play's
    generated device APK ZIP alignment and runtime need independent review.
    """
    total = 0
    with zipfile.ZipFile(path, "r") as bundle:
        for name in bundle.namelist():
            if not (name.startswith("base/lib/arm64-v8a/") and name.endswith(".so")):
                continue
            elf = bundle.read(name)
            if (len(elf) < 64 or elf[:4] != b"\x7fELF" or
                elf[4] != 2 or elf[5] != 1):
                raise RuntimeError("ELF ARM64 inválido: " + name)
            phoff = struct.unpack_from("<Q", elf, 32)[0]
            size = struct.unpack_from("<H", elf, 54)[0]
            count = struct.unpack_from("<H", elf, 56)[0]
            if count == 0 or size < 56 or phoff + size * count > len(elf):
                raise RuntimeError("ELF ARM64 sin encabezados válidos: " + name)
            found = False
            for i in range(count):
                start = phoff + i * size
                ptype = struct.unpack_from("<I", elf, start)[0]
                if ptype != 1:  # PT_LOAD
                    continue
                found = True
                align = struct.unpack_from("<Q", elf, start + 48)[0]
                if align < 16384 or align % 16384 != 0:
                    raise RuntimeError(
                        f"ELF ARM64 no alineado a 16 KB: {name} p_align={align}")
            if not found:
                raise RuntimeError("ELF ARM64 sin segmentos PT_LOAD: " + name)
            total += 1
    if total == 0:
        raise RuntimeError("No se encontraron librerías ARM64 para validar 16 KB")
    print(f"ANDROID_ARM64_16KB_ELF_PASS: {total} librerías; falta validar con Play y dispositivo")


def locate_flutter() -> str:
    """Resolve flutter.bat explicitly on Windows for Python subprocess/WinError 2.

    PowerShell resolves 'flutter' to a .bat shim via PATHEXT, but a raw
    CreateProcess call may not, depending on the caller/environment.
    """
    command = "flutter.bat" if os.name == "nt" else "flutter"
    executable = shutil.which(command)
    if executable is None and command != "flutter":
        executable = shutil.which("flutter")
    if not executable:
        raise RuntimeError(
            "No se encontro Flutter en PATH. Comprueba en PowerShell: "
            "Get-Command flutter; flutter --version. "
            "En Windows agrega <FlutterSDK>\\\\bin a PATH y abre nueva terminal."
        )
    return executable


def build() -> None:
    check_source()
    require_local_configuration()
    # Always block a signed AAB while original customer-provided HD media is missing.
    subprocess.run([sys.executable, str(ROOT / "ci/verify_landing_assets.py")],
      cwd=APP, check=True)
    flutter_exe = locate_flutter()
    print("FLUTTER_TOOL_FOUND: " + str(Path(flutter_exe).name), flush=True)
    subprocess.run([flutter_exe, "pub", "get"], cwd=APP, check=True)
    configure_ephemeral_gradle()
    # Prevent a previously signed/stale bundle from being reported as a new RC.
    if BUNDLE.exists():
        BUNDLE.unlink()
    cmd = [flutter_exe, "build", "appbundle", "--release", "--no-pub"]
    cmd.extend("--dart-define=" + k + "=" + os.environ[k] for k in PUBLIC_FIREBASE)
    subprocess.run(cmd, cwd=APP, check=True)
    if not BUNDLE.is_file() or BUNDLE.stat().st_size < 10000:
        raise RuntimeError("No se generó el AAB de release")
    verify_aab_structure(BUNDLE)
    verify_arm64_native_alignment(BUNDLE)
    verification = subprocess.run(
        ["jarsigner", "-verify", str(BUNDLE)],
        capture_output=True, text=True, check=False,
    )
    if verification.returncode != 0 or "jar verified." not in verification.stdout:
        raise RuntimeError("Falló la verificación criptográfica del AAB")
    digest = hashlib.sha256(BUNDLE.read_bytes()).hexdigest()
    print("SIGNED_AAB_PASS; SHA256=" + digest)
    print("AAB local: " + str(BUNDLE))
    print("No se subió nada a Google Play ni se almacenó la clave en GitHub.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true")
    group.add_argument("--build", action="store_true")
    args = parser.parse_args()
    try:
        build() if args.build else check_source()
    except (AssertionError, OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        print("RELEASE_BLOCKED: " + str(exc), file=sys.stderr)
        sys.exit(2)
