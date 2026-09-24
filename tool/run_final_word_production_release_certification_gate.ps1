param(
    [switch]$SkipDependencyResolution
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)] [scriptblock]$Command
    )

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
    try {
        & $Command
    }
    catch {
        Write-Host ""
        Write-Host ("FINAL WORD PRODUCTION RELEASE CERTIFICATION FAILED at: " + $Name) -ForegroundColor Red
        throw
    }
}

Write-Host "EduSheet Final Word Production Release Certification" -ForegroundColor Green
Write-Host "Scope: Smart Editor Android/Windows Open-Import + VF1-VF8 Word visual fidelity + real Microsoft Word corpus edit/export/reopen + package integrity + WM1-WM10/DF regressions"

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

Invoke-Step "Smart Editor Android + Windows Open/Import contracts" {
    Invoke-Native { flutter test --no-pub test/features/smart_editor/smart_editor_open_import_test.dart }
    Invoke-Native { flutter test --no-pub test/features/smart_editor/smart_editor_w5_test.dart }
}

Invoke-Step "DOCX viewer runtime layout safety" {
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_fidelity_long_table_runtime_regression_test.dart }
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_fidelity_nested_table_runtime_regression_test.dart }
}

Invoke-Step "Core Word visual fidelity VF1 + VF2 + VF3" {
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_visual_fidelity_super_phase_a_test.dart }
}

Invoke-Step "Advanced Word visual fidelity VF4 + VF5 + VF6" {
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_visual_fidelity_super_phase_b_test.dart }
}

Invoke-Step "Universal Word compatibility + visual certification VF7 + VF8" {
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_visual_fidelity_super_phase_c_test.dart }
    Write-Host ""
    Write-Host "==> VF8 isolated real Microsoft Word render probe" -ForegroundColor DarkCyan
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_visual_fidelity_real_word_probe_test.dart }
}

Invoke-Step "Final real-Word open -> edit -> export -> reopen certification" {
    Invoke-Native { flutter test --no-pub test/features/smart_editor/smart_editor_word_production_release_certification_test.dart }
}

Invoke-Step "WM1-WM10 + DF full Word regression certification" {
    Invoke-Native {
        powershell -ExecutionPolicy Bypass -File .\tool\run_word_maturity_wm9_wm10_gate.ps1 -SkipDependencyResolution
    }
}

Write-Host ""
Write-Host "FINAL WORD PRODUCTION RELEASE CERTIFICATION GATE PASSED" -ForegroundColor Green
