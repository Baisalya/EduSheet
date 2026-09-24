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
        Write-Host ("WM5+WM6 gate FAILED at: " + $Name) -ForegroundColor Red
        throw
    }
}

Write-Host "EduSheet Word Maturity WM5 + WM6 Gate" -ForegroundColor Green
Write-Host "Scope: shapes/floating objects/wrap/z-order + sections/page/pagination/columns/header/footer + WM1-WM4/DF regressions"

Invoke-Step "Dependency resolution" {
    flutter pub get
}

Invoke-Step "Static analysis" {
    flutter analyze --no-pub
}

Invoke-Step "WM5 + WM6 canonical parser/viewer contracts" {
    flutter test test/features/document_reader/word_wm5_wm6_layout_engine_test.dart
}

Invoke-Step "WM5 + WM6 Smart Editor DOCX round-trip contracts" {
    flutter test test/features/smart_editor/smart_editor_docx_wm5_wm6_test.dart
}

Invoke-Step "WM3 + WM4 paragraph/table regressions" {
    flutter test test/features/document_reader/word_wm3_wm4_paragraph_table_engine_test.dart
    flutter test test/features/smart_editor/smart_editor_docx_wm3_wm4_test.dart
}

Invoke-Step "WM1 + WM2 media/style regressions" {
    flutter test test/features/document_reader/word_wm1_wm2_ooxml_style_media_test.dart
    flutter test test/features/smart_editor/smart_editor_docx_wm1_wm2_test.dart
}

Invoke-Step "DF2/DF4/DF5/DF6 Word fidelity regressions" {
    flutter test test/features/document_reader/word_layout_fidelity_df2_test.dart
    flutter test test/features/smart_editor/smart_editor_docx_df4_test.dart
    flutter test test/features/document_reader/word_docx_df5_responsive_performance_test.dart
    flutter test test/features/document_reader/word_docx_df6_production_certification_test.dart
    flutter test test/features/document_reader/word_fidelity_nested_table_runtime_regression_test.dart
}

Write-Host ""
Write-Host "WORD MATURITY WM5 + WM6 GATE PASSED" -ForegroundColor Green
