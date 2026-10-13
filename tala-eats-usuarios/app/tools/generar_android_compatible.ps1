$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $Flutter) { throw 'Flutter no está en PATH. Ejecuta CONFIGURAR-ENTORNO-ANDROID.cmd.' }

$Temp = Join-Path $env:TEMP ("talaeats_android_scaffold_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $Temp | Out-Null
try {
  Push-Location $Temp
  & flutter create --platforms=android --android-language java --org com.talaeats --project-name app .
  if ($LASTEXITCODE -ne 0) { throw 'flutter create falló.' }
  Pop-Location

  $TargetAndroid = Join-Path $Root 'android'
  if (Test-Path $TargetAndroid) { Remove-Item -Recurse -Force $TargetAndroid }
  Copy-Item -Recurse -Force (Join-Path $Temp 'android') $TargetAndroid

  $Manifest = Join-Path $TargetAndroid 'app\src\main\AndroidManifest.xml'
  if (-not (Test-Path $Manifest)) { throw 'No se generó AndroidManifest.xml.' }
  $ManifestText = Get-Content -Raw -Path $Manifest
  $ManifestText = $ManifestText -replace 'android:label="app"', 'android:label="Tala Eats"'
  Set-Content -Path $Manifest -Value $ManifestText -Encoding UTF8


  # Producción móvil: permisos, deep links y bridge nativo seguro.
  $ManifestText = Get-Content -Raw -Path $Manifest
  $ManifestOpen = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
  $PermissionLines = @()
  if ($ManifestText -notmatch 'android.permission.INTERNET') { $PermissionLines += '    <uses-permission android:name="android.permission.INTERNET" />' }
  if ($ManifestText -notmatch 'android.permission.ACCESS_FINE_LOCATION') { $PermissionLines += '    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />' }
  if ($ManifestText -notmatch 'android.permission.ACCESS_COARSE_LOCATION') { $PermissionLines += '    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />' }
  if ($PermissionLines.Count -gt 0) {
    $PermissionBlock = $ManifestOpen + "`r`n" + ($PermissionLines -join "`r`n")
    $ManifestText = $ManifestText.Replace($ManifestOpen, $PermissionBlock)
  }
  $DeepLinks = @'
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="talaeats.alan-palacios-dev.com" android:pathPrefix="/restablecer" />
                <data android:scheme="https" android:host="talaeats.alan-palacios-dev.com" android:pathPrefix="/pedido" />
            </intent-filter>
'@
  if ($ManifestText -notmatch 'android:pathPrefix="/restablecer"') {
    $ManifestText = $ManifestText -replace '(</activity>)', ($DeepLinks + '            $1')
  }

  # Stripe PaymentSheet redirect + Google Pay capability.
  $StripeRedirect = @'
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="talaeats" android:host="stripe-redirect" />
            </intent-filter>
'@
  if ($ManifestText -notmatch 'android:host="stripe-redirect"') {
    $ManifestText = $ManifestText -replace '(</activity>)', ($StripeRedirect + '            $1')
  }
  if ($ManifestText -notmatch 'com.google.android.gms.wallet.api.enabled') {
    $WalletMeta = '        <meta-data android:name="com.google.android.gms.wallet.api.enabled" android:value="true" />'
    $ManifestText = $ManifestText -replace '(</application>)', ($WalletMeta + "`r`n    `$1")
  }
  Set-Content -Path $Manifest -Value $ManifestText -Encoding UTF8

  $NativeSource = Join-Path $Root 'tools\native\MainActivity.java'
  $NativeTargetDir = Join-Path $TargetAndroid 'app\src\main\java\com\talaeats\app'
  New-Item -ItemType Directory -Force -Path $NativeTargetDir | Out-Null
  Copy-Item -Force $NativeSource (Join-Path $NativeTargetDir 'MainActivity.java')

  $LauncherIcons = Join-Path $Root 'tools\launcher-icons'
  if (Test-Path $LauncherIcons) {
    Get-ChildItem $LauncherIcons -Directory | ForEach-Object {
      $Target = Join-Path $TargetAndroid ('app\src\main\res\' + $_.Name)
      New-Item -ItemType Directory -Force -Path $Target | Out-Null
      Copy-Item -Force (Join-Path $_.FullName 'ic_launcher.png') (Join-Path $Target 'ic_launcher.png')
    }
  }

  # flutter_stripe requiere FlutterFragmentActivity y un Theme.AppCompat/MaterialComponents.
  foreach ($Styles in @(
      (Join-Path $TargetAndroid 'app\src\main\res\values\styles.xml'),
      (Join-Path $TargetAndroid 'app\src\main\res\values-night\styles.xml')
    )) {
    if (Test-Path $Styles) {
      $StylesText = Get-Content -Raw -Path $Styles
      $StylesText = $StylesText -replace '(<style name="LaunchTheme" parent=")[^"]+("[^>]*>)', '${1}Theme.AppCompat.Light.NoActionBar${2}'
      $StylesText = $StylesText -replace '(<style name="NormalTheme" parent=")[^"]+("[^>]*>)', '${1}Theme.MaterialComponents.DayNight.NoActionBar${2}'
      Set-Content -Path $Styles -Value $StylesText -Encoding UTF8
    }
  }

  $Proguard = Join-Path $TargetAndroid 'app\proguard-rules.pro'
  @'
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
'@ | Set-Content -Path $Proguard -Encoding UTF8

  $BuildGradleKts = Join-Path $TargetAndroid 'app\build.gradle.kts'
  $BuildGradle = Join-Path $TargetAndroid 'app\build.gradle'
  $GradleText = ''
  if (Test-Path $BuildGradleKts) { $GradleText = Get-Content -Raw $BuildGradleKts }
  elseif (Test-Path $BuildGradle) { $GradleText = Get-Content -Raw $BuildGradle }
  if ($GradleText -notmatch 'com\.talaeats\.app') { throw 'El applicationId generado no es com.talaeats.app.' }

  if (Test-Path $BuildGradleKts) {
    $GradleText = Get-Content -Raw $BuildGradleKts
    $GradleText = $GradleText -replace 'minSdk = flutter.minSdkVersion', 'minSdk = 23'
    # Mantener Java en 17 aunque Gradle se ejecute con JDK 21.
    $GradleText = $GradleText -replace 'sourceCompatibility\s*=\s*JavaVersion\.VERSION_[A-Z0-9_]+', 'sourceCompatibility = JavaVersion.VERSION_17'
    $GradleText = $GradleText -replace 'targetCompatibility\s*=\s*JavaVersion\.VERSION_[A-Z0-9_]+', 'targetCompatibility = JavaVersion.VERSION_17'
    Set-Content -Path $BuildGradleKts -Value $GradleText -Encoding UTF8
  } elseif (Test-Path $BuildGradle) {
    $GradleText = Get-Content -Raw $BuildGradle
    $GradleText = $GradleText -replace 'minSdkVersion flutter.minSdkVersion', 'minSdkVersion 23'
    $GradleText = $GradleText -replace 'sourceCompatibility\s+JavaVersion\.VERSION_[A-Z0-9_]+', 'sourceCompatibility JavaVersion.VERSION_17'
    $GradleText = $GradleText -replace 'targetCompatibility\s+JavaVersion\.VERSION_[A-Z0-9_]+', 'targetCompatibility JavaVersion.VERSION_17'
    Set-Content -Path $BuildGradle -Value $GradleText -Encoding UTF8
  }


  Write-Host '[OK] Android regenerado con tu Flutter actual.' -ForegroundColor Green
  Write-Host '[OK] applicationId: com.talaeats.app' -ForegroundColor Green
  Write-Host '[OK] app label: Tala Eats' -ForegroundColor Green
  Write-Host '[OK] Java target app: 17' -ForegroundColor Green
} finally {
  if ((Get-Location).Path -eq $Temp) { Pop-Location }
  if (Test-Path $Temp) { Remove-Item -Recurse -Force $Temp }
}
