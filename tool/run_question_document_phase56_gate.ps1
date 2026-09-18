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
        Write-Host "Question Document Phase 5+6 gate FAILED at: $Name"
        exit $LASTEXITCODE
    }
}

Write-Host "EduSheet Question Document Phase 5+6 release gate"
Write-Host "Scope: anchoring + explicit pagination intent, printable-boundary safety, floating geometry design objects"

Invoke-GateStep -Name 'Static analysis' -Action {
    flutter analyze --no-pub
}

Invoke-GateStep -Name 'Phase 5+6 anchoring and geometry domain' -Action {
    flutter test test/features/paper_composer/word_pagination_geometry_phase56_test.dart
}

Invoke-GateStep -Name 'Phase 5+6 editor interactions' -Action {
    flutter test test/features/paper_composer/word_object_editor_layer_phase56_test.dart
}

Invoke-GateStep -Name 'Phase 3+4 freeform manipulation regression' -Action {
    flutter test test/features/paper_composer/word_object_manipulation_phase34_test.dart
}

Invoke-GateStep -Name 'Phase 3+4 floating editor regression' -Action {
    flutter test test/features/paper_composer/word_object_editor_layer_phase34_test.dart
}

Invoke-GateStep -Name 'Persisted Word object metadata regression' -Action {
    flutter test test/features/paper_composer/word_shapes_phase4b_test.dart
}

Invoke-GateStep -Name 'Read-only Word object preview regression' -Action {
    flutter test test/features/paper_composer/word_shape_preview_phase4b_test.dart
}

Invoke-GateStep -Name 'Unified document projection regression' -Action {
    flutter test test/features/paper_composer/question_document_projection_test.dart
}

Invoke-GateStep -Name 'Geometry print/editor separation regression' -Action {
    flutter test test/features/paper_composer/geometry_print_surface_boundary_test.dart
}

Invoke-GateStep -Name 'PDF/DOCX object and geometry fidelity' -Action {
    flutter test test/features/pdf/office_export_services_test.dart
}

Invoke-GateStep -Name 'Structured paper preview regression' -Action {
    flutter test test/features/paper_composer/paper_preview_advanced_content_test.dart
}

Write-Host ""
Write-Host "Question Document Phase 5+6 gate PASSED"
