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
        Write-Host "Question Document Phase 1+2 gate FAILED at: $Name"
        exit $LASTEXITCODE
    }
}

Write-Host "EduSheet Question Document Phase 1+2 release gate"
Write-Host "Scope: clean editor/print separation, unclipped geometry preview, canonical printable content projection"

Invoke-GateStep -Name 'Static analysis' -Action {
    flutter analyze --no-pub
}

Invoke-GateStep -Name 'Printable content projection' -Action {
    flutter test test/features/paper_composer/question_print_content_projection_test.dart
}

Invoke-GateStep -Name 'Persisted question/paper document projection' -Action {
    flutter test test/features/paper_composer/question_document_projection_test.dart
}

Invoke-GateStep -Name 'Universal question persisted-vs-draft parity' -Action {
    flutter test test/features/paper_composer/universal_question_document_test.dart
}

Invoke-GateStep -Name 'Geometry editor/print surface boundary' -Action {
    flutter test test/features/paper_composer/geometry_print_surface_boundary_test.dart
}

Invoke-GateStep -Name 'Geometry placement persistence baseline' -Action {
    flutter test test/features/geometry_builder/geometry_embed_layout_phase4c_test.dart
}

Invoke-GateStep -Name 'Office printable text boundary' -Action {
    flutter test test/features/pdf/office_text_formatter_test.dart
}

Invoke-GateStep -Name 'PDF/DOCX export regression' -Action {
    flutter test test/features/pdf/office_export_services_test.dart
}

Invoke-GateStep -Name 'Paper preview structured-content regression' -Action {
    flutter test test/features/paper_composer/paper_preview_advanced_content_test.dart
}

Invoke-GateStep -Name 'Question editor Material regression' -Action {
    flutter test test/features/paper_composer/question_editor_material_surface_test.dart
}

Write-Host ""
Write-Host "Question Document Phase 1+2 gate PASSED"
