[CmdletBinding()]
param(
    [switch]$SkipChecks
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $projectRoot

if (-not $SkipChecks) {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed.' }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'flutter test failed.' }
}

flutter build windows --release `
    --dart-define=PREMIUM_ENABLED=false `
    --dart-define=PREMIUM_PRODUCT_ID=edusheet_premium_yearly `
    --dart-define=MICROSOFT_PREMIUM_PRODUCT_ID=edusheet_premium_yearly
if ($LASTEXITCODE -ne 0) { throw 'Windows release build failed.' }

dart run msix:create --build-windows false --install-certificate false
if ($LASTEXITCODE -ne 0) { throw 'QA MSIX creation failed.' }

$package = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'release\microsoft_store\packages') `
    -Filter '*_qa.msix' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -eq $package) { throw 'The QA MSIX was not found.' }

& (Join-Path $PSScriptRoot 'VERIFY_MSIX.ps1') -PackagePath $package.FullName
Write-Output "QA_PACKAGE=$($package.FullName)"
