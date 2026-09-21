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
        Write-Host "EDS Phase 7+8 gate FAILED at: $Name"
        exit $LASTEXITCODE
    }
}

Write-Host "EduSheet EDS Phase 7+8 production certification gate"
Write-Host "Scope: official Master Curriculum vs Teacher Working Layer enforcement, protected official resources, and full offline Principal-to-Teacher update/re-import certification"

Invoke-GateStep -Name 'Dependency resolution' -Action {
    flutter pub get
}

Invoke-GateStep -Name 'Static analysis' -Action {
    flutter analyze --no-pub
}

Invoke-GateStep -Name 'Master vs Teacher layer policy and write guards' -Action {
    flutter test test/features/teaching_planner/curriculum_layers_phase7_test.dart
}

Invoke-GateStep -Name 'Offline collaboration end-to-end certification' -Action {
    flutter test test/features/teaching_planner/offline_collaboration_phase8_test.dart
}

Invoke-GateStep -Name 'Curriculum merge engine and repository safety regression' -Action {
    flutter test test/features/teaching_planner/curriculum_merge_phase6_test.dart
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

Invoke-GateStep -Name 'Syllabus manager responsive and layer UI regression' -Action {
    flutter test test/features/teaching_planner/syllabus_manager_screen_test.dart
}

Invoke-GateStep -Name 'Syllabus resources and papers regression' -Action {
    flutter test test/features/teaching_planner/syllabus_attachments_phase5_6_test.dart
}

Invoke-GateStep -Name 'Teaching workspace regression' -Action {
    flutter test test/features/teaching_planner/teaching_workspace_screen_phase20_test.dart
}

Invoke-GateStep -Name 'Planner repository/schema regression' -Action {
    flutter test test/features/teaching_planner/local_teaching_planner_repository_test.dart
}

Invoke-GateStep -Name 'Planner backup schema regression' -Action {
    flutter test test/features/teaching_planner/planner_insights_backup_phase18_test.dart
}

Invoke-GateStep -Name 'Unified EDS container regression' -Action {
    flutter test test/shared/portable/eds_unified_container_test.dart
}

Invoke-GateStep -Name 'Saved Paper EDS regression' -Action {
    flutter test test/features/editor/saved_paper_eds_phase1_2_test.dart
}

Invoke-GateStep -Name 'Saved Papers official-master protection regression' -Action {
    flutter test test/features/editor/saved_papers_rename_action_test.dart
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
Write-Host "EDS Phase 7+8 gate PASSED"
