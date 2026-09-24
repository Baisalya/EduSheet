$ErrorActionPreference = "Stop"

function Invoke-Step([string]$Name, [scriptblock]$Action) {
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    & $Action
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Smart Editor DOCX DF5 gate FAILED at: $Name" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Write-Host "EduSheet Smart Editor DOCX DF5 gate" -ForegroundColor Green
Write-Host "Scope: responsive Word/Smart Editor layout, lazy high-fidelity pages, bounded payload/document caches, repaint isolation, DF4-DF1 regressions"

Invoke-Step "Static analysis" { flutter analyze --no-pub }
Invoke-Step "DF5 responsive and performance hardening" { flutter test test/features/document_reader/word_docx_df5_responsive_performance_test.dart }
Invoke-Step "DF4 DOCX round-trip fidelity" { flutter test test/features/smart_editor/smart_editor_docx_df4_test.dart }
Invoke-Step "DF3 structured DOCX import" { flutter test test/features/smart_editor/smart_editor_docx_df3_test.dart }
Invoke-Step "DF2 advanced Word layout fidelity" { flutter test test/features/document_reader/word_layout_fidelity_df2_test.dart }
Invoke-Step "DF1 resume/table/image fidelity" { flutter test test/features/smart_editor/docx_fidelity_df1_test.dart }
Invoke-Step "Word viewer performance regression" { flutter test test/features/document_reader/word_document_viewer_performance_regression_test.dart }
Invoke-Step "Document reader responsive regression" { flutter test test/features/document_reader/document_reader_phase8_responsive_gate_test.dart }
Invoke-Step "Smart Editor W5 DOCX regression" { flutter test test/features/smart_editor/smart_editor_w5_test.dart }
Invoke-Step "Smart Editor W6 persistence regression" { flutter test test/features/smart_editor/smart_editor_w6_test.dart }
Invoke-Step "Teaching Planner Smart Document regression" { flutter test test/features/teaching_planner/planner_smart_document_phase_s1_s2_test.dart }

Write-Host ""
Write-Host "Smart Editor DOCX DF5 gate PASSED" -ForegroundColor Green
