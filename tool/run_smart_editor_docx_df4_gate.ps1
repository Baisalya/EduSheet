$ErrorActionPreference = "Stop"

function Invoke-Step([string]$Name, [scriptblock]$Action) {
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    & $Action
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Smart Editor DOCX DF4 gate FAILED at: $Name" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Write-Host "EduSheet Smart Editor DOCX DF4 gate" -ForegroundColor Green
Write-Host "Scope: Word -> Smart Editor edit -> Word layout round-trip, exact page geometry, floating objects, editable text boxes, structured tables, DF3/DF2/DF1 regressions"

Invoke-Step "Static analysis" { flutter analyze --no-pub }
Invoke-Step "DF4 DOCX round-trip fidelity" { flutter test test/features/smart_editor/smart_editor_docx_df4_test.dart }
Invoke-Step "DF3 structured DOCX import" { flutter test test/features/smart_editor/smart_editor_docx_df3_test.dart }
Invoke-Step "DF2 advanced Word layout fidelity" { flutter test test/features/document_reader/word_layout_fidelity_df2_test.dart }
Invoke-Step "DF1 resume/table/image fidelity" { flutter test test/features/smart_editor/docx_fidelity_df1_test.dart }
Invoke-Step "Smart Editor W5 DOCX regression" { flutter test test/features/smart_editor/smart_editor_w5_test.dart }
Invoke-Step "Smart Editor W6 persistence regression" { flutter test test/features/smart_editor/smart_editor_w6_test.dart }
Invoke-Step "Teaching Planner Smart Document regression" { flutter test test/features/teaching_planner/planner_smart_document_phase_s1_s2_test.dart }

Write-Host ""
Write-Host "Smart Editor DOCX DF4 gate PASSED" -ForegroundColor Green
