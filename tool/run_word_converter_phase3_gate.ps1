$ErrorActionPreference = 'Stop'

function Invoke-GateStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command
    )

    Write-Host "`n==> $Name"
    & $Command
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Host "`nWord Converter Phase 3 gate FAILED at: $Name" -ForegroundColor Red
        exit $exitCode
    }
}

Write-Host 'EduSheet Word Converter Phase 3 release gate'
Write-Host 'Scope: geometry-aware editable PDF-to-Word reconstruction'

Invoke-GateStep -Name 'Static analysis' -Command {
    flutter analyze --no-pub
}

Invoke-GateStep -Name 'Phase 1+2 DOCX structured parser regression' -Command {
    flutter test test/features/word_converter/docx_conversion_parser_test.dart
}

Invoke-GateStep -Name 'PDF editable geometry reconstruction' -Command {
    flutter test test/features/word_converter/pdf_editable_reconstructor_test.dart
}

Invoke-GateStep -Name 'Editable DOCX writer structure' -Command {
    flutter test test/features/word_converter/editable_docx_writer_test.dart
}

Invoke-GateStep -Name 'Converter service regression' -Command {
    flutter test test/features/word_converter/word_converter_service_test.dart
}

Invoke-GateStep -Name 'Converter UI capability/naming regression' -Command {
    flutter test test/features/word_converter/word_converter_screen_test.dart
}

Write-Host "`nWord Converter Phase 3 gate PASSED" -ForegroundColor Green
exit 0
