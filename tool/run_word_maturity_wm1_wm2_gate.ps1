$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter(Mandatory = $true)] [scriptblock]$Action
    )

    Write-Host ""
    Write-Host ("==> " + $Name) -ForegroundColor Cyan
    $global:LASTEXITCODE = 0
    $previous = $ErrorActionPreference
    try {
        # Windows PowerShell 5.1 can surface benign native stderr warnings as
        # terminating ErrorRecord objects. Preserve them while certifying by
        # the actual process exit code.
        $ErrorActionPreference = "Continue"
        & $Action
        $nativeExitCode = $global:LASTEXITCODE
        $ErrorActionPreference = $previous
        if ($nativeExitCode -ne 0) {
            throw ("Native command exit code " + $nativeExitCode)
        }
    }
    catch {
        $ErrorActionPreference = $previous
        Write-Host ""
        Write-Host ("WM1+WM2 gate FAILED at: " + $Name) -ForegroundColor Red
        throw
    }
}

Write-Host "EduSheet Word Maturity WM1 + WM2 Gate" -ForegroundColor Green
Write-Host "Scope: OOXML relationship/media fidelity, image crop/transforms, theme/style inheritance, Smart Editor preservation, DF regressions"

Invoke-Step "Dependency resolution" {
    flutter pub get
}

Invoke-Step "Static analysis" {
    flutter analyze --no-pub
}

Invoke-Step "WM1 + WM2 OOXML media/style contracts" {
    flutter test test/features/document_reader/word_wm1_wm2_ooxml_style_media_test.dart
}

Invoke-Step "WM1 Smart Editor crop round-trip" {
    flutter test test/features/smart_editor/smart_editor_docx_wm1_wm2_test.dart
}

Invoke-Step "Real-document nested table runtime regression" {
    flutter test test/features/document_reader/word_fidelity_nested_table_runtime_regression_test.dart
}

Invoke-Step "DF5 responsive/performance regression" {
    flutter test test/features/document_reader/word_docx_df5_responsive_performance_test.dart
}

Invoke-Step "DF4 Smart Editor DOCX round-trip regression" {
    flutter test test/features/smart_editor/smart_editor_docx_df4_test.dart
}

Invoke-Step "DF2 advanced layout regression" {
    flutter test test/features/document_reader/word_layout_fidelity_df2_test.dart
}

Invoke-Step "DF6 production-like DOCX regression" {
    flutter test test/features/document_reader/word_docx_df6_production_certification_test.dart
}

Write-Host ""
Write-Host "WORD MATURITY WM1 + WM2 GATE PASSED" -ForegroundColor Green
