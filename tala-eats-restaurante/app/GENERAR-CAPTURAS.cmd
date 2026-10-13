@echo off
setlocal
cd /d "%~dp0"
echo ==========================================================
echo   TALA EATS RESTAURANTE v0.5.1 - MATRIZ DE CAPTURAS P0
echo ==========================================================
where flutter >nul 2>nul || (echo [FALTA] Flutter no esta disponible. & exit /b 1)
call flutter pub get || exit /b 1
call flutter test --update-goldens --dart-define=TALA_SCREENSHOTS=true test/screenshot_matrix_test.dart || exit /b 1
echo [OK] Capturas generadas en ..\qa\screenshots\
