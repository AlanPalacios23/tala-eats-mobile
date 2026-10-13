$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$PackageConfig = Join-Path $Root '.dart_tool\package_config.json'
if (-not (Test-Path $PackageConfig)) {
  throw 'No existe .dart_tool\package_config.json. Ejecuta flutter pub get antes de este paso.'
}

$Config = Get-Content -Raw -Path $PackageConfig | ConvertFrom-Json
$Stripe = $Config.packages | Where-Object { $_.name -eq 'stripe_android' } | Select-Object -First 1
if (-not $Stripe) {
  throw 'No se encontró stripe_android en package_config.json.'
}

$RootUri = [string]$Stripe.rootUri
if ($RootUri -match '^file:') {
  $StripePath = ([System.Uri]$RootUri).LocalPath
} else {
  $Base = Split-Path -Parent $PackageConfig
  $StripePath = [System.IO.Path]::GetFullPath((Join-Path $Base $RootUri))
}

# En Windows, Uri.LocalPath ya entrega C:\..., pero normalizamos por seguridad.
$StripePath = [System.Uri]::UnescapeDataString($StripePath)
$StripeGradle = Join-Path $StripePath 'android\build.gradle'
if (-not (Test-Path $StripeGradle)) {
  throw "No se encontró android\build.gradle de stripe_android en: $StripePath"
}

$Text = Get-Content -Raw -Path $StripeGradle
$Marker = 'TALA_EATS_JVM17_COMPAT'
if ($Text -notmatch $Marker) {
  $Compat = @'

// TALA_EATS_JVM17_COMPAT
// flutter_stripe 14.1.x + AGP 9/Built-in Kotlin puede heredar el JDK de Gradle
// para Kotlin aun cuando javac ya está en 17. Forzamos el mismo bytecode target
// en ambos lados para evitar Inconsistent JVM Target Compatibility.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
'@
  $Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($StripeGradle, ($Text + $Compat), $Utf8NoBom)
}

$Verify = Get-Content -Raw -Path $StripeGradle
if ($Verify -notmatch 'TALA_EATS_JVM17_COMPAT' -or $Verify -notmatch 'JvmTarget\.JVM_17') {
  throw 'No se pudo aplicar el guard JVM 17 a stripe_android.'
}

Write-Host '[OK] stripe_android localizado:' $StripePath -ForegroundColor Green
Write-Host '[OK] Kotlin/JVM target Stripe: 17' -ForegroundColor Green
Write-Host '[OK] Se mantiene validación estricta de compatibilidad JVM.' -ForegroundColor Green
