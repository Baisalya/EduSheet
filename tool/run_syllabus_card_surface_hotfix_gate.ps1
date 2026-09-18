$ErrorActionPreference = 'Stop'

function Invoke-GateStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    Write-Host ""
    Write-Host "==> $Name"
    & $Action
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Syllabus card surface hotfix gate FAILED at: $Name"
        exit $LASTEXITCODE
    }
}

Write-Host "EduSheet Syllabus Card Surface Hotfix release gate"
Write-Host "Scope: remove dark shadow bleed from hierarchy cards in Day theme"

Invoke-GateStep -Name 'Static analysis' -Action {
    flutter analyze --no-pub
}

Invoke-GateStep -Name 'Hierarchy card surface regression' -Action {
    flutter test test/features/teaching_planner/syllabus_hierarchy_card_surface_test.dart
}

Invoke-GateStep -Name 'Syllabus manager regression' -Action {
    flutter test test/features/teaching_planner/syllabus_manager_screen_test.dart
}

Write-Host ""
Write-Host "Syllabus card surface hotfix gate PASSED"
