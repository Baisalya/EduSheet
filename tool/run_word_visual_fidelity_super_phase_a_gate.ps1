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
        Write-Host ("WORD VISUAL FIDELITY SUPER PHASE A FAILED at: " + $Name) -ForegroundColor Red
        throw
    }
}

Write-Host "EduSheet Word Visual Fidelity Super Phase A - VF1 + VF2 + VF3" -ForegroundColor Green
Write-Host "Scope: Word page geometry + typography metrics/fallback + professional table sizing/continuation pagination + production regressions"

if (-not $SkipDependencyResolution) {
    Invoke-Step "Dependency resolution" {
        Invoke-Native { flutter pub get }
    }
}
else {
    Write-Host ""
    Write-Host "==> Dependency resolution (reusing top-level resolved packages)" -ForegroundColor DarkGray
}

Invoke-Step "Static analysis" {
    Invoke-Native { flutter analyze --no-pub }
}

Invoke-Step "VF1 + VF2 + VF3 core fidelity contracts" {
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_visual_fidelity_super_phase_a_test.dart }
}

Invoke-Step "Existing Word layout/runtime regressions" {
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_layout_fidelity_df2_test.dart }
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_wm3_wm4_paragraph_table_engine_test.dart }
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_fidelity_long_table_runtime_regression_test.dart }
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_fidelity_nested_table_runtime_regression_test.dart }
}

Invoke-Step "Final Word production regression gate" {
    Invoke-Native {
        powershell -ExecutionPolicy Bypass -File .\tool\run_final_word_production_release_certification_gate.ps1 -SkipDependencyResolution
    }
}

Write-Host ""
Write-Host "WORD VISUAL FIDELITY SUPER PHASE A GATE PASSED" -ForegroundColor Green
