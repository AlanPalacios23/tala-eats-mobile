@echo off
setlocal
cd /d "%~dp0"
echo ==========================================================
echo    TALA EATS - CONFIGURAR ENTORNO ANDROID EN WINDOWS
echo ==========================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\setup_android.ps1"
if errorlevel 1 (
  echo.
  echo [ERROR] No se pudo completar la configuracion.
  pause
  exit /b 1
)
echo.
echo [OK] Entorno preparado.
pause
