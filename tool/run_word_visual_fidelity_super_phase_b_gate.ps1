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
        Write-Host ("WORD VISUAL FIDELITY SUPER PHASE B FAILED at: " + $Name) -ForegroundColor Red
        throw
    }
}

Write-Host "EduSheet Word Visual Fidelity Super Phase B - VF4 + VF5 + VF6" -ForegroundColor Green
Write-Host "Scope: advanced floating anchors/wrap/z-order + paragraph/section pagination + headers/footers/borders/shading/WordArt visual fidelity + full production regressions"

Invoke-Step "Dependency resolution" {
    Invoke-Native { flutter pub get }
}

Invoke-Step "Static analysis" {
    Invoke-Native { flutter analyze --no-pub }
}

Invoke-Step "VF4 + VF5 + VF6 advanced fidelity contracts" {
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_visual_fidelity_super_phase_b_test.dart }
}

Invoke-Step "Super Phase A + full Word production regressions" {
    Invoke-Native {
        powershell -ExecutionPolicy Bypass -File .\tool\run_word_visual_fidelity_super_phase_a_gate.ps1 -SkipDependencyResolution
    }
}

Write-Host ""
Write-Host "WORD VISUAL FIDELITY SUPER PHASE B GATE PASSED" -ForegroundColor Green
