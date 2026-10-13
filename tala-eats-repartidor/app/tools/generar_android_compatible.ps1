$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $Flutter) { throw 'Flutter no está en PATH.' }
$Temp = Join-Path $env:TEMP ("talaeats_driver_android_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $Temp | Out-Null
try {
  Push-Location $Temp
  & flutter create --platforms=android --android-language java --org com.talaeats --project-name driver .
  if ($LASTEXITCODE -ne 0) { throw 'flutter create falló.' }
  Pop-Location

  $TargetAndroid = Join-Path $Root 'android'
  if (Test-Path $TargetAndroid) { Remove-Item -Recurse -Force $TargetAndroid }
  Copy-Item -Recurse -Force (Join-Path $Temp 'android') $TargetAndroid

  # Branding estricto: únicamente el logotipo oficial de Tala Eats incluido en
  # assets/branding. No se permite el icono genérico ni una variante inventada.
  $BrandRoot = Join-Path $Root 'assets\branding\android'
  foreach ($Density in @('mipmap-mdpi','mipmap-hdpi','mipmap-xhdpi','mipmap-xxhdpi','mipmap-xxxhdpi')) {
    $SourceIcon = Join-Path $BrandRoot "$Density\ic_launcher.png"
    $SourceRound = Join-Path $BrandRoot "$Density\ic_launcher_round.png"
    $TargetDir = Join-Path $TargetAndroid "app\src\main\res\$Density"
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
    if (-not (Test-Path $SourceIcon)) { throw "Falta icono oficial: $SourceIcon" }
    Copy-Item -Force $SourceIcon (Join-Path $TargetDir 'ic_launcher.png')
    Copy-Item -Force $SourceRound (Join-Path $TargetDir 'ic_launcher_round.png')
  }

  # Flutter/Android puede generar adaptive icons que tienen prioridad sobre los
  # PNG por densidad en Android moderno. Los quitamos para impedir que reaparezca
  # el icono genérico al resolver @mipmap/ic_launcher.
  $AdaptiveDir = Join-Path $TargetAndroid 'app\src\main\res\mipmap-anydpi-v26'
  if (Test-Path $AdaptiveDir) {
    foreach ($Name in @('ic_launcher.xml','ic_launcher_round.xml')) {
      $Candidate = Join-Path $AdaptiveDir $Name
      if (Test-Path $Candidate) { Remove-Item -Force $Candidate }
    }
  }

  # Splash nativo: usa el mismo logotipo oficial antes de que Flutter pinte UI.
  $SplashSource = Join-Path $BrandRoot 'drawable\tala_eats_splash.png'
  if (-not (Test-Path $SplashSource)) { throw "Falta splash oficial: $SplashSource" }
  $Drawable = Join-Path $TargetAndroid 'app\src\main\res\drawable'
  $DrawableV21 = Join-Path $TargetAndroid 'app\src\main\res\drawable-v21'
  New-Item -ItemType Directory -Force -Path $Drawable | Out-Null
  New-Item -ItemType Directory -Force -Path $DrawableV21 | Out-Null
  Copy-Item -Force $SplashSource (Join-Path $Drawable 'tala_eats_splash.png')
  Copy-Item -Force $SplashSource (Join-Path $DrawableV21 'tala_eats_splash.png')

  $LaunchXml = @'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/white" />
    <item>
        <bitmap
            android:gravity="center"
            android:src="@drawable/tala_eats_splash" />
    </item>
</layer-list>
'@
  Set-Content -Path (Join-Path $Drawable 'launch_background.xml') -Value $LaunchXml -Encoding UTF8
  Set-Content -Path (Join-Path $DrawableV21 'launch_background.xml') -Value $LaunchXml -Encoding UTF8

  # Android 12+ tiene un splash del sistema separado. Forzamos el asset oficial.
  $ValuesV31 = Join-Path $TargetAndroid 'app\src\main\res\values-v31\styles.xml'
  if (Test-Path $ValuesV31) {
    $Styles = Get-Content -Raw $ValuesV31
    if ($Styles -match 'android:windowSplashScreenAnimatedIcon') {
      $Styles = $Styles -replace '<item name="android:windowSplashScreenAnimatedIcon">.*?</item>', '<item name="android:windowSplashScreenAnimatedIcon">@drawable/tala_eats_splash</item>'
    }
    if ($Styles -match 'android:windowSplashScreenBackground') {
      $Styles = $Styles -replace '<item name="android:windowSplashScreenBackground">.*?</item>', '<item name="android:windowSplashScreenBackground">@android:color/white</item>'
    }
    Set-Content -Path $ValuesV31 -Value $Styles -Encoding UTF8
  }

  $Manifest = Join-Path $TargetAndroid 'app\src\main\AndroidManifest.xml'
  $ManifestText = Get-Content -Raw $Manifest
  $ManifestText = $ManifestText -replace 'android:label="driver"', 'android:label="Tala Eats Repartidor"'
  if ($ManifestText -notmatch 'android:roundIcon=') {
    $ManifestText = $ManifestText -replace 'android:icon="@mipmap/ic_launcher"', 'android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/ic_launcher_round"'
  }
  $Permissions = @'
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
'@
  $ManifestText = $ManifestText -replace '<manifest([^>]*)>', "<manifest`$1>`n$Permissions"
  $ManifestText = $ManifestText -replace '<application', '<application android:allowBackup="false" android:usesCleartextTraffic="false"'
  Set-Content -Path $Manifest -Value $ManifestText -Encoding UTF8

  $Gradle = Join-Path $TargetAndroid 'app\build.gradle.kts'
  if (Test-Path $Gradle) {
    $g = Get-Content -Raw $Gradle
    $g = $g -replace 'minSdk = flutter.minSdkVersion', 'minSdk = 23'
    Set-Content -Path $Gradle -Value $g -Encoding UTF8
  }

  Write-Host '[OK] Android generado con branding oficial Tala Eats: launcher + splash.' -ForegroundColor Green
} finally {
  if ((Get-Location).Path -eq $Temp) { Pop-Location }
  if (Test-Path $Temp) { Remove-Item -Recurse -Force $Temp }
}
