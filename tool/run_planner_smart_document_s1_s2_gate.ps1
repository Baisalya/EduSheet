$ErrorActionPreference = "Stop"

function Invoke-Step([string]$name, [scriptblock]$command) {
  Write-Host ""
  Write-Host "==> $name"
  & $command
  if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Planner Smart Document S1+S2 gate FAILED at: $name"
    exit $LASTEXITCODE
  }
}

Write-Host "EduSheet Teaching Planner Smart Document S1+S2 gate"
Write-Host "Scope: first-class Smart Document links, duplicate safety, Resources & Papers UI, Create/Attach integration, Smart Editor regression"

Invoke-Step "Static analysis" { flutter analyze --no-pub }
Invoke-Step "Planner Smart Document contracts" { flutter test test/features/teaching_planner/planner_smart_document_phase_s1_s2_test.dart }
Invoke-Step "Saved paper resource regression" { flutter test test/features/teaching_planner/syllabus_paper_resources_phase11_test.dart }
Invoke-Step "Resources & Papers widget regression" { flutter test test/features/teaching_planner/syllabus_resources_papers_widget_test.dart }
Invoke-Step "Smart Editor W6 regression" { flutter test test/features/smart_editor/smart_editor_w6_test.dart }
Invoke-Step "User Manual regression" { flutter test test/features/guided_experience/user_manual_guide_coverage_test.dart }

Write-Host ""
Write-Host "Planner Smart Document S1+S2 gate PASSED"
