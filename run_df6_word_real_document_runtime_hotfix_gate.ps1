$ErrorActionPreference = "Stop"

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    Write-Host ""
    Write-Host ("==> " + $Name) -ForegroundColor Cyan
    & $Action
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host ("DF6 Word real-document runtime hotfix FAILED at: " + $Name) -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Write-Host "EduSheet DF6 Word Real-Document Runtime Hotfix Gate" -ForegroundColor Green
Write-Host "Scope: nested/complex Word table runtime layout + DF6/DF5/DF2 regression"

Invoke-Step "Static analysis" {
    flutter analyze --no-pub
}

Invoke-Step "Nested Word table Windows-layout regression" {
    flutter test test/features/document_reader/word_fidelity_nested_table_runtime_regression_test.dart
}

Invoke-Step "DF5 responsive/performance regression" {
    flutter test test/features/document_reader/word_docx_df5_responsive_performance_test.dart
}

Invoke-Step "DF2 layout fidelity regression" {
    flutter test test/features/document_reader/word_layout_fidelity_df2_test.dart
}

Invoke-Step "DF6 production DOCX regression" {
    flutter test test/features/document_reader/word_docx_df6_production_certification_test.dart
}

Write-Host ""
Write-Host "DF6 WORD REAL-DOCUMENT RUNTIME HOTFIX GATE PASSED" -ForegroundColor Green
