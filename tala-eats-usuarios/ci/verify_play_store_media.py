#!/usr/bin/env python3
"""Verify ORIGINAL Play listing PNGs locally. Never fabricate artwork or captures.

Release gate is intentionally separate from Android APK/debug tests:
the app can compile while the Google Play listing is not publishable.
"""
from __future__ import annotations
import argparse
from pathlib import Path
import struct
import sys
import zlib

BASE = Path(__file__).resolve().parents[1] / "play-store-assets"
MAX_PNG_BYTES = 15 * 1024 * 1024


def png_dimensions(path: Path) -> tuple[int, int, int]:
    if not path.is_file():
        raise ValueError("Falta archivo PNG original: " + str(path))
    if path.is_symlink():
        raise ValueError("No se permiten enlaces simbólicos: " + path.name)
    data = path.read_bytes()
    if len(data) < 100 or len(data) > MAX_PNG_BYTES:
        raise ValueError("Archivo PNG vacío, incompleto o enorme: " + path.name)
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("No es PNG: " + path.name)
    offset = 8
    width = height = mode = 0
    has_image = has_end = False
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset:offset+4])[0]
        end = offset + 12 + length
        if end > len(data):
            raise ValueError("PNG truncado: " + path.name)
        kind = data[offset+4:offset+8]
        payload = data[offset+8:offset+8+length]
        crc = struct.unpack(">I", data[offset+8+length:end])[0]
        if zlib.crc32(kind + payload) & 0xffffffff != crc:
            raise ValueError("CRC PNG inválido: " + path.name)
        if kind == b"IHDR":
            if offset != 8 or length != 13:
                raise ValueError("IHDR inválido: " + path.name)
            width, height = struct.unpack(">II", payload[:8])
            mode = payload[9]  # 2 RGB; 6 RGBA
        elif kind == b"IDAT":
            has_image = True
        elif kind == b"IEND":
            has_end = True
            if end != len(data):
                raise ValueError("Contenido extra después de IEND: " + path.name)
            break
        offset = end
    if not (has_image and has_end and width > 0 and height > 0):
        raise ValueError("PNG sin imagen completa: " + path.name)
    if mode not in (2, 6):
        raise ValueError("Recurso debe ser PNG RGB o RGBA: " + path.name)
    return width, height, mode


def inspect_listing(root: Path = BASE) -> list[str]:
    issues: list[str] = []
    for name, w, h, alpha_allowed in (
        ("icon-512.png", 512, 512, True),
        ("feature-1024x500.png", 1024, 500, False),
    ):
        try:
            x, y, mode = png_dimensions(root / name)
            if (x, y) != (w, h):
                issues.append(f"{name}: tamaño requerido {w}×{h}, encontrado {x}×{y}")
            if not alpha_allowed and mode != 2:
                issues.append(f"{name}: gráfico promocional sin transparencia (RGB)")
        except (ValueError, OSError) as exc:
            issues.append(str(exc))
    shots = sorted((root / "screenshots").glob("*.png"))
    if not 2 <= len(shots) <= 8:
        issues.append("Play requiere 2–8 capturas Android reales PNG en screenshots/")
    for shot in shots:
        try:
            w, h, _ = png_dimensions(shot)
            if not 320 <= min(w, h) <= max(w, h) <= 3840:
                issues.append(f"{shot.name}: dimensión fuera del rango 320–3840")
            if max(w, h) > 2 * min(w, h):
                issues.append(f"{shot.name}: proporción superior a 2:1")
        except (ValueError, OSError) as exc:
            issues.append(str(exc))
    return issues


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", required=True)
    args = parser.parse_args()
    errors = inspect_listing()
    if errors:
        print("PLAY_LISTING_NO_GO:", file=sys.stderr)
        for error in errors:
            print(" - " + error, file=sys.stderr)
        return 2
    print("PLAY_LISTING_MEDIA_PASS: ícono 512, feature 1024×500 RGB y capturas PNG")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
