#!/usr/bin/env python3
"""Release gate: require the exact user-provided TALA EATS landing media.

Never treat fallback gradients or fallback text as a production-ready build.
No external network, third-party packages, or credentials are needed.
"""
from __future__ import annotations

import hashlib
import struct
import sys
from pathlib import Path

ASSETS = Path(__file__).resolve().parents[1] / "app" / "assets" / "landing"
EXPECTED = {
    "food_fiesta.webp": (
        "0e6123346ee3624c909c8f8061d103c00aa47098c7c919907d828d742076d313",
        100_000,
    ),
    "food_tala.webp": (
        "074b1c1325a4b3a75ff07ffbcae72ece5960389bd78d623728deba1ec899a45d",
        100_000,
    ),
    "tala_eats_original_wordmark.png": (
        "9c4468e976b0660fd56177d7f2e49b9d3f4ea294018a6501a5dd42c42300f17d",
        50_000,
    ),
}


def validate(name: str, expected_hash: str, minimum_size: int) -> None:
    file = ASSETS / name
    if not file.is_file():
        raise ValueError(f"FALTA {file}: sube las imagenes originales a la rama del PR")
    data = file.read_bytes()
    if len(data) < minimum_size:
        raise ValueError(f"Recurso demasiado pequeño o incompleto: {name}")
    if name.endswith(".png"):
        if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
            raise ValueError(f"PNG dañado: {name}")
        w, h = struct.unpack(">II", data[16:24])
        if w < 400 or h < 100:
            raise ValueError(f"Dimensiones de logo incorrectas: {w}x{h}")
    else:
        if data[:4] != b"RIFF" or data[8:12] != b"WEBP":
            raise ValueError(f"WEBP dañado: {name}")
        riff_size = struct.unpack("<I", data[4:8])[0]
        if riff_size + 8 != len(data):
            raise ValueError(f"WEBP truncado: {name}")
    digest = hashlib.sha256(data).hexdigest()
    if digest != expected_hash:
        raise ValueError(
            f"Archivo no coincide con la fotografía/logotipo proporcionados: {name}. "
            "No reemplazar el material sin aprobación del responsable."
        )
    print(f"PASS {name}  {len(data)} bytes  sha256={digest[:12]}...")


def main() -> int:
    failures = 0
    for name, (digest, minimum_size) in EXPECTED.items():
        try:
            validate(name, digest, minimum_size)
        except (OSError, ValueError) as exc:
            print(f"FAIL {exc}", file=sys.stderr)
            failures += 1
    if failures:
        print(
            "\nBLOQUEADO: los fallbacks visuales no son material de lanzamiento. "
            "Extrae los tres archivos del ZIP de recursos y súbelos a "
            "tala-eats-usuarios/app/assets/landing/ de la rama del PR.",
            file=sys.stderr,
        )
        return 1
    print("TALA EATS landing media: 3/3 PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
