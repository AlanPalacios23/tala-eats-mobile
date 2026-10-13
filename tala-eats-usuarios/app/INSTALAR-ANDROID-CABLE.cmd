@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
echo ==========================================================
echo   TALA EATS USUARIOS v1.0.18 - CHECKOUT TARIFA SERVICIO USB
echo ==========================================================
echo.
if not defined TALAEATS_API_BASE_URL set "TALAEATS_API_BASE_URL=https://talaeats.alan-palacios-dev.com/api/v1"
echo API: %TALAEATS_API_BASE_URL%
where flutter >nul 2>nul
if errorlevel 1 (
  if exist "%USERPROFILE%\OneDrive\Escritorio\flutter\bin\flutter.bat" set "PATH=%USERPROFILE%\OneDrive\Escritorio\flutter\bin;%PATH%"
)
where flutter >nul 2>nul
if errorlevel 1 (echo [FALTA] Flutter no esta disponible.& pause & exit /b 1)
set "ADB="
for /f "delims=" %%A in ('where adb 2^>nul') do if not defined ADB set "ADB=%%A"
if not defined ADB if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not defined ADB (echo [FALTA] adb no esta disponible.& pause & exit /b 1)
"%ADB%" start-server >nul 2>nul
set "DEVICE_COUNT=0"
for /f "skip=1 tokens=1,2" %%A in ('"%ADB%" devices') do if "%%B"=="device" (
  set /a DEVICE_COUNT+=1 >nul
  if not defined DEVICE_SERIAL set "DEVICE_SERIAL=%%A"
)
if !DEVICE_COUNT! GTR 1 (echo [ERROR] Hay varios Android conectados. Deja solo un dispositivo USB autorizado.& pause & exit /b 1)
if not defined DEVICE_SERIAL (echo [ERROR] No hay Android autorizado por USB.& pause & exit /b 1)
echo [1/7] Parser/formato Dart...
call dart format lib test || goto :fail
echo [2/7] Android production scaffold...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\generar_android_compatible.ps1" || goto :fail
echo [3/7] Dependencias...
call flutter pub get || goto :fail
echo [3B/7] Compatibilidad JVM Stripe...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\normalizar_stripe_jvm.ps1" || goto :fail
echo [4/7] Analisis...
call flutter analyze --no-fatal-warnings --no-fatal-infos || goto :fail
echo [5/7] Tests...
call flutter test || goto :fail
echo [6/7] APK production frontend...
call flutter build apk --debug --dart-define=TALAEATS_API_BASE_URL=%TALAEATS_API_BASE_URL% || goto :fail
set "APK=%~dp0build\app\outputs\flutter-apk\app-debug.apk"
if not exist "%APK%" goto :fail
echo [7/7] Instalando en %DEVICE_SERIAL%...
"%ADB%" -s "%DEVICE_SERIAL%" install -r "%APK%" || goto :fail
"%ADB%" -s "%DEVICE_SERIAL%" shell monkey -p com.talaeats.app -c android.intent.category.LAUNCHER 1 >nul 2>nul
echo.
echo [OK] Tala Eats v1.0.18 instalada sin borrar datos.
echo API: %TALAEATS_API_BASE_URL%
echo IMPORTANTE: pagos y pedidos ya no usan modo demo.
pause
exit /b 0
:fail
echo.
echo [ERROR] Se detuvo el gate. Copia desde el primer ERROR hacia abajo.
pause
exit /b 1
