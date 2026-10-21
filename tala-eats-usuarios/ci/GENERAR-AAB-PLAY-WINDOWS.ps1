# TALA EATS Usuarios - Ejecutar UNICAMENTE en Windows propio; NO en CI.
# Esta herramienta NO sube la app a Play, no imprime contraseñas y no exporta claves.
[CmdletBinding()]
param(
    [switch]$SoloRevisar,
    [string]$KeystorePath = (Join-Path $env:USERPROFILE 'TalaEats-Keys\talaeats-upload.p12')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ReleaseScript = Join-Path $PSScriptRoot 'build_signed_play_bundle.py'
$Root = Split-Path $PSScriptRoot -Parent
$PrivateNames = @(
    'TALAEATS_UPLOAD_KEYSTORE',
    'TALAEATS_UPLOAD_STORE_PASSWORD',
    'TALAEATS_UPLOAD_KEY_ALIAS',
    'TALAEATS_UPLOAD_KEY_PASSWORD'
)
$PublicNames = @(
    'TALAEATS_FCM_API_KEY',
    'TALAEATS_FCM_APP_ID',
    'TALAEATS_FCM_SENDER_ID',
    'TALAEATS_FCM_PROJECT_ID'
)

function Read-Secret([string] $message) {
    $value = Read-Host -Prompt $message -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($value)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        $value.Dispose()
    }
}

function Invoke-ReleaseScript([string] $flag) {
    & python $ReleaseScript $flag
    if ($LASTEXITCODE -ne 0) {
        throw "TALA EATS release check no aprobado ($flag). No subir a Play."
    }
}

Push-Location $Root
try {
    # Gate sin llaves ni conexión LIVE.
    Invoke-ReleaseScript '--check'
    if ($SoloRevisar) {
        Write-Host 'Comprobación de código aprobada. No se generó ni firmó el AAB.'
        return
    }

    if (-not (Test-Path -LiteralPath $KeystorePath -PathType Leaf)) {
        $KeyDir = Split-Path -Parent $KeystorePath
        New-Item -ItemType Directory -Force -Path $KeyDir | Out-Null
        Write-Host 'No se encontró la upload key. Se creará localmente con keytool.'
        Write-Host 'Los datos y contraseñas se ingresan en la terminal, sin subirlos aquí.'
        & keytool -genkeypair -v -keystore $KeystorePath -storetype PKCS12 -keyalg RSA -keysize 3072 -validity 10000 -alias 'talaeats-upload'
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo generar la upload key.' }
        Write-Host 'IMPORTANTE: respalda este archivo cifrado fuera del equipo.'
    }

    [Environment]::SetEnvironmentVariable('TALAEATS_UPLOAD_KEYSTORE',
        (Resolve-Path -LiteralPath $KeystorePath).Path, 'Process')
    $alias = Read-Host 'Alias del keystore (normalmente talaeats-upload)'
    if ([string]::IsNullOrWhiteSpace($alias)) { $alias = 'talaeats-upload' }
    [Environment]::SetEnvironmentVariable('TALAEATS_UPLOAD_KEY_ALIAS', $alias, 'Process')

    [Environment]::SetEnvironmentVariable('TALAEATS_UPLOAD_STORE_PASSWORD',
        (Read-Secret 'Contraseña del almacén de claves'), 'Process')
    [Environment]::SetEnvironmentVariable('TALAEATS_UPLOAD_KEY_PASSWORD',
        (Read-Secret 'Contraseña de la clave'), 'Process')

    foreach ($name in $PublicNames) {
        $value = Read-Host "Valor público Firebase: $name"
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw "Falta $name; no se puede compilar."
        }
        [Environment]::SetEnvironmentVariable($name, $value.Trim(), 'Process')
    }

    Invoke-ReleaseScript '--build'
    Write-Host 'AAB firmado listo para validación manual. NO publicado.'
    Write-Host 'Ruta: app\build\app\outputs\bundle\release\app-release.aab'
    Write-Host 'Revisar además Play App Signing, recursos HD, pruebas reales y compatibilidad 16 KB.'
} finally {
    foreach ($name in ($PrivateNames + $PublicNames)) {
        Remove-Item -Path ("Env:" + $name) -ErrorAction SilentlyContinue
    }
    Pop-Location
}
