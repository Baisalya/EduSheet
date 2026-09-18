$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

function Invoke-Gate {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    Write-Host "`n==> $Label" -ForegroundColor Cyan
    & flutter @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

Push-Location $projectRoot
try {
    Invoke-Gate -Label 'Static analysis' -Arguments @('analyze', '--no-pub')
    Invoke-Gate -Label 'Phase 9 Smart Work Assistant regression' -Arguments @('test', 'test/features/guided_experience/smart_work_activity_controller_test.dart', 'test/features/guided_experience/smart_work_activity_host_test.dart', 'test/features/guided_experience/contextual_help_policy_test.dart', 'test/features/guided_experience/contextual_help_offer_test.dart', 'test/features/guided_experience/smart_work_robot_test.dart')
    Invoke-Gate -Label 'Class Subject Chapter recommendation engine' -Arguments @('test', 'test/features/teaching_planner/teaching_planner_smart_assistant_test.dart')
    Invoke-Gate -Label 'Syllabus Show Me direct actions' -Arguments @('test', 'test/features/teaching_planner/smart_assistant_syllabus_flow_test.dart')
    Invoke-Gate -Label 'Lesson context preselection' -Arguments @('test', 'test/features/teaching_planner/lesson_planner_screen_phase15_test.dart')
    Invoke-Gate -Label 'Teaching Planner and Syllabus regression' -Arguments @('test', 'test/features/teaching_planner/teaching_planner_screen_test.dart', 'test/features/teaching_planner/syllabus_manager_screen_test.dart', 'test/features/teaching_planner/teaching_planner_navigation_contract_test.dart')
    Invoke-Gate -Label 'Guided overlay regression' -Arguments @('test', 'test/features/guided_experience/guide_overlay_precision_test.dart', 'test/features/guided_experience/guide_placement_engine_test.dart')
    Write-Host "`nClass-aware Smart Assistant gate PASSED." -ForegroundColor Green
}
finally {
    Pop-Location
}
