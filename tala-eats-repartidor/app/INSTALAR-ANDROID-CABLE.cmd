@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
echo ==========================================================
echo   TALA EATS REPARTIDOR v1.2.5 - UI RETIROS (SIN TRANSFERENCIAS)
echo ==========================================================
echo.
where flutter >nul 2>nul
if errorlevel 1 (
  if exist "%USERPROFILE%\OneDrive\Escritorio\flutter\bin\flutter.bat" set "PATH=%USERPROFILE%\OneDrive\Escritorio\flutter\bin;%PATH%"
)
where flutter >nul 2>nul
if errorlevel 1 (echo [FALTA] Flutter no esta disponible. & pause & exit /b 1)
set "ADB="
for /f "delims=" %%A in ('where adb 2^>nul') do if not defined ADB set "ADB=%%A"
if not defined ADB if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not defined ADB (echo [FALTA] adb no esta disponible. & pause & exit /b 1)
"%ADB%" start-server >nul 2>nul
for /f "skip=1 tokens=1,2" %%A in ('"%ADB%" devices') do if "%%B"=="device" if not defined DEVICE_SERIAL set "DEVICE_SERIAL=%%A"
if not defined DEVICE_SERIAL (echo [ERROR] No hay Android autorizado por USB. & pause & exit /b 1)
echo [1/7] Generando Android...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\generar_android_compatible.ps1" || goto :fail
echo [2/7] Dependencias...
call flutter pub get || goto :fail
echo [3/7] Formato...
call dart format lib test || goto :fail
echo [4/7] Analisis...
call flutter analyze || goto :fail
echo [5A/7] Registro y onboarding de repartidor...
call flutter test test/registration_flow_widget_test.dart --reporter expanded || goto :fail
echo [5B/7] Prueba flujo completo evidencia + confirmacion...
call flutter test test/proof_flow_responsive_test.dart --reporter expanded || goto :fail
echo [5C/7] Prueba critica responsive + motion...
call flutter test test/layout_and_motion_test.dart --reporter expanded || goto :fail
echo [5D/7] Regresion flujo completo de entrega...
call flutter test test/delivery_flow_widget_test.dart --reporter expanded || goto :fail
echo [5E/7] Branding oficial...
call flutter test test/branding_asset_test.dart --reporter expanded || goto :fail
echo [5F/7] Suite completa...
call flutter test --reporter expanded || goto :fail
echo [6/7] Compilando APK release...
call flutter build apk --release || goto :fail
set "APK=%~dp0build\app\outputs\flutter-apk\app-release.apk"
if not exist "%APK%" goto :fail
echo [7/7] Instalando en %DEVICE_SERIAL%...
"%ADB%" -s "%DEVICE_SERIAL%" install -r "%APK%" || goto :fail
"%ADB%" -s "%DEVICE_SERIAL%" shell monkey -p com.talaeats.driver -c android.intent.category.LAUNCHER 1 >nul 2>nul
echo.
echo [OK] Tala Eats Repartidor v1.2.5 instalada.
echo [INFO] Backend actual por HTTPS; no se solicitan retiros.
pause
exit /b 0
:fail
echo.
echo [ERROR] Se detuvo el proceso. Copia el primer ERROR para revisarlo.
pause
exit /b 1
