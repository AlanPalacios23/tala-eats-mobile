#!/usr/bin/env python3
"""Safe, fail-closed import of the four already-approved TALA EATS HD originals.

Reads an owner-provided ZIP locally; never downloads unknown art, changes
SHA256 expectations, publishes to Play or touches private signing material.

    python ci/import_original_hd_assets.py --zip "C:/ruta/TALA-EATS-ORIGINALES.zip" --check
    python ci/import_original_hd_assets.py --zip "C:/ruta/TALA-EATS-ORIGINALES.zip" --install

Both options verify original hashes. --check makes no changes.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import os
import stat
import sys
import tempfile
import zipfile

import verify_landing_assets as gate

MAX_ENTRY_BYTES = 40 * 1024 * 1024
MAX_TOTAL_BYTES = 130 * 1024 * 1024
MAX_ENTRIES = 256


def read_approved_media(path: Path) -> dict[str, bytes]:
    if not path.is_file():
        raise ValueError("No se encontró el ZIP original indicado.")
    selected: dict[str, bytes] = {}
    try:
        with zipfile.ZipFile(path) as archive:
            members = archive.infolist()
            if len(members) > MAX_ENTRIES:
                raise ValueError("ZIP contiene demasiados archivos.")
            total = 0
            for member in members:
                raw = member.filename.replace("\\", "/")
                segments = raw.split("/")
                if (raw.startswith("/") or any(s in ("", ".", "..") for s in
                       segments if not (member.is_dir() and s == segments[-1]))
                    or ":" in segments[0]):
                    raise ValueError("ZIP contiene una ruta insegura.")
                unix_type = (member.external_attr >> 16) & 0o170000
                if unix_type == stat.S_IFLNK:
                    raise ValueError("ZIP contiene un enlace simbólico; rechazado.")
                if member.is_dir():
                    continue
                if member.file_size > MAX_ENTRY_BYTES or member.file_size < 0:
                    raise ValueError("Archivo ZIP HD demasiado grande.")
                total += member.file_size
                if total > MAX_TOTAL_BYTES:
                    raise ValueError("ZIP excede tamaño permitido.")
                name = segments[-1]
                if name not in gate.EXPECTED:
                    continue
                if name in selected:
                    raise ValueError("ZIP contiene nombre HD repetido: " + name)
                with archive.open(member) as entry:
                    data = entry.read(MAX_ENTRY_BYTES + 1)
                if len(data) != member.file_size:
                    raise ValueError("Archivo ZIP incompleto: " + name)
                digest, minimum = gate.EXPECTED[name]
                gate.validate_blob(name, data, digest, minimum)
                selected[name] = data
    except (zipfile.BadZipFile, zipfile.LargeZipFile, OSError) as exc:
        raise ValueError("No se pudo abrir el ZIP; revisa que sea original y válido.") from exc
    missing = sorted(set(gate.EXPECTED).difference(selected))
    if missing:
        raise ValueError("Faltan recursos HD oficiales en el ZIP: " + ", ".join(missing))
    return selected


def install_media(selected: dict[str, bytes]) -> None:
    """Stage verified originals inside the target folder, then replace by name."""
    target = gate.ASSETS
    target.mkdir(parents=True, exist_ok=True)
    if target.is_symlink() or any((target / name).is_symlink() for name in selected):
        raise ValueError("La carpeta HD o alguno de sus archivos es un enlace simbólico.")
    staged: list[tuple[Path, Path]] = []
    try:
        for name, data in selected.items():
            with tempfile.NamedTemporaryFile(mode="wb", prefix=".tala-hd-",
                                             dir=target, delete=False) as fp:
                fp.write(data)
                staged.append((Path(fp.name), target / name))
        # Every source file was checked and written before replacing originals.
        for source, dest in staged:
            os.replace(source, dest)
    finally:
        for source, _ in staged:
            source.unlink(missing_ok=True)
    for name, (digest, minimum) in gate.EXPECTED.items():
        gate.validate(name, digest, minimum)
    print("TALA_EATS_HD_INSTALLED_PASS: 4/4, originales intactos y hashes aprobados")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--zip", required=True, type=Path,
                        help="ZIP original aprobado por el dueño; local, nunca en GitHub")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="Solo validar; no escribir")
    mode.add_argument("--install", action="store_true", help="Copiar archivos verificados al proyecto")
    args = parser.parse_args()
    try:
        selected = read_approved_media(args.zip)
        if args.install:
            install_media(selected)
        else:
            print("TALA_EATS_HD_ZIP_PASS: 4/4 SHA256, sin cambiar archivos.")
        return 0
    except (ValueError, OSError) as exc:
        print("TALA_EATS_HD_BLOCKED: " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
