#!/usr/bin/env python3
"""Port of the existing Usuarios native stripe_android JVM 17 workaround for CI Linux."""
import json
from pathlib import Path
from urllib.parse import urlparse,unquote
from urllib.request import url2pathname

app=Path(__file__).resolve().parent.parent/'app'
config=app/'.dart_tool/package_config.json'
if not config.exists():
    raise RuntimeError('Missing package_config.json; flutter pub get must run first')
packages=json.loads(config.read_text(encoding='utf-8'))['packages']
pkg=next((p for p in packages if p['name']=='stripe_android'),None)
if not pkg:
    raise RuntimeError('stripe_android missing: dependency tree changed')
uri=pkg['rootUri']
if uri.startswith('file:'):
    parsed=urlparse(uri)
    plugin_root=Path(url2pathname(parsed.path))
else:
    plugin_root=(config.parent/unquote(uri)).resolve()
file=plugin_root/'android/build.gradle'
if not file.is_file():
    raise RuntimeError(f'Could not locate Stripe plugin Gradle file: {file}')
content=file.read_text(encoding='utf-8')
marker='TALA_EATS_JVM17_COMPAT'
if marker not in content:
    content+='''\n\n// TALA_EATS_JVM17_COMPAT; port of validated local workaround.
// Required for consistency between Java and Kotlin bytecode with this Flutter/Stripe stack.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
'''
    file.write_text(content,encoding='utf-8')
assert marker in file.read_text(encoding='utf-8')
print(f'Stripe JVM 17 compatibility applied to ephemeral runner: {file}')
