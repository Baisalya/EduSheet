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
        Write-Host ("WM3+WM4 gate FAILED at: " + $Name) -ForegroundColor Red
        throw
    }
}

Write-Host "EduSheet Word Maturity WM3 + WM4 Gate" -ForegroundColor Green
Write-Host "Scope: paragraph flow/tabs/borders, exact numbering markers, table styles/borders/conditional formatting, WM1-WM2 + DF regressions"

Invoke-Step "Dependency resolution" {
    flutter pub get
}

Invoke-Step "Static analysis" {
    flutter analyze --no-pub
}

Invoke-Step "WM3 + WM4 paragraph/table engine contracts" {
    flutter test test/features/document_reader/word_wm3_wm4_paragraph_table_engine_test.dart
}

Invoke-Step "WM4 Smart Editor table preservation round-trip" {
    flutter test test/features/smart_editor/smart_editor_docx_wm3_wm4_test.dart
}

Invoke-Step "WM1 + WM2 media/style contracts" {
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
Write-Host "WORD MATURITY WM3 + WM4 GATE PASSED" -ForegroundColor Green
