$ErrorActionPreference = 'Stop'

function Run-Step {
    param(
        [string]$Label,
        [scriptblock]$Command
    )
    Write-Host "`n==> $Label" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

Run-Step 'Static analysis' { flutter analyze --no-pub }
Run-Step 'Phase 9 Smart Work Assistant regression' { flutter test test/features/guided_experience }
Run-Step 'Phase 10 class-aware assistant regression' { flutter test test/features/teaching_planner/teaching_planner_smart_assistant_test.dart test/features/teaching_planner/smart_assistant_syllabus_flow_test.dart }
Run-Step 'Phase 11 paper resource domain and backup' { flutter test test/features/teaching_planner/syllabus_paper_resources_phase11_test.dart }
Run-Step 'Phase 11 Resources & Papers UI' { flutter test test/features/teaching_planner/syllabus_resources_papers_widget_test.dart }
Run-Step 'Legacy syllabus attachments regression' { flutter test test/features/teaching_planner/syllabus_attachments_phase5_6_test.dart }
Run-Step 'Phase 11 Create Paper context' { flutter test test/features/editor/syllabus_paper_context_test.dart }
Run-Step 'Teaching Planner schema/regression set' { flutter test test/features/teaching_planner/teaching_resource_ownership_phase1_test.dart test/features/teaching_planner/teaching_workspace_phase20_test.dart test/features/teaching_planner/planner_insights_backup_phase18_test.dart }

Write-Host "`nPhase 11 Syllabus Resources & Papers gate passed." -ForegroundColor Green
