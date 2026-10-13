#!/usr/bin/env python3
"""Fetch unmodified OFL typefaces for the restaurant CI job; do not commit font binaries."""
import hashlib
from pathlib import Path
from urllib.request import Request, urlopen

ROOT=Path(__file__).resolve().parent.parent
FONT_DIR=ROOT/'app/assets/fonts'
FONT_DIR.mkdir(parents=True,exist_ok=True)
SOURCES={
 'Figtree':('https://raw.githubusercontent.com/google/fonts/main/ofl/figtree/Figtree%5Bwght%5D.ttf',
    ['Figtree_400Regular.ttf','Figtree_500Medium.ttf','Figtree_600SemiBold.ttf','Figtree_700Bold.ttf','Figtree_800ExtraBold.ttf']),
 'Bricolage':('https://raw.githubusercontent.com/google/fonts/main/ofl/bricolagegrotesque/BricolageGrotesque%5Bopsz%2Cwdth%2Cwght%5D.ttf',
    ['BricolageGrotesque_600SemiBold.ttf','BricolageGrotesque_700Bold.ttf','BricolageGrotesque_800ExtraBold.ttf']),
}
for family,(url,names) in SOURCES.items():
    if all((FONT_DIR/n).exists() for n in names):
        continue
    request=Request(url,headers={'User-Agent':'TalaEats-CI-font-bootstrap/1.0'})
    with urlopen(request,timeout=90) as response:
        data=response.read(15_000_000)
    if len(data)<20000 or data[:4] not in (b'\x00\x01\x00\x00',b'OTTO',b'true'):
        raise RuntimeError(f'{family}: font invalid or incomplete')
    sha=hashlib.sha256(data).hexdigest()
    print(f'{family} official Google Fonts SHA256: {sha}')
    for name in names:
        target=FONT_DIR/name
        if not target.exists():
            target.write_bytes(data)
print('Fonts prepared for CI. Font files are not part of the Git repository.')
