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
        Write-Host "EDS Phase 4+5 gate FAILED at: $Name"
        exit $LASTEXITCODE
    }
}

Write-Host "EduSheet EDS Phase 4+5 production certification gate"
Write-Host "Scope: curriculum package builder, typed v4 curriculum payloads, Principal-to-Teacher assignment packs, hierarchy/assets/lineage preservation, scope isolation and Phase 3 preview safety"

Invoke-GateStep -Name 'Dependency resolution' -Action {
    flutter pub get
}

Invoke-GateStep -Name 'Static analysis' -Action {
    flutter analyze --no-pub
}

Invoke-GateStep -Name 'Curriculum and teacher assignment package contracts' -Action {
    flutter test test/features/teaching_planner/curriculum_package_phase4_5_test.dart
}

Invoke-GateStep -Name 'Unified EDS router regression' -Action {
    flutter test test/features/eds_import/eds_import_router_phase3_test.dart
}

Invoke-GateStep -Name 'Import Center regression' -Action {
    flutter test test/features/eds_import/eds_import_center_screen_phase3_test.dart
}

Invoke-GateStep -Name 'Syllabus manager UI regression' -Action {
    flutter test test/features/teaching_planner/syllabus_manager_screen_test.dart
}

Invoke-GateStep -Name 'Unified EDS container regression' -Action {
    flutter test test/shared/portable/eds_unified_container_test.dart
}

Invoke-GateStep -Name 'Saved Paper EDS regression' -Action {
    flutter test test/features/editor/saved_paper_eds_phase1_2_test.dart
}

Invoke-GateStep -Name 'Saved Paper lineage regression' -Action {
    flutter test test/features/editor/local_paper_lineage_test.dart
}

Invoke-GateStep -Name 'Planner backup restore transaction regression' -Action {
    flutter test test/features/teaching_planner/teaching_planner_backup_restore_service_phase3_test.dart
}

Invoke-GateStep -Name 'Legacy portable EDS regression' -Action {
    flutter test test/features/teaching_planner/portable_eds_v3_test.dart
}

Write-Host ""
Write-Host "EDS Phase 4+5 gate PASSED"
