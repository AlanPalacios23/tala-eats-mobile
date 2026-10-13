@echo off
setlocal EnableExtensions
cd /d "%~dp0"
echo ==========================================================
echo   TALA EATS REPARTIDOR v1.2.2 - VERIFICACION (sin telefono)
echo ==========================================================
echo.
where flutter >nul 2>nul
if errorlevel 1 (
  if exist "%USERPROFILE%\OneDrive\Escritorio\flutter\bin\flutter.bat" set "PATH=%USERPROFILE%\OneDrive\Escritorio\flutter\bin;%PATH%"
)
where flutter >nul 2>nul
if errorlevel 1 (echo [FALTA] Flutter no esta disponible. & pause & exit /b 1)

set "LOG=%~dp0QA-RESULTADOS-LOCAL.txt"
set "FAILED="
echo TALA EATS REPARTIDOR v1.2.2 - RESULTADOS QA LOCALES > "%LOG%"
echo Fecha: %DATE% %TIME% >> "%LOG%"
call flutter --version >> "%LOG%" 2>&1

echo [1/9] dart format .
call dart format . >> "%LOG%" 2>&1
if errorlevel 1 (set "FAILED=1" & echo        FALLO) else (echo        OK)

echo [2/9] flutter pub get
call flutter pub get >> "%LOG%" 2>&1
if errorlevel 1 (set "FAILED=1" & echo        FALLO) else (echo        OK)

echo [3/9] flutter analyze
call flutter analyze >> "%LOG%" 2>&1
if errorlevel 1 (set "FAILED=1" & echo        FALLO) else (echo        OK)

echo [4/9] proof_flow_responsive_test.dart
call flutter test test/proof_flow_responsive_test.dart --reporter expanded >> "%LOG%" 2>&1
if errorlevel 1 (set "FAILED=1" & echo        FALLO) else (echo        OK)

echo [5/9] layout_and_motion_test.dart
call flutter test test/layout_and_motion_test.dart --reporter expanded >> "%LOG%" 2>&1
if errorlevel 1 (set "FAILED=1" & echo        FALLO) else (echo        OK)

echo [6/9] delivery_flow_widget_test.dart
call flutter test test/delivery_flow_widget_test.dart --reporter expanded >> "%LOG%" 2>&1
if errorlevel 1 (set "FAILED=1" & echo        FALLO) else (echo        OK)

echo [7/9] registration_flow_widget_test.dart
call flutter test test/registration_flow_widget_test.dart --reporter expanded >> "%LOG%" 2>&1
if errorlevel 1 (set "FAILED=1" & echo        FALLO) else (echo        OK)

echo [8/9] branding_asset_test.dart
call flutter test test/branding_asset_test.dart --reporter expanded >> "%LOG%" 2>&1
if errorlevel 1 (set "FAILED=1" & echo        FALLO) else (echo        OK)

echo [9/9] flutter test completo
call flutter test --reporter expanded >> "%LOG%" 2>&1
if errorlevel 1 (set "FAILED=1" & echo        FALLO) else (echo        OK)

echo.
if defined FAILED (
  echo [ATENCION] Hubo fallos. Revisa y comparte: %LOG%
) else (
  echo [OK] Todo paso. Resultados guardados en: %LOG%
)
pause
if defined FAILED exit /b 1
exit /b 0
