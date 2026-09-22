$ErrorActionPreference = "Stop"

Write-Host "EduSheet Smart Editor Phase W6 production hardening gate"
Write-Host "Scope: W1-W5 regressions, crash recovery, lazy autosave, save-before-pop, large-document durability, responsive UI and interoperability"

function Run-Step([string]$Name, [scriptblock]$Action) {
    Write-Host ""
    Write-Host "==> $Name"
    & $Action
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Smart Editor Phase W6 gate FAILED at: $Name" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Run-Step "Static analysis" { flutter analyze --no-pub }
Run-Step "W1 regression" { flutter test test/features/smart_editor/smart_editor_w1_test.dart }
Run-Step "W2 regression" { flutter test test/features/smart_editor/smart_editor_w2_test.dart }
Run-Step "W3 Math + Geometry regression" { flutter test test/features/smart_editor/smart_editor_w3_test.dart }
Run-Step "W4 Smart/WPS regression" { flutter test test/features/smart_editor/smart_editor_w4_test.dart }
Run-Step "W5 DOCX/PDF interoperability and responsive regression" { flutter test test/features/smart_editor/smart_editor_w5_test.dart }
Run-Step "W6 production hardening" { flutter test test/features/smart_editor/smart_editor_w6_test.dart }
Run-Step "Autosave coordinator regression" { flutter test test/features/editor/autosave_coordinator_test.dart }
Run-Step "Atomic persistence regression" { flutter test test/shared/persistence/atomic_json_file_store_test.dart }
Run-Step "DOCX parser regression" { flutter test test/features/word_converter/docx_conversion_parser_test.dart }
Run-Step "Editable DOCX writer regression" { flutter test test/features/word_converter/editable_docx_writer_test.dart }
Run-Step "Math keyboard regression" { flutter test test/features/math_keyboard/formula_editor_sheet_test.dart }
Run-Step "Geometry embed regression" { flutter test test/features/geometry_builder/geometry_embed_layout_phase4c_test.dart }
Run-Step "Dual editor regression" { flutter test test/features/paper_composer/dual_editor_mode_test.dart }
Run-Step "User manual regression" { flutter test test/features/guided_experience/user_manual_guide_coverage_test.dart }

Write-Host ""
Write-Host "Smart Editor Phase W6 production hardening gate PASSED" -ForegroundColor Green
