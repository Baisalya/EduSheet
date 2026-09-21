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
        Write-Host "Settings Import/Export gate FAILED at: $Name"
        exit $LASTEXITCODE
    }
}

Write-Host "EduSheet Settings Import/Export reuse gate"
Write-Host "Scope: remove Settings coming-soon placeholder and reuse Unified .eds Import Center, planner backup/export, and Saved Paper export entry points"

Invoke-GateStep -Name 'Dependency resolution' -Action {
    flutter pub get
}

Invoke-GateStep -Name 'Static analysis' -Action {
    flutter analyze --no-pub
}

Invoke-GateStep -Name 'Settings Import/Export reuse regression' -Action {
    flutter test test/shared/presentation/settings_import_export_reuse_test.dart
}

Invoke-GateStep -Name 'Import Center regression' -Action {
    flutter test test/features/eds_import/eds_import_center_screen_phase3_test.dart
}

Invoke-GateStep -Name 'Saved Papers EDS regression' -Action {
    flutter test test/features/editor/saved_paper_eds_phase1_2_test.dart
}

Invoke-GateStep -Name 'Planner backup regression' -Action {
    flutter test test/features/teaching_planner/planner_insights_backup_phase18_test.dart
}

Write-Host ""
Write-Host "Settings Import/Export gate PASSED"
