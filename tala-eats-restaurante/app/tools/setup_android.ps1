$ErrorActionPreference = 'Stop'
$FlutterVersion = '3.47.5'
$FlutterHome = Join-Path $env:USERPROFILE 'develop\flutter'
$AndroidSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$ToolsDir = Join-Path $env:USERPROFILE 'talaeats-dev-tools'
New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null

function Add-PathNow([string]$p) {
  if ($env:Path -notlike "*$p*") { $env:Path = "$p;$env:Path" }
}

Write-Host '=== Tala Eats · Preparación Android ===' -ForegroundColor Cyan


if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host 'Git no encontrado. Instalando Git for Windows...' -ForegroundColor Yellow
    winget install --id Git.Git --exact --accept-source-agreements --accept-package-agreements
    $GitCmd = 'C:\Program Files\Git\cmd'
    if (Test-Path $GitCmd) { Add-PathNow $GitCmd }
  } else {
    throw 'Git no está instalado y winget no está disponible.'
  }
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "Flutter no encontrado. Preparando Flutter $FlutterVersion..." -ForegroundColor Yellow
  $Zip = Join-Path $ToolsDir "flutter_windows_${FlutterVersion}-stable.zip"
  $Url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_${FlutterVersion}-stable.zip"
  if (-not (Test-Path $Zip)) {
    Invoke-WebRequest -Uri $Url -OutFile $Zip -UseBasicParsing
  }
  $DevDir = Join-Path $env:USERPROFILE 'develop'
  New-Item -ItemType Directory -Force -Path $DevDir | Out-Null
  if (Test-Path $FlutterHome) { Remove-Item -Recurse -Force $FlutterHome }
  Expand-Archive -Path $Zip -DestinationPath $DevDir -Force
  Add-PathNow (Join-Path $FlutterHome 'bin')
  [Environment]::SetEnvironmentVariable('Path', (([Environment]::GetEnvironmentVariable('Path','User') + ';' + (Join-Path $FlutterHome 'bin')).Trim(';')), 'User')
}

if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
  $StudioJava = 'C:\Program Files\Android\Android Studio\jbr\bin\java.exe'
  if (Test-Path $StudioJava) {
    $env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
    Add-PathNow (Join-Path $env:JAVA_HOME 'bin')
    [Environment]::SetEnvironmentVariable('JAVA_HOME', $env:JAVA_HOME, 'User')
  } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host 'Java no encontrado. Instalando OpenJDK 17...' -ForegroundColor Yellow
    winget install --id Microsoft.OpenJDK.17 --exact --accept-source-agreements --accept-package-agreements
    $jdk = Get-ChildItem 'C:\Program Files\Microsoft\jdk-*' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if ($jdk) { $env:JAVA_HOME = $jdk.FullName; Add-PathNow (Join-Path $jdk.FullName 'bin'); [Environment]::SetEnvironmentVariable('JAVA_HOME', $jdk.FullName, 'User') }
  } else {
    throw 'Java 17+ no está instalado y winget no está disponible.'
  }
}

$SdkManager = Join-Path $AndroidSdk 'cmdline-tools\latest\bin\sdkmanager.bat'
if (-not (Test-Path $SdkManager)) {
  Write-Host 'Android SDK command-line tools no encontrados. Descargando...' -ForegroundColor Yellow
  $CliZip = Join-Path $ToolsDir 'commandlinetools-win-15859902_latest.zip'
  $CliUrl = 'https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip'
  if (-not (Test-Path $CliZip)) { Invoke-WebRequest -Uri $CliUrl -OutFile $CliZip -UseBasicParsing }
  $Extract = Join-Path $ToolsDir 'cmdline-tools-extract'
  if (Test-Path $Extract) { Remove-Item -Recurse -Force $Extract }
  Expand-Archive -Path $CliZip -DestinationPath $Extract -Force
  $Latest = Join-Path $AndroidSdk 'cmdline-tools\latest'
  New-Item -ItemType Directory -Force -Path (Split-Path $Latest) | Out-Null
  if (Test-Path $Latest) { Remove-Item -Recurse -Force $Latest }
  Move-Item (Join-Path $Extract 'cmdline-tools') $Latest
}

$env:ANDROID_HOME = $AndroidSdk
$env:ANDROID_SDK_ROOT = $AndroidSdk
Add-PathNow (Join-Path $AndroidSdk 'platform-tools')
Add-PathNow (Join-Path $AndroidSdk 'cmdline-tools\latest\bin')
[Environment]::SetEnvironmentVariable('ANDROID_HOME', $AndroidSdk, 'User')
[Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $AndroidSdk, 'User')

Write-Host 'Aceptando licencias Android e instalando componentes...' -ForegroundColor Yellow
$yes = (1..40 | ForEach-Object { 'y' }) -join "`n"
$yes | & $SdkManager --licenses | Out-Host
& $SdkManager 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0'
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron instalar los componentes Android.' }

& flutter config --android-sdk $AndroidSdk
Write-Host ''
& flutter doctor -v
Write-Host ''
Write-Host '[OK] Entorno Android preparado. Cierra y vuelve a abrir CMD antes de compilar si PATH aún no se refleja.' -ForegroundColor Green
