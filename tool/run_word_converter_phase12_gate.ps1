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
        Write-Host "`nWord Converter Phase 1+2 gate FAILED at: $Name" -ForegroundColor Red
        exit $exitCode
    }
}

Write-Host 'EduSheet Word Converter Phase 1+2 release gate'
Write-Host 'Scope: conversion architecture + professional Word-to-PDF fidelity'

Invoke-GateStep -Name 'Static analysis' -Command {
    flutter analyze --no-pub
}

Invoke-GateStep -Name 'DOCX structured parser' -Command {
    flutter test test/features/word_converter/docx_conversion_parser_test.dart
}

Invoke-GateStep -Name 'Converter service regression' -Command {
    flutter test test/features/word_converter/word_converter_service_test.dart
}

Invoke-GateStep -Name 'Converter UI capability/naming' -Command {
    flutter test test/features/word_converter/word_converter_screen_test.dart
}

Write-Host "`nWord Converter Phase 1+2 gate PASSED" -ForegroundColor Green
exit 0
