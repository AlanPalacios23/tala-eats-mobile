# TALA EATS Usuarios - Ejecutar UNICAMENTE en Windows propio; NO en CI.
# Esta herramienta NO sube la app a Play, no imprime contraseñas y no exporta claves.
[CmdletBinding()]
param(
    [switch]$SoloRevisar,
    [string]$OriginalesZip = '',
    [string]$KeystorePath = (Join-Path $env:USERPROFILE 'TalaEats-Keys\talaeats-upload.p12')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ReleaseScript = Join-Path $PSScriptRoot 'build_signed_play_bundle.py'
$HdImportScript = Join-Path $PSScriptRoot 'import_original_hd_assets.py'
$HdVerifyScript = Join-Path $PSScriptRoot 'verify_landing_assets.py'
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
    if (-not [string]::IsNullOrWhiteSpace($OriginalesZip)) {
        $ZipResolved = (Resolve-Path -LiteralPath $OriginalesZip -ErrorAction Stop).Path
        & python $HdImportScript '--zip' $ZipResolved '--check'
        if ($LASTEXITCODE -ne 0) {
            throw 'El ZIP HD no coincide con los cuatro originales aprobados.'
        }
        if (-not $SoloRevisar) {
            & python $HdImportScript '--zip' $ZipResolved '--install'
            if ($LASTEXITCODE -ne 0) { throw 'No se pudieron instalar los HD originales.' }
        }
    }
    if ($SoloRevisar) {
        Write-Host 'Comprobación del código aprobada; no se generó ni firmó el AAB.'
        return
    }

    # Explicitly validate originals before even creating an upload key.
    & python $HdVerifyScript
    if ($LASTEXITCODE -ne 0) {
        throw 'Faltan originales HD verificados. NO se generó la clave ni el AAB.'
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

    $storePassword = Read-Secret 'Contraseña del almacén de claves'
    [Environment]::SetEnvironmentVariable(
        'TALAEATS_UPLOAD_STORE_PASSWORD', $storePassword, 'Process')
    if ([IO.Path]::GetExtension($KeystorePath).ToLowerInvariant() -in @('.p12', '.pfx')) {
        # keytool PKCS12 uses one store/key password on most Java providers.
        [Environment]::SetEnvironmentVariable(
            'TALAEATS_UPLOAD_KEY_PASSWORD', $storePassword, 'Process')
    } else {
        [Environment]::SetEnvironmentVariable(
            'TALAEATS_UPLOAD_KEY_PASSWORD',
            (Read-Secret 'Contraseña de la clave'), 'Process')
    }
    $storePassword = $null

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
