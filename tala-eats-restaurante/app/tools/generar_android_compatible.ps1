$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $Flutter) { throw 'Flutter no está en PATH. Ejecuta CONFIGURAR-ENTORNO-ANDROID.cmd.' }

$Temp = Join-Path $env:TEMP ("talaeats_android_scaffold_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $Temp | Out-Null
try {
  Push-Location $Temp
  & flutter create --platforms=android --android-language java --org com.talaeats --project-name restaurant .
  if ($LASTEXITCODE -ne 0) { throw 'flutter create falló.' }
  Pop-Location

  $TargetAndroid = Join-Path $Root 'android'
  if (Test-Path $TargetAndroid) { Remove-Item -Recurse -Force $TargetAndroid }
  Copy-Item -Recurse -Force (Join-Path $Temp 'android') $TargetAndroid

  $Manifest = Join-Path $TargetAndroid 'app\src\main\AndroidManifest.xml'
  if (-not (Test-Path $Manifest)) { throw 'No se generó AndroidManifest.xml.' }
  $ManifestText = Get-Content -Raw -Path $Manifest
  if ($ManifestText -notmatch 'android.permission.INTERNET') {
    $ManifestText = $ManifestText -replace '<manifest([^>]*)>', ('$0' + [Environment]::NewLine + '    <uses-permission android:name="android.permission.INTERNET" />')
  }
  # v0.5.15: ubicación del establecimiento («Usar mi ubicación», solo en primer plano).
  foreach ($Perm in @('android.permission.ACCESS_FINE_LOCATION', 'android.permission.ACCESS_COARSE_LOCATION')) {
    if ($ManifestText -notmatch [regex]::Escape($Perm)) {
      $ManifestText = $ManifestText -replace '<manifest([^>]*)>', ('$0' + [Environment]::NewLine + '    <uses-permission android:name="' + $Perm + '" />')
    }
  }
  $ManifestText = $ManifestText -replace 'android:label="[^"]+"', 'android:label="Tala Eats Restaurante"'
  $ManifestText = $ManifestText -replace '<application', '<application android:allowBackup="false" android:usesCleartextTraffic="false"'
  Set-Content -Path $Manifest -Value $ManifestText -Encoding UTF8



  # Producción móvil: se conserva el MainActivity estándar generado por Flutter.
  $LauncherIcons = Join-Path $Root 'tools\launcher-icons'
  if (Test-Path $LauncherIcons) {
    Get-ChildItem $LauncherIcons -Directory | ForEach-Object {
      $Target = Join-Path $TargetAndroid ('app\src\main\res\' + $_.Name)
      New-Item -ItemType Directory -Force -Path $Target | Out-Null
      Copy-Item -Force (Join-Path $_.FullName 'ic_launcher.png') (Join-Path $Target 'ic_launcher.png')
    }
  }

  $BuildGradleKts = Join-Path $TargetAndroid 'app\build.gradle.kts'
  $BuildGradle = Join-Path $TargetAndroid 'app\build.gradle'
  $GradleText = ''
  if (Test-Path $BuildGradleKts) { $GradleText = Get-Content -Raw $BuildGradleKts }
  elseif (Test-Path $BuildGradle) { $GradleText = Get-Content -Raw $BuildGradle }
  if ($GradleText -notmatch 'com\.talaeats\.restaurant') { throw 'El applicationId generado no es com.talaeats.restaurant.' }

  if (Test-Path $BuildGradleKts) {
    $GradleText = Get-Content -Raw $BuildGradleKts
    $GradleText = $GradleText -replace 'minSdk = flutter.minSdkVersion', 'minSdk = 23'
    Set-Content -Path $BuildGradleKts -Value $GradleText -Encoding UTF8
  } elseif (Test-Path $BuildGradle) {
    $GradleText = Get-Content -Raw $BuildGradle
    $GradleText = $GradleText -replace 'minSdkVersion flutter.minSdkVersion', 'minSdkVersion 23'
    Set-Content -Path $BuildGradle -Value $GradleText -Encoding UTF8
  }


  Write-Host '[OK] Android regenerado con tu Flutter actual.' -ForegroundColor Green
  Write-Host '[OK] applicationId: com.talaeats.restaurant' -ForegroundColor Green
  Write-Host '[OK] app label: Tala Eats Restaurante' -ForegroundColor Green
} finally {
  if ((Get-Location).Path -eq $Temp) { Pop-Location }
  if (Test-Path $Temp) { Remove-Item -Recurse -Force $Temp }
}
