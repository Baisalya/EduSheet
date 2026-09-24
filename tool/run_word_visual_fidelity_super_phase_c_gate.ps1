param(
    [switch]$SkipDependencyResolution
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Invoke-Native {
    param([Parameter(Mandatory = $true)] [scriptblock]$Command)
    $global:LASTEXITCODE = 0
    & $Command
    $nativeExitCode = $global:LASTEXITCODE
    if ($nativeExitCode -ne 0) {
        throw ("Native command exit code " + $nativeExitCode)
    }
}

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter(Mandatory = $true)] [scriptblock]$Command
    )
    Write-Host ""
    Write-Host ("==> " + $Name) -ForegroundColor Cyan
    try { & $Command }
    catch {
        Write-Host ""
        Write-Host ("WORD VISUAL FIDELITY SUPER PHASE C FAILED at: " + $Name) -ForegroundColor Red
        throw
    }
}

Write-Host "EduSheet Word Visual Fidelity Super Phase C - VF7 + VF8" -ForegroundColor Green
Write-Host "Scope: universal compatibility profiles + deterministic visual certification snapshots + real Microsoft Word corpus + VF1-VF8/WM full production regressions"

if (-not $SkipDependencyResolution) {
    Invoke-Step "Dependency resolution" {
        Invoke-Native { flutter pub get }
    }
}
else {
    Write-Host ""
    Write-Host "==> Dependency resolution (reusing top-level resolved packages)" -ForegroundColor DarkGray
}

Invoke-Step "VF1-VF8 final production certification chain" {
    Invoke-Native {
        powershell -ExecutionPolicy Bypass -File .\tool\run_final_word_production_release_certification_gate.ps1 -SkipDependencyResolution
    }
}

Write-Host ""
Write-Host "WORD VISUAL FIDELITY SUPER PHASE C GATE PASSED" -ForegroundColor Green
