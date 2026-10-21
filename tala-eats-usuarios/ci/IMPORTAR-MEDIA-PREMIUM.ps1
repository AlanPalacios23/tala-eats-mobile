# Instala solamente los tres assets originales del ZIP proporcionado en el chat.
# Uso (desde el clon de tala-eats-mobile):
# powershell -ExecutionPolicy Bypass -File .\tala-eats-usuarios\ci\IMPORTAR-MEDIA-PREMIUM.ps1 -ZipPath "C:\Descargas\TALA-EATS-Usuarios-v1.0.33-RECURSOS-ONBOARDING.zip"
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ZipPath)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$expectedBranch = 'feat/usuarios-v1.0.31-liquid-glass-auth'
$actual = (& git -C $repo branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $actual -ne $expectedBranch) {
    throw "Debes cambiar a la rama $expectedBranch antes de instalar assets. Actual: $actual"
}
if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
    throw "No encuentro el ZIP: $ZipPath"
}
$expected = @{
    'food_fiesta.webp' = '0e6123346ee3624c909c8f8061d103c00aa47098c7c919907d828d742076d313'
    'food_tala.webp' = '074b1c1325a4b3a75ff07ffbcae72ece5960389bd78d623728deba1ec899a45d'
    'tala_eats_original_wordmark.png' = '9c4468e976b0660fd56177d7f2e49b9d3f4ea294018a6501a5dd42c42300f17d'
    'tala_eats_wordmark_transparent.png' = 'b8255a65439392074172c0d934fcfcd455c556d82da5854deb04f6686b7327a2'
}
$temp = Join-Path ([IO.Path]::GetTempPath()) ("tala-premium-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $temp -Force
    $relative = 'tala-eats-usuarios/app/assets/landing'
    $source = Join-Path $temp $relative
    $dest = Join-Path $repo $relative
    New-Item -Path $dest -ItemType Directory -Force | Out-Null
    foreach ($file in $expected.Keys) {
        $from = Join-Path $source $file
        if (-not (Test-Path -LiteralPath $from -PathType Leaf)) {
            throw "El ZIP no contiene $file"
        }
        $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $from).Hash.ToLowerInvariant()
        if ($actualHash -ne $expected[$file]) {
            throw "Archivo incorrecto o modificado: $file"
        }
        Copy-Item -LiteralPath $from -Destination (Join-Path $dest $file) -Force
        Write-Host "PASS: $file" -ForegroundColor Green
    }
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ""
Write-Host "Los 4 recursos están colocados. Para actualizar GitHub:"
Write-Host 'git add tala-eats-usuarios/app/assets/landing/'
Write-Host 'git commit -m "assets(usuarios): fotografias y logo originales"'
Write-Host "git push origin $expectedBranch"
Write-Host "NO se ejecutó ningún push automáticamente."
