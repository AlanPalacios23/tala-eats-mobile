#!/usr/bin/env python3
"""Android P0 native security gate. Does not make network calls."""
import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

PROJECT_ROOT=Path(__file__).resolve().parents[1]
ANDROID_NS='{http://schemas.android.com/apk/res/android}'
ROLES={
    'usuarios': ('app','com.talaeats.app'),
    'restaurante': ('restaurant','com.talaeats.restaurant'),
    'repartidor': ('driver','com.talaeats.driver'),
}
SECRET_MARKERS=(
    ('Stripe secret key', re.compile(r'sk_(?:live|test)_[A-Za-z0-9]{12,}')),
    ('GitHub token', re.compile(r'gh[pousr]_[A-Za-z0-9]{25,}')),
    ('private key material', re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')),
    ('AWS access key', re.compile(r'AKIA[0-9A-Z]{16}')),
)
SCAN_SUFFIXES={'.dart','.java','.kt','.py','.yaml','.yml','.xml','.kts','.properties','.json'}
MAX_BYTES=2_000_000

def ensure(condition, description):
    if not condition:
        raise AssertionError(description)
    print('PASS:',description)

def check_secret_sources():
    for role in ROLES:
        root=PROJECT_ROOT/f'tala-eats-{role}'
        for relative in ('app/lib','app/tools/native','ci'):
            directory=root/relative
            if not directory.exists():
                continue
            for path in directory.rglob('*'):
                if not path.is_file() or path.suffix not in SCAN_SUFFIXES or path.stat().st_size>MAX_BYTES:
                    continue
                if '/build/' in path.as_posix() or '/.dart_tool/' in path.as_posix():
                    continue
                data=path.read_text(encoding='utf-8',errors='replace')
                for description,rule in SECRET_MARKERS:
                    if rule.search(data):
                        raise AssertionError(f'Possible {description} in source {path.relative_to(PROJECT_ROOT)}')
    print('PASS: no private key blocks, Stripe secret keys or tokens detected in source paths')

def main(role):
    project,package=ROLES[role]
    app=PROJECT_ROOT/f'tala-eats-{role}'/'app'
    manifest=app/'android/app/src/main/AndroidManifest.xml'
    gradle=app/'android/app/build.gradle.kts'
    ensure(manifest.is_file() and gradle.is_file(),f'{role}: generated native Android files present')
    root=ET.parse(manifest).getroot()
    application=root.find('application')
    ensure(application is not None, f'{role}: Android application exists')
    ensure(application.get(ANDROID_NS+'allowBackup')=='false',f'{role}: Android backup explicitly disabled')
    ensure(application.get(ANDROID_NS+'usesCleartextTraffic')=='false',f'{role}: cleartext HTTP explicitly disabled')
    ensure(application.get(ANDROID_NS+'debuggable')!='true',f'{role}: debuggable never enabled explicitly in production manifest')
    permissions={
        p.get(ANDROID_NS+'name') for p in root.findall('uses-permission')
    }
    ensure('android.permission.INTERNET' in permissions,f'{role}: INTERNET permission declared')
    g=gradle.read_text(encoding='utf-8')
    ensure(re.search(r'\bminSdk\s*=\s*23\b',g) is not None,f'{role}: minSdk 23')
    ensure(re.search(r'\bapplicationId\s*=\s*["\']'+re.escape(package)+r'["\']',g) is not None,
           f'{role}: expected Android package {package}')
    activities=application.findall('activity')
    ensure(any(a.get(ANDROID_NS+'name')=='.MainActivity' and a.get(ANDROID_NS+'exported')=='true'
               for a in activities),f'{role}: single exported launcher activity')
    for activity in activities:
        exported=activity.get(ANDROID_NS+'exported')
        if exported=='true' and activity.get(ANDROID_NS+'name')!='.MainActivity':
            raise AssertionError(f'{role}: unexpected exported activity: {activity.get(ANDROID_NS+"name")}')
    source=app/'lib'
    dart_files=list(source.rglob('*.dart'))
    ensure(bool(dart_files),f'{role}: Dart production sources present')
    bases=[p.read_text(encoding='utf-8') for p in dart_files if p.name in ('remote_api.dart','production_api.dart')]
    ensure(any('https://talaeats.alan-palacios-dev.com/api/v1' in s for s in bases),
           f'{role}: HTTPS production API base configured')
    check_secret_sources()
    print(f'SECURITY_GATE_PASS role={role} (native checks and secret-pattern scan only)')
    
if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--role',choices=ROLES,required=True)
    try:
        main(parser.parse_args().role)
    except (AssertionError,ET.ParseError) as error:
        print('::error::SECURITY_GATE_FAIL',error,file=sys.stderr)
        sys.exit(1)
