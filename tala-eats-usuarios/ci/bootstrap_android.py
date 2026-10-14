#!/usr/bin/env python3
"""Build the native Android scaffold on an ephemeral CI runner, without touching production."""
import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / 'app'
ROLES = {
    'usuarios': {'name':'app', 'package':'com.talaeats.app', 'label':'Tala Eats', 'permissions':['INTERNET','ACCESS_FINE_LOCATION','ACCESS_COARSE_LOCATION','POST_NOTIFICATIONS']},
    'restaurante': {'name':'restaurant', 'package':'com.talaeats.restaurant', 'label':'Tala Eats Restaurante', 'permissions':['INTERNET','ACCESS_FINE_LOCATION','ACCESS_COARSE_LOCATION']},
    'repartidor': {'name':'driver', 'package':'com.talaeats.driver', 'label':'Tala Eats Repartidor', 'permissions':['INTERNET','CAMERA','ACCESS_COARSE_LOCATION','ACCESS_FINE_LOCATION','FOREGROUND_SERVICE','FOREGROUND_SERVICE_LOCATION']},
}

def replace_once(text, old, new, label):
    if old not in text:
        raise RuntimeError(f'Android scaffold changed; expected marker missing: {label}')
    return text.replace(old, new, 1)

def write(path, data):
    path.write_text(data, encoding='utf-8')

def setup(role):
    cfg = ROLES[role]
    if not (APP/'pubspec.yaml').is_file() or not (APP/'lib/main.dart').is_file():
        raise RuntimeError('Missing pubspec.yaml or lib/main.dart. Use the full official app source.')
    target = APP/'android'
    if target.exists():
        raise RuntimeError('android/ already exists: CI will not replace a checked-in native project.')
    with tempfile.TemporaryDirectory(prefix='talaeats-scaffold-') as temp:
        temp = Path(temp)
        cmd = ['flutter','create','--no-pub','--platforms=android','--android-language=java','--org','com.talaeats','--project-name',cfg['name'],'.']
        subprocess.run(cmd,cwd=temp,check=True)
        shutil.copytree(temp/'android', target)

    build = target/'app/build.gradle.kts'
    if not build.is_file():
        raise RuntimeError('Expected app/build.gradle.kts not generated; inspect Flutter version.')
    gradle = build.read_text(encoding='utf-8')
    if f'com.talaeats.{cfg["name"]}' not in gradle:
        raise RuntimeError('Android applicationId differs from expected package; aborting.')
    gradle = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23', gradle)
    if 'minSdk = 23' not in gradle:
        raise RuntimeError('Could not enforce Android minSdk 23.')
    if role == 'usuarios':
        gradle = re.sub(r'(sourceCompatibility\s*=\s*)JavaVersion\.VERSION_[A-Z0-9_]+', r'\1JavaVersion.VERSION_17',gradle)
        gradle = re.sub(r'(targetCompatibility\s*=\s*)JavaVersion\.VERSION_[A-Z0-9_]+', r'\1JavaVersion.VERSION_17',gradle)
    write(build, gradle)

    manifest = target/'app/src/main/AndroidManifest.xml'
    content=manifest.read_text(encoding='utf-8')
    permission_lines = ''.join(f'    <uses-permission android:name="android.permission.{p}" />\n' for p in cfg['permissions'] if f'android.permission.{p}' not in content)
    match=re.search(r'<manifest\b[^>]*>',content)
    if not match: raise RuntimeError('Missing Android manifest root element')
    content=content[:match.end()]+'\n'+permission_lines+content[match.end():]
    content=re.sub(r'android:label="[^"]*"',f'android:label="{cfg["label"]}"',content,count=1)
    # Todos los roles almacenan sesiones; nunca permitir copias de seguridad
    # Android de datos locales ni trafico HTTP de texto claro en produccion.
    content=replace_once(content,'<application','<application android:allowBackup="false" android:usesCleartextTraffic="false"','application policy')
    if role == 'repartidor':
        content=replace_once(content,'android:icon="@mipmap/ic_launcher"','android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/ic_launcher_round"','round icon')
    if role == 'usuarios':
        deep_links='''            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="talaeats.alan-palacios-dev.com" android:pathPrefix="/restablecer" />
                <data android:scheme="https" android:host="talaeats.alan-palacios-dev.com" android:pathPrefix="/pedido" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="talaeats" android:host="stripe-redirect" />
            </intent-filter>
'''
        content=replace_once(content,'</activity>',deep_links+'        </activity>','user deep links')
        content=replace_once(content,'</application>',
            '        <meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="orders" />\\n'
            '        <meta-data android:name="com.google.android.gms.wallet.api.enabled" android:value="true" />\\n'
            '    </application>','wallet and push metadata')
        source=APP/'tools/native/MainActivity.java'
        if not source.is_file(): raise RuntimeError('Missing project-native Stripe/secure MainActivity.java')
        dest=target/'app/src/main/java/com/talaeats/app/MainActivity.java'
        dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source,dest)
        for file in [target/'app/src/main/res/values/styles.xml',target/'app/src/main/res/values-night/styles.xml']:
            if not file.is_file(): raise RuntimeError(f'Missing expected native theme: {file}')
            s=file.read_text(encoding='utf-8')
            s,c1=re.subn(r'(<style name="LaunchTheme" parent=")[^"]+("[^>]*>)',r'\1Theme.AppCompat.Light.NoActionBar\2',s)
            s,c2=re.subn(r'(<style name="NormalTheme" parent=")[^"]+("[^>]*>)',r'\1Theme.MaterialComponents.DayNight.NoActionBar\2',s)
            if c1!=1 or c2!=1: raise RuntimeError(f'Unexpected native theme format: {file}')
            write(file,s)
        write(target/'app/proguard-rules.pro','''-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
''')
    write(manifest,content)
    if role in ('usuarios','restaurante'):
        source=APP/'tools/launcher-icons'
        if source.is_dir():
            for density in source.iterdir():
                if density.is_dir() and (density/'ic_launcher.png').is_file():
                    dest=target/'app/src/main/res'/density.name
                    dest.mkdir(parents=True,exist_ok=True)
                    shutil.copy2(density/'ic_launcher.png',dest/'ic_launcher.png')
    if role == 'repartidor':
        assets=APP/'assets/branding/android'
        res=target/'app/src/main/res'
        for density in ('mipmap-mdpi','mipmap-hdpi','mipmap-xhdpi','mipmap-xxhdpi','mipmap-xxxhdpi'):
            for icon in ('ic_launcher.png','ic_launcher_round.png'):
                source=assets/density/icon
                if not source.is_file(): raise RuntimeError(f'Missing official Tala Eats branding asset: {source}')
                dest=res/density/icon
                dest.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(source,dest)
        for n in ('ic_launcher.xml','ic_launcher_round.xml'):
            (res/'mipmap-anydpi-v26'/n).unlink(missing_ok=True)
        splash=assets/'drawable/tala_eats_splash.png'
        if not splash.is_file(): raise RuntimeError('Missing official Tala Eats splash')
        launch='''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/white" />
    <item><bitmap android:gravity="center" android:src="@drawable/tala_eats_splash" /></item>
</layer-list>
'''
        for d in ('drawable','drawable-v21'):
            (res/d).mkdir(parents=True,exist_ok=True)
            shutil.copy2(splash,res/d/'tala_eats_splash.png')
            write(res/d/'launch_background.xml',launch)
        style=res/'values-v31/styles.xml'
        if style.exists():
            s=style.read_text(encoding='utf-8')
            s=re.sub(r'<item name="android:windowSplashScreenAnimatedIcon">.*?</item>','<item name="android:windowSplashScreenAnimatedIcon">@drawable/tala_eats_splash</item>',s)
            s=re.sub(r'<item name="android:windowSplashScreenBackground">.*?</item>','<item name="android:windowSplashScreenBackground">@android:color/white</item>',s)
            write(style,s)
    print(f'BOOTSTRAP_OK role={role} package={cfg["package"]} native={target}')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--role',choices=tuple(ROLES),required=True)
    setup(parser.parse_args().role)
