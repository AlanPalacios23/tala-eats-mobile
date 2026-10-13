$ErrorActionPreference = 'Stop'

$AppDir = Split-Path -Parent $PSScriptRoot
Set-Location $AppDir

# Evidencia del gate (format / analyze / test / build) para QA y ChatGPT.
$GateLog = Join-Path $AppDir 'GATE-LOG.txt'
try { Start-Transcript -Path $GateLog -Force | Out-Null } catch { }

function Stop-Gate([string]$Message, [int]$Code = 1) {
    Write-Host ""
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    Write-Host "Se detuvo el gate. Revisa GATE-LOG.txt" -ForegroundColor Red
    try { Stop-Transcript | Out-Null } catch { }
    exit $Code
}

function Run-Native([string]$Label, [scriptblock]$Command) {
    Write-Host $Label
    & $Command
    if ($LASTEXITCODE -ne 0) {
        Stop-Gate "$Label fallo con codigo $LASTEXITCODE."
    }
}

Write-Host '=========================================================='
Write-Host '  TALA EATS RESTAURANTE v0.6.0 RC1 - CANDIDATA A PRODUCCION (RETIROS SIN DINERO REAL)'
Write-Host '=========================================================='
Write-Host ''
Write-Host 'Frontend de Claude conectado al backend Tala Eats desplegado.'
Write-Host 'API: https://talaeats.alan-palacios-dev.com/api/v1'
try {
    $ready = Invoke-RestMethod -Uri 'https://talaeats.alan-palacios-dev.com/api/v1/ready' -Method Get -TimeoutSec 8
    if ($ready.ready -eq $true) {
        Write-Host "[OK] Backend disponible: $($ready.version) | DB=$($ready.database) | Redis=$($ready.redis)" -ForegroundColor Green
    } else {
        Write-Host '[AVISO] /ready respondio, pero no marco ready=true.' -ForegroundColor Yellow
    }
} catch {
    Write-Host '[AVISO] No pude validar /ready ahora. El APK se compilara de todos modos.' -ForegroundColor Yellow
}
Write-Host ''

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    $flutterCandidate = Join-Path $env:USERPROFILE 'OneDrive\Escritorio\flutter\bin\flutter.bat'
    if (Test-Path $flutterCandidate) {
        $env:PATH = "$(Split-Path -Parent $flutterCandidate);$env:PATH"
        $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    }
}
if (-not $flutterCmd) {
    Stop-Gate 'Flutter no esta disponible. Ejecuta CONFIGURAR-ENTORNO-ANDROID.cmd o agrega Flutter al PATH.'
}

Run-Native '[1/8] Formato Dart...' { dart format lib test }
Write-Host "Flutter: $((flutter --version) -join ' | ')"

Write-Host '[2/8] Generando Android compatible con tu Flutter...'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'generar_android_compatible.ps1')
if ($LASTEXITCODE -ne 0) { Stop-Gate 'No se pudo generar el proyecto Android compatible.' }

Run-Native '[3/8] Limpieza de compilacion anterior...' { flutter clean }
Run-Native '[4/8] Dependencias...' { flutter pub get }
Run-Native '[5/8] Analisis estatico...' { flutter analyze --no-fatal-warnings --no-fatal-infos }
Write-Host '[OK] Analisis completado. Los mensajes "info" no son errores y no bloquean el APK.' -ForegroundColor Green
Run-Native '[6/8] Tests...' { flutter test }
Run-Native '[7/8] Construyendo APK debug conectado a produccion...' { flutter build apk --debug --dart-define=TALA_EATS_API_BASE=https://talaeats.alan-palacios-dev.com/api/v1 }

$apk = Join-Path $AppDir 'build\app\outputs\flutter-apk\app-debug.apk'
if (-not (Test-Path $apk)) { Stop-Gate 'Flutter termino pero no encuentro app-debug.apk.' }
Write-Host "[OK] APK generado: $apk" -ForegroundColor Green

Write-Host '[8/8] Detectando Android por USB e instalando...'
$adbCmd = Get-Command adb.exe -ErrorAction SilentlyContinue
$adb = if ($adbCmd) { $adbCmd.Source } else { $null }
if (-not $adb) {
    $candidate = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    if (Test-Path $candidate) { $adb = $candidate }
}
if (-not $adb) {
    Write-Host '[FALTA] adb no esta disponible, pero el APK SI fue generado.' -ForegroundColor Yellow
    Write-Host "APK: $apk"
    try { Stop-Transcript | Out-Null } catch { }
    exit 2
}

& $adb start-server | Out-Null
$deviceOutput = & $adb devices
$serial = $null
foreach ($line in $deviceOutput) {
    if ($line -match '^([^\s]+)\s+device\s*$') {
        $serial = $Matches[1]
        break
    }
}

$authorizedDevices = @($deviceOutput | Where-Object { $_ -match '^([^\s]+)\s+device\s*$' })
if ($authorizedDevices.Count -gt 1) {
    Stop-Gate 'Hay varios Android autorizados. Deja solo un dispositivo conectado por USB.'
}
if (-not $serial) {
    Write-Host '[ERROR] No hay Android autorizado por USB, pero el APK SI fue generado.' -ForegroundColor Red
    Write-Host ''
    $deviceOutput | ForEach-Object { Write-Host $_ }
    Write-Host ''
    Write-Host 'Si aparece unauthorized: desbloquea el telefono y acepta la huella RSA.'
    Write-Host 'Si aparece offline: desconecta y vuelve a conectar el cable.'
    Write-Host "APK: $apk"
    try { Stop-Transcript | Out-Null } catch { }
    exit 2
}

Write-Host "Instalando en $serial..."
& $adb -s $serial install -r $apk
$installCode = $LASTEXITCODE
if ($installCode -ne 0) {
    Stop-Gate 'ADB rechazo la actualizacion. No se desinstalara la app ni se borraran las fotos locales. Revisa firma/paquete/versionCode.'
}

& $adb -s $serial shell monkey -p com.talaeats.restaurant -c android.intent.category.LAUNCHER 1 | Out-Null

Write-Host ''
Write-Host '[OK] Tala Eats Restaurante v0.6.0 RC1 instalada y abierta.' -ForegroundColor Green
Write-Host '[OK] API productiva configurada: talaeats.alan-palacios-dev.com/api/v1' -ForegroundColor Green
Write-Host '[OK] Evidencia del gate guardada en GATE-LOG.txt' -ForegroundColor Green
try { Stop-Transcript | Out-Null } catch { }
exit 0
