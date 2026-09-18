param(
    [switch]$BuildAndroid,
    [switch]$BuildWindows
)

$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

function Invoke-GateCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [Parameter(Mandatory = $true)]
        [string]$Executable,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    Write-Host "`n==> $Label" -ForegroundColor Cyan
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

Push-Location $projectRoot
try {
    Invoke-GateCommand `
        -Label 'Teaching Planner format normalization' `
        -Executable 'dart' `
        -Arguments @(
            'format',
            'lib/features/teaching_planner',
            'test/features/teaching_planner'
        )

    Invoke-GateCommand `
        -Label 'Teaching Planner format verification' `
        -Executable 'dart' `
        -Arguments @(
            'format',
            '--output=none',
            '--set-exit-if-changed',
            'lib/features/teaching_planner',
            'test/features/teaching_planner'
        )

    Invoke-GateCommand `
        -Label 'Teaching Planner full regression suite' `
        -Executable 'flutter' `
        -Arguments @('test', 'test/features/teaching_planner')

    Invoke-GateCommand `
        -Label 'Static analysis' `
        -Executable 'flutter' `
        -Arguments @('analyze', '--no-pub')

    if ($BuildAndroid) {
        Invoke-GateCommand `
            -Label 'Android debug build' `
            -Executable 'flutter' `
            -Arguments @('build', 'apk', '--debug')
    }

    if ($BuildWindows) {
        Invoke-GateCommand `
            -Label 'Windows debug build' `
            -Executable 'flutter' `
            -Arguments @('build', 'windows', '--debug')
    }

    Write-Host "`nTeaching Planner release gate PASSED." -ForegroundColor Green
}
finally {
    Pop-Location
}
