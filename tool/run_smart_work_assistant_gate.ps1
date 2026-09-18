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
    Invoke-Gate -Label 'Smart Work Assistant activity controller' -Arguments @('test', 'test/features/guided_experience/smart_work_activity_controller_test.dart')
    Invoke-Gate -Label 'Smart Work Assistant activity host' -Arguments @('test', 'test/features/guided_experience/smart_work_activity_host_test.dart')
    Invoke-Gate -Label 'Smart Work Assistant policy' -Arguments @('test', 'test/features/guided_experience/contextual_help_policy_test.dart')
    Invoke-Gate -Label 'Smart Work Assistant prompt' -Arguments @('test', 'test/features/guided_experience/contextual_help_offer_test.dart')
    Invoke-Gate -Label 'Smart Work Assistant robot animation' -Arguments @('test', 'test/features/guided_experience/smart_work_robot_test.dart')
    Invoke-Gate -Label 'Smart Work Assistant contract' -Arguments @('test', 'test/features/guided_experience/smart_work_assistant_contract_test.dart')
    Invoke-Gate -Label 'Contextual preferences persistence' -Arguments @('test', 'test/features/guided_experience/contextual_help_controller_test.dart', 'test/features/guided_experience/shared_preferences_contextual_help_repository_test.dart')
    Invoke-Gate -Label 'Create Paper guide regression' -Arguments @('test', 'test/features/guided_experience/create_paper_guide_test.dart')
    Invoke-Gate -Label 'Create Syllabus guide regression' -Arguments @('test', 'test/features/guided_experience/create_syllabus_guide_test.dart')
    Invoke-Gate -Label 'Overlay precision regression' -Arguments @('test', 'test/features/guided_experience/guide_overlay_precision_test.dart', 'test/features/guided_experience/guide_placement_engine_test.dart')
    Invoke-Gate -Label 'Teaching Planner regression' -Arguments @('test', 'test/features/teaching_planner/teaching_planner_screen_test.dart', 'test/features/teaching_planner/syllabus_manager_screen_test.dart')
    Write-Host "`nSmart Work Assistant gate PASSED." -ForegroundColor Green
}
finally {
    Pop-Location
}
