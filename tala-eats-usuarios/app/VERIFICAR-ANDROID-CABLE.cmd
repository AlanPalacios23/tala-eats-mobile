@echo off
setlocal
set "ADB="
for /f "delims=" %%A in ('where adb 2^>nul') do if not defined ADB set "ADB=%%A"
if not defined ADB if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not defined ADB (
  echo ADB no encontrado. Ejecuta CONFIGURAR-ENTORNO-ANDROID.cmd
  pause
  exit /b 1
)
"%ADB%" start-server
"%ADB%" devices -l
echo.
echo El telefono debe aparecer con estado: device
pause
