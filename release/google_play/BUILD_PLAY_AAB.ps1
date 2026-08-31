$ErrorActionPreference = 'Stop'

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

Push-Location $repositoryRoot
try {
    Invoke-ReleaseCommand -Arguments @('clean')
    Invoke-ReleaseCommand -Arguments @('pub', 'get')
    Invoke-ReleaseCommand -Arguments @('test', '--no-pub')
    Invoke-ReleaseCommand -Arguments @('analyze', '--no-pub')
    Invoke-ReleaseCommand -Arguments @(
        'build',
        'appbundle',
        '--release',
        '--dart-define=PREMIUM_ENABLED=true',
        '--dart-define=PREMIUM_PRODUCT_ID=edusheet_premium_yearly'
    )

    $bundlePath = (Resolve-Path -LiteralPath $bundleRelativePath).Path
    $bundle = Get-Item -LiteralPath $bundlePath
    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $bundlePath

    Write-Host "Google Play AAB: $bundlePath"
    Write-Host "Size: $($bundle.Length) bytes"
    Write-Host "SHA-256: $($hash.Hash)"
} finally {
    Pop-Location
}
