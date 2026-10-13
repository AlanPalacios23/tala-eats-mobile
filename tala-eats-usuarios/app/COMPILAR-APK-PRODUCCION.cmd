@echo off
setlocal
cd /d "%~dp0"
if not defined TALAEATS_API_BASE_URL set "TALAEATS_API_BASE_URL=https://talaeats.alan-palacios-dev.com/api/v1"
call dart format lib test || exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\generar_android_compatible.ps1" || exit /b 1
call flutter pub get || exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\normalizar_stripe_jvm.ps1" || exit /b 1
call flutter analyze --no-fatal-warnings --no-fatal-infos || exit /b 1
call flutter test || exit /b 1
call flutter build apk --debug --dart-define=TALAEATS_API_BASE_URL=%TALAEATS_API_BASE_URL% || exit /b 1
echo [OK] APK: build\app\outputs\flutter-apk\app-debug.apk
