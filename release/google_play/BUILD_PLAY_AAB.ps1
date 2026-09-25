param(
    [int] $BuildNumber = 0
)

$ErrorActionPreference = 'Stop'

if ($BuildNumber -le 0 -or $BuildNumber -gt 65535) {
    throw 'Pass -BuildNumber with an unused Play version code from 1 to 65535 (current planned code: 9).'
}

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$bundleRelativePath = 'build\app\outputs\bundle\release\app-release.aab'

function Invoke-ReleaseCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )

    & flutter @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "flutter $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
}

function Get-RequiredEnvironmentValue {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Set $Name before building the ads-ready Google Play AAB."
    }
    return $value.Trim()
}

$adMobAppId = Get-RequiredEnvironmentValue -Name 'EDUSHEET_ADMOB_APP_ID'
$homeBannerId = Get-RequiredEnvironmentValue -Name 'ADMOB_ANDROID_HOME_BANNER_ID'
$homeInterstitialId = Get-RequiredEnvironmentValue -Name 'ADMOB_ANDROID_HOME_INTERSTITIAL_ID'
$verificationUrl = Get-RequiredEnvironmentValue -Name 'EDUSHEET_PURCHASE_VERIFICATION_URL'

if ($adMobAppId -notmatch '^ca-app-pub-\d+~\d+$') {
    throw 'EDUSHEET_ADMOB_APP_ID must be an AdMob app ID containing ~.'
}
foreach ($adUnit in @($homeBannerId, $homeInterstitialId)) {
    if ($adUnit -notmatch '^ca-app-pub-\d+/\d+$') {
        throw 'Ad unit IDs must use the ca-app-pub-.../... format containing /.'
    }
}
if (@($adMobAppId, $homeBannerId, $homeInterstitialId) -match '3940256099942544') {
    throw 'Google sample IDs are forbidden in a release AAB.'
}
if ($verificationUrl -notmatch '^https://') {
    throw 'EDUSHEET_PURCHASE_VERIFICATION_URL must be HTTPS.'
}

Push-Location $repositoryRoot
try {
    Invoke-ReleaseCommand -Arguments @('clean')
    Invoke-ReleaseCommand -Arguments @('pub', 'get')
    Write-Host 'Packaging only: this command never runs flutter test or flutter analyze.' -ForegroundColor Yellow
    Invoke-ReleaseCommand -Arguments @(
        'build',
        'appbundle',
        '--release',
        "--build-number=$BuildNumber",
        '--dart-define=PREMIUM_ENABLED=true',
        '--dart-define=PREMIUM_PRODUCT_ID=edusheet_premium_yearly',
        '--dart-define=ADS_ENABLED=true',
        "--dart-define=ADMOB_ANDROID_HOME_BANNER_ID=$homeBannerId",
        "--dart-define=ADMOB_ANDROID_HOME_INTERSTITIAL_ID=$homeInterstitialId",
        "--dart-define=EDUSHEET_PURCHASE_VERIFICATION_URL=$verificationUrl"
    )

    $bundlePath = (Resolve-Path -LiteralPath $bundleRelativePath).Path
    $bundle = Get-Item -LiteralPath $bundlePath
    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $bundlePath
    $metadataPath = Join-Path $repositoryRoot 'build\app\intermediates\packaged_manifests\release\processReleaseManifestForPackage\output-metadata.json'
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    $builtVersion = $metadata.elements | Select-Object -First 1
    if ($metadata.applicationId -ne 'com.baishalya.edusheet' -or
        $builtVersion.versionCode -ne $BuildNumber) {
        throw "Built manifest identity/version mismatch: $($metadata.applicationId), code $($builtVersion.versionCode)."
    }

    Write-Host "Google Play AAB: $bundlePath"
    Write-Host "Package: $($metadata.applicationId)"
    Write-Host "Play version name: $($builtVersion.versionName)"
    Write-Host "Play version code: $BuildNumber"
    Write-Host "Size: $($bundle.Length) bytes"
    Write-Host "SHA-256: $($hash.Hash)"
    Write-Host 'Mode: ads-ready Free; Premium activates remotely when the Play base plan becomes active.'

} finally {
    Pop-Location
}
