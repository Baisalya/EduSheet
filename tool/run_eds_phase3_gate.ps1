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
        Write-Host "EDS Phase 3 gate FAILED at: $Name"
        exit $LASTEXITCODE
    }
}

Write-Host "EduSheet EDS Phase 3 production certification gate"
Write-Host "Scope: unified Import Center, v4 type routing, legacy planner detection, paper lineage safety, shared planner restore transaction and rollback"

Invoke-GateStep -Name 'Dependency resolution' -Action {
    flutter pub get
}

Invoke-GateStep -Name 'Static analysis' -Action {
    flutter analyze --no-pub
}

Invoke-GateStep -Name 'Unified EDS Import Router' -Action {
    flutter test test/features/eds_import/eds_import_router_phase3_test.dart
}

Invoke-GateStep -Name 'Import Center responsive UI contract' -Action {
    flutter test test/features/eds_import/eds_import_center_screen_phase3_test.dart
}

Invoke-GateStep -Name 'Shared planner restore transaction and rollback' -Action {
    flutter test test/features/teaching_planner/teaching_planner_backup_restore_service_phase3_test.dart
}

Invoke-GateStep -Name 'Phase 1+2 universal container and Saved Paper regressions' -Action {
    flutter test test/shared/portable/eds_unified_container_test.dart
    flutter test test/features/editor/saved_paper_eds_phase1_2_test.dart
    flutter test test/features/editor/local_paper_lineage_test.dart
}

Invoke-GateStep -Name 'Planner legacy and v4 portability regressions' -Action {
    flutter test test/features/teaching_planner/portable_eds_v3_test.dart
    flutter test test/features/teaching_planner/planner_insights_backup_phase18_test.dart
}

Write-Host ""
Write-Host "EDS Phase 3 gate PASSED"
