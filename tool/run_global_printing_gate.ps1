$ErrorActionPreference = "Stop"

Write-Host "EduSheet Global Printing production gate"
Write-Host "Scope: global print source contract, file adapters, responsive Print Center, Smart Editor actions, Create Paper/preview, OMR, PDF/DOCX Reader"

function Run-Step([string]$Name, [scriptblock]$Action) {
    Write-Host ""
    Write-Host "==> $Name"
    & $Action
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Global Printing gate FAILED at: $Name" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Run-Step "Dependency resolution" { flutter pub get }
Run-Step "Static analysis" { flutter analyze --no-pub }
Run-Step "Print source contract" { flutter test test/features/printing/print_document_source_test.dart }
Run-Step "File printing adapters" { flutter test test/features/printing/file_print_source_factory_test.dart }
Run-Step "Print Center responsive entry" { flutter test test/features/printing/print_center_screen_test.dart }
Run-Step "Smart Editor print action regression" { flutter test test/features/smart_editor/smart_editor_open_import_test.dart }
Run-Step "Paper preview regression" { flutter test test/release/smart_paper_export_parity_gate_test.dart }
Run-Step "Document reader open architecture" { flutter test test/features/document_reader/document_open_architecture_test.dart }
Run-Step "Document reader viewer regression" { flutter test test/features/document_reader/document_viewer_widget_test.dart }

Write-Host ""
Write-Host "Global Printing production gate PASSED" -ForegroundColor Green
