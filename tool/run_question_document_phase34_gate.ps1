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
        Write-Host "Question Document Phase 3+4 gate FAILED at: $Name"
        exit $LASTEXITCODE
    }
}

Write-Host "EduSheet Question Document Phase 3+4 release gate"
Write-Host "Scope: hybrid Word flow + floating objects, professional object manipulation, PDF/DOCX style fidelity"

Invoke-GateStep -Name 'Static analysis' -Action {
    flutter analyze --no-pub
}

Invoke-GateStep -Name 'Freeform object manipulation domain' -Action {
    flutter test test/features/paper_composer/word_object_manipulation_phase34_test.dart
}

Invoke-GateStep -Name 'Floating object editor interactions' -Action {
    flutter test test/features/paper_composer/word_object_editor_layer_phase34_test.dart
}

Invoke-GateStep -Name 'Persisted Word shape metadata regression' -Action {
    flutter test test/features/paper_composer/word_shapes_phase4b_test.dart
}

Invoke-GateStep -Name 'Read-only Word shape preview regression' -Action {
    flutter test test/features/paper_composer/word_shape_preview_phase4b_test.dart
}

Invoke-GateStep -Name 'Word content block regression' -Action {
    flutter test test/features/paper_composer/word_content_block_service_test.dart
}

Invoke-GateStep -Name 'Phase 1+2 document projection boundary' -Action {
    flutter test test/features/paper_composer/question_document_projection_test.dart
}

Invoke-GateStep -Name 'Phase 1 geometry print/editor boundary' -Action {
    flutter test test/features/paper_composer/geometry_print_surface_boundary_test.dart
}

Invoke-GateStep -Name 'PDF/DOCX floating-object fidelity' -Action {
    flutter test test/features/pdf/office_export_services_test.dart
}

Invoke-GateStep -Name 'Paper preview structured-content regression' -Action {
    flutter test test/features/paper_composer/paper_preview_advanced_content_test.dart
}

Write-Host ""
Write-Host "Question Document Phase 3+4 gate PASSED"
