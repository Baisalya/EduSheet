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
    Write-Host ("==> " + $Name)
    & $Command
}

Write-Host "EduSheet Word Maturity WM9 + WM10 Gate"
Write-Host "Scope: unknown OOXML/package preservation + hardened round-trip + Microsoft Word identified corpus certification + WM1-WM8/DF regressions"

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

Invoke-Step "WM9 preserve-only OOXML/package contracts" {
    Invoke-Native { flutter test --no-pub test/features/smart_editor/smart_editor_docx_wm9_preservation_test.dart }
}

Invoke-Step "WM10 Microsoft Word identified + compatibility corpus certification" {
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_wm10_real_document_certification_test.dart }
}

Invoke-Step "DF4 + DF6 VML textbox fidelity regressions" {
    Invoke-Native { flutter test --no-pub test/features/smart_editor/smart_editor_docx_df4_test.dart }
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_docx_df6_production_certification_test.dart }
}

Invoke-Step "WM7 + WM8 and WM1-WM6 regression gate" {
    Invoke-Native {
        powershell -ExecutionPolicy Bypass -File .\tool\run_word_maturity_wm7_wm8_gate.ps1 -SkipDependencyResolution
    }
}

Write-Host ""
Write-Host "WORD MATURITY WM9 + WM10 GATE PASSED"
