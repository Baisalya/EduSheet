$ErrorActionPreference = "Stop"

function Invoke-Step([string]$name, [scriptblock]$command) {
  Write-Host ""
  Write-Host "==> $name"
  & $command
  if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "DOCX Fidelity DF1 gate FAILED at: $name"
    exit $LASTEXITCODE
  }
}

Write-Host "EduSheet DOCX Fidelity DF1 gate"
Write-Host "Scope: complex Word layout detection, borderless-table column fidelity, in-cell images, Smart Editor rich DOCX import, Word viewer fallback"

Invoke-Step "Static analysis" { flutter analyze --no-pub }
Invoke-Step "DF1 resume/table/image fidelity" { flutter test test/features/smart_editor/docx_fidelity_df1_test.dart }
Invoke-Step "Word viewer loading regression" { flutter test test/features/document_reader/word_document_viewer_loading_regression_test.dart }
Invoke-Step "Word viewer performance regression" { flutter test test/features/document_reader/word_document_viewer_performance_regression_test.dart }
Invoke-Step "Smart Editor W5 DOCX regression" { flutter test test/features/smart_editor/smart_editor_w5_test.dart }
Invoke-Step "Smart Editor W6 persistence regression" { flutter test test/features/smart_editor/smart_editor_w6_test.dart }
Invoke-Step "Teaching Planner Smart Document regression" { flutter test test/features/teaching_planner/planner_smart_document_phase_s1_s2_test.dart }

Write-Host ""
Write-Host "DOCX Fidelity DF1 gate PASSED"
