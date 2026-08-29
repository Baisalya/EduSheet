[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$PackagePath,
    [string]$ExpectedIdentityName = '',
    [string]$ExpectedPublisher = '',
    [string]$ExpectedVersion = ''
)

$ErrorActionPreference = 'Stop'
$resolvedPackage = (Resolve-Path -LiteralPath $PackagePath).Path
$kitsRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$makeAppx = Get-ChildItem -LiteralPath $kitsRoot -Filter 'makeappx.exe' -Recurse -File |
    Sort-Object FullName -Descending |
    Select-Object -First 1
if ($null -eq $makeAppx) { throw 'MakeAppx.exe was not found in the Windows SDK.' }

$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$unpackPath = [IO.Path]::GetFullPath((Join-Path $tempRoot ("edusheet-msix-" + [guid]::NewGuid().ToString('N'))))
if (-not $unpackPath.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to use an MSIX verification path outside the system temp directory.'
}

try {
    New-Item -ItemType Directory -Path $unpackPath | Out-Null
    & $makeAppx.FullName unpack /p $resolvedPackage /d $unpackPath /nv
    if ($LASTEXITCODE -ne 0) { throw 'MakeAppx could not unpack the package.' }

    $manifestPath = Join-Path $unpackPath 'AppxManifest.xml'
    [xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
    $identity = $manifest.Package.Identity

    if ($ExpectedIdentityName -and $identity.Name -ne $ExpectedIdentityName) {
        throw "Identity mismatch: $($identity.Name)"
    }
    if ($ExpectedPublisher -and $identity.Publisher -ne $ExpectedPublisher) {
        throw "Publisher mismatch: $($identity.Publisher)"
    }
    if ($ExpectedVersion -and $identity.Version -ne $ExpectedVersion) {
        throw "Version mismatch: $($identity.Version)"
    }

    $manifestText = Get-Content -LiteralPath $manifestPath -Raw
    foreach ($extension in @('.pdf', '.docx', '.xlsx', '.pptx', '.txt')) {
        if ($manifestText -notmatch [regex]::Escape(">$extension<")) {
            throw "Required file association is missing: $extension"
        }
    }

    $hash = (Get-FileHash -LiteralPath $resolvedPackage -Algorithm SHA256).Hash
    $signature = Get-AuthenticodeSignature -LiteralPath $resolvedPackage
    Write-Output "IDENTITY_NAME=$($identity.Name)"
    Write-Output "PUBLISHER=$($identity.Publisher)"
    Write-Output "VERSION=$($identity.Version)"
    Write-Output "ARCHITECTURE=$($identity.ProcessorArchitecture)"
    Write-Output "SIGNATURE_STATUS=$($signature.Status)"
    Write-Output "SHA256=$hash"
} finally {
    if (Test-Path -LiteralPath $unpackPath) {
        $verifiedPath = [IO.Path]::GetFullPath($unpackPath)
        if ($verifiedPath.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path -Leaf $verifiedPath).StartsWith('edusheet-msix-')) {
            Remove-Item -LiteralPath $verifiedPath -Recurse -Force
        }
    }
}
