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
        Write-Host "Question Document Phase 7 gate FAILED at: $Name"
        exit $LASTEXITCODE
    }
}

Write-Host "EduSheet Question Document Phase 7 release gate"
Write-Host "Scope: professional page tools, columns, watermark/background, ruler/grid editor chrome, PDF/DOCX fidelity"

Invoke-GateStep -Name 'Static analysis' -Action {
    flutter analyze --no-pub
}

Invoke-GateStep -Name 'Phase 7 canonical page tools and editor chrome' -Action {
    flutter test test/features/paper_composer/page_tools_phase7_test.dart
}

Invoke-GateStep -Name 'Phase 7 PDF/DOCX page design fidelity' -Action {
    flutter test test/features/pdf/page_tools_export_phase7_test.dart
}

Invoke-GateStep -Name 'Phase 5+6 anchoring and geometry regression' -Action {
    flutter test test/features/paper_composer/word_pagination_geometry_phase56_test.dart
}

Invoke-GateStep -Name 'Phase 5+6 editor interaction regression' -Action {
    flutter test test/features/paper_composer/word_object_editor_layer_phase56_test.dart
}

Invoke-GateStep -Name 'Phase 3+4 floating editor regression' -Action {
    flutter test test/features/paper_composer/word_object_editor_layer_phase34_test.dart
}

Invoke-GateStep -Name 'Unified document projection regression' -Action {
    flutter test test/features/paper_composer/question_document_projection_test.dart
}

Invoke-GateStep -Name 'Geometry print/editor separation regression' -Action {
    flutter test test/features/paper_composer/geometry_print_surface_boundary_test.dart
}

Invoke-GateStep -Name 'Office export regression' -Action {
    flutter test test/features/pdf/office_export_services_test.dart
}

Write-Host ""
Write-Host "Question Document Phase 7 gate PASSED"
