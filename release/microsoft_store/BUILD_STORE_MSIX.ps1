[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$IdentityName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Publisher,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PublisherDisplayName,

    [string]$MicrosoftStoreId = '',
    [string]$PremiumProductId = 'edusheet_premium_yearly',
    [string]$MsixVersion = '',
    [switch]$SkipChecks
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $projectRoot

foreach ($value in @($IdentityName, $Publisher, $PublisherDisplayName)) {
    if ($value -match 'YOUR_|PLACEHOLDER|example|contoso') {
        throw 'Use the exact Product identity values copied from Partner Center.'
    }
}

$versionLine = Select-String -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') `
    -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$'
if ($null -eq $versionLine) { throw 'pubspec.yaml version is not in x.y.z+build format.' }
$versionMatch = [regex]::Match($versionLine.Line, '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$')
$semanticParts = $versionMatch.Groups[1].Value.Split('.')
$buildNumber = [int]$versionMatch.Groups[2].Value
if ($buildNumber -gt 65535) {
    throw 'Flutter build number must be <= 65535 for the Microsoft Store MSIX mapping.'
}
# Partner Center requires the fourth MSIX version segment (revision) to be 0.
# The globally increasing Flutter build number is carried in the third segment.
$expectedMsixVersion = "$($semanticParts[0]).$($semanticParts[1]).$buildNumber.0"
if ([string]::IsNullOrWhiteSpace($MsixVersion)) { $MsixVersion = $expectedMsixVersion }
if ($MsixVersion -ne $expectedMsixVersion) {
    throw "MSIX version $MsixVersion must match pubspec mapping $expectedMsixVersion."
}

if (-not $SkipChecks) {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed.' }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'flutter test failed.' }
}

$buildArguments = @(
    'build', 'windows', '--release',
    '--dart-define=PREMIUM_ENABLED=false',
    "--dart-define=PREMIUM_PRODUCT_ID=$PremiumProductId",
    "--dart-define=MICROSOFT_PREMIUM_PRODUCT_ID=$PremiumProductId"
)
if (-not [string]::IsNullOrWhiteSpace($MicrosoftStoreId)) {
    $buildArguments += "--dart-define=MICROSOFT_STORE_ID=$MicrosoftStoreId"
}
& flutter @buildArguments
if ($LASTEXITCODE -ne 0) { throw 'Windows release build failed.' }

$outputName = "EduSheet_${MsixVersion}_x64_store"
$fileExtensions = '.pdf,.doc,.docx,.rtf,.odt,.xls,.xlsx,.csv,.ods,.ppt,.pptx,.odp,.txt'
$msixArguments = @(
    'run', 'msix:create',
    '--build-windows', 'false',
    '--store',
    '--sign-msix', 'false',
    '--install-certificate', 'false',
    '--display-name', 'EduSheet',
    '--publisher-display-name', $PublisherDisplayName,
    '--identity-name', $IdentityName,
    '--publisher', $Publisher,
    '--version', $MsixVersion,
    '--architecture', 'x64',
    '--os-min-version', '10.0.17763.0',
    '--languages', 'en-us,hi-in',
    '--capabilities', 'internetClient',
    '--file-extension', $fileExtensions,
    '--logo-path', 'assets/Applogo.png',
    '--output-path', 'release/microsoft_store/packages',
    '--output-name', $outputName
)
& dart @msixArguments
if ($LASTEXITCODE -ne 0) { throw 'Store MSIX creation failed.' }

$packagePath = Join-Path $projectRoot "release\microsoft_store\packages\$outputName.msix"
if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
    throw "Store package was not created at $packagePath"
}

& (Join-Path $PSScriptRoot 'VERIFY_MSIX.ps1') `
    -PackagePath $packagePath `
    -ExpectedIdentityName $IdentityName `
    -ExpectedPublisher $Publisher `
    -ExpectedVersion $MsixVersion

Write-Output "STORE_PACKAGE=$packagePath"
Write-Warning 'Package created only. This script never uploads or submits to Partner Center.'
