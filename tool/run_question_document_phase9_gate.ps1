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
        Write-Host "Question Document Phase 9 gate FAILED at: $Name"
        exit $LASTEXITCODE
    }
}

Write-Host "EduSheet Question Document Phase 9 production certification gate"
Write-Host "Scope: Preview/PDF/DOCX fidelity, Unicode-safe geometry, explicit pagination, editor-chrome isolation, production audit"

Invoke-GateStep -Name 'Dependency resolution' -Action {
    flutter pub get
}

Invoke-GateStep -Name 'Static analysis' -Action {
    flutter analyze --no-pub
}

Invoke-GateStep -Name 'Phase 9 end-to-end fidelity certification' -Action {
    flutter test test/features/paper_composer/question_document_phase9_fidelity_test.dart
}

Invoke-GateStep -Name 'Canonical Smart Paper round-trip regression' -Action {
    flutter test test/features/paper_composer/smart_paper_docx_round_trip_service_test.dart
    flutter test test/features/paper_composer/question_math_validation_service_test.dart
}

Invoke-GateStep -Name 'Unicode/offline PDF font-plan regression' -Action {
    flutter test test/features/pdf/pdf_export_theme_service_test.dart
}

Invoke-GateStep -Name 'Preview/PDF/Word semantic parity regression' -Action {
    flutter test test/release/smart_paper_export_parity_gate_test.dart
}

Invoke-GateStep -Name 'Office export regression' -Action {
    flutter test test/features/pdf/office_export_services_test.dart
}

Invoke-GateStep -Name 'Phase 8 interaction regression' -Action {
    flutter test test/features/paper_composer/word_interaction_phase8_test.dart
}

Invoke-GateStep -Name 'Phase 7 page tools regression' -Action {
    flutter test test/features/paper_composer/page_tools_phase7_test.dart
    flutter test test/features/pdf/page_tools_export_phase7_test.dart
}

Invoke-GateStep -Name 'Phase 5+6 anchoring/geometry regression' -Action {
    flutter test test/features/paper_composer/word_pagination_geometry_phase56_test.dart
    flutter test test/features/paper_composer/word_object_editor_layer_phase56_test.dart
}

Invoke-GateStep -Name 'Phase 3+4 floating-object regression' -Action {
    flutter test test/features/paper_composer/word_object_editor_layer_phase34_test.dart
    flutter test test/features/paper_composer/word_object_manipulation_phase34_test.dart
}

Invoke-GateStep -Name 'Geometry print/editor boundary regression' -Action {
    flutter test test/features/paper_composer/geometry_print_surface_boundary_test.dart
}

Write-Host ""
Write-Host "Question Document Phase 9 gate PASSED"
