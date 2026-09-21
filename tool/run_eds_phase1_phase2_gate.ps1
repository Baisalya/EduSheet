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
        Write-Host "EDS Phase 1+2 gate FAILED at: $Name"
        exit $LASTEXITCODE
    }
}

Write-Host "EduSheet EDS Phase 1+2 production certification gate"
Write-Host "Scope: universal .eds v4 container, stable paper lineage/revisions, canonical Saved Paper portability, assets, safe import, legacy planner compatibility"

Invoke-GateStep -Name 'Dependency resolution' -Action {
    flutter pub get
}

Invoke-GateStep -Name 'Static analysis' -Action {
    flutter analyze --no-pub
}

Invoke-GateStep -Name 'Universal EDS v4 container contract' -Action {
    flutter test test/shared/portable/eds_unified_container_test.dart
}

Invoke-GateStep -Name 'Saved Paper EDS import/export and collision safety' -Action {
    flutter test test/features/editor/saved_paper_eds_phase1_2_test.dart
}

Invoke-GateStep -Name 'Persistent paper lineage and revision tracking' -Action {
    flutter test test/features/editor/local_paper_lineage_test.dart
    flutter test test/features/editor/paper_model_legacy_migration_test.dart
}

Invoke-GateStep -Name 'Planner legacy v2/v3 and unified v4 portability' -Action {
    flutter test test/features/teaching_planner/portable_eds_v3_test.dart
    flutter test test/features/teaching_planner/planner_insights_backup_phase18_test.dart
    flutter test test/features/teaching_planner/syllabus_attachments_phase5_6_test.dart
}

Invoke-GateStep -Name 'Question Document canonical round-trip regression' -Action {
    flutter test test/features/paper_composer/question_document_phase9_fidelity_test.dart
    flutter test test/release/smart_paper_word_round_trip_gate_test.dart
}

Write-Host ""
Write-Host "EDS Phase 1+2 gate PASSED"
