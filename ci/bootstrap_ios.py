#!/usr/bin/env python3
"""Build a temporary iOS scaffold on GitHub macOS (never stores Apple secrets)."""
from __future__ import annotations
import argparse
import plistlib
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
CONFIG={
    "usuarios": ("talaeats_users","com.talaeats.app","Tala Eats"),
    "restaurante": ("talaeats_restaurant","com.talaeats.restaurant","Tala Eats Restaurante"),
    "repartidor": ("talaeats_driver","com.talaeats.driver","Tala Eats Repartidor"),
}
IOS_MIN="15.0"

def main(role: str) -> None:
    project, bundle, display=CONFIG[role]
    app=ROOT / f"tala-eats-{role}" / "app"
    for name in ("pubspec.yaml","lib/main.dart"):
        if not (app/name).is_file():
            raise RuntimeError(f"Missing Flutter source {app/name}")
    target=app/"ios"
    if target.exists():
        raise RuntimeError("iOS scaffold already checked in; will not overwrite it")

    with tempfile.TemporaryDirectory(prefix="tala-eats-ios-") as t:
        tmp=Path(t)
        subprocess.run([
            "flutter", "create", "--no-pub", "--platforms=ios",
            "--org=com.talaeats", "--project-name", project, "."
        ], cwd=tmp, check=True)
        if not (tmp/"ios/Runner.xcodeproj/project.pbxproj").is_file():
            raise RuntimeError("Flutter did not generate an Xcode project")
        shutil.copytree(tmp/"ios",target)

    pbx=target/"Runner.xcodeproj/project.pbxproj"
    content=pbx.read_text(encoding="utf-8")
    content, count=re.subn(r"(PRODUCT_BUNDLE_IDENTIFIER\s*=\s*)[A-Za-z0-9_.-]+(\s*;)",lambda m: m[1]+bundle+m[2],content)
    if count < 2:
        raise RuntimeError("Expected multiple iOS bundle-id entries; scaffold changed")
    content, n=re.subn(r"(IPHONEOS_DEPLOYMENT_TARGET\s*=\s*)[0-9.]+(\s*;)",lambda m: m[1]+IOS_MIN+m[2],content)
    if n == 0:
        raise RuntimeError("iOS deployment target marker missing")
    pbx.write_text(content,encoding="utf-8")

    podfile=target/"Podfile"
    if podfile.is_file():
        content=podfile.read_text(encoding="utf-8")
        content,n=re.subn(r"^\s*#?\s*platform\s*:ios,\s*['\"][0-9.]+['\"]",f"platform :ios, '{IOS_MIN}'",content,count=1,flags=re.M)
        if n == 0:
            content=f"platform :ios, '{IOS_MIN}'\n"+content
        podfile.write_text(content,encoding="utf-8")

    plist=target/"Runner/Info.plist"
    with plist.open("rb") as f: data=plistlib.load(f)
    data["CFBundleDisplayName"]=display
    if role in ("repartidor","restaurante"):
        data["NSLocationWhenInUseUsageDescription"]="Usamos tu ubicación para gestionar entregas y mostrar pedidos cercanos."
        data["NSCameraUsageDescription"]="Permite tomar fotos relacionadas con productos, pedidos o entregas."
        data["NSPhotoLibraryUsageDescription"]="Permite seleccionar fotos para productos, pedidos o evidencias de entrega."
    if role=="usuarios":
        data["NSLocationWhenInUseUsageDescription"]="Permite identificar tu ubicación para la entrega de pedidos."
        data["NSCameraUsageDescription"]="Permite usar la cámara para las opciones de pago que lo requieran."
        data["CFBundleURLTypes"]=[{"CFBundleURLName":"com.talaeats.app","CFBundleURLSchemes":["talaeats"]}]
    with plist.open("wb") as f: plistlib.dump(data,f,sort_keys=False)

    if not (target/"Runner.xcworkspace").exists():
        raise RuntimeError("Expected iOS Runner workspace not generated")
    print(f"IOS_SCAFFOLD_OK role={role} identifier={bundle} deployment={IOS_MIN} signed=no")

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--role",required=True,choices=CONFIG.keys())
    main(p.parse_args().role)
