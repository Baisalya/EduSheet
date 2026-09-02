Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-CheckedNative {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Command,

    [Parameter(Mandatory = $true)]
    [string[]]$Arguments,

    [Parameter(Mandatory = $true)]
    [string]$StepName
  )

  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$StepName failed with exit code $LASTEXITCODE."
  }
}

try {
  Write-Host 'EduSheet Professional Formatting Phase 4C gate' -ForegroundColor Cyan
  Write-Host 'Baseline: Phase 4B QA Fix 1 / automated +346 green'

  Write-Host '1/6 Formatting check'
  $formatTargets = @('lib', 'test')
  if (Test-Path -LiteralPath 'integration_test' -PathType Container) {
    $formatTargets += 'integration_test'
  }
  $formatArgs = @('format', '--output=none', '--set-exit-if-changed') + $formatTargets
  Invoke-CheckedNative -Command 'dart' -Arguments $formatArgs -StepName 'Formatting check'

  Write-Host '2/6 Static analysis'
  Invoke-CheckedNative -Command 'flutter' -Arguments @('analyze') -StepName 'Static analysis'

  Write-Host '3/6 Phase 4C focused tests'
  $focusedTests = @(
    @('test/features/geometry_builder/geometry_freeform_phase4c_test.dart', 'Phase 4C free-form geometry tests'),
    @('test/features/geometry_builder/geometry_embed_layout_phase4c_test.dart', 'Phase 4C geometry placement tests'),
    @('test/features/paper_composer/word_shapes_phase4b_test.dart', 'Phase 4B shape regression'),
    @('test/features/paper_composer/word_shape_preview_phase4b_test.dart', 'Phase 4B preview regression'),
    @('test/features/paper_composer/word_direct_authoring_phase4a_test.dart', 'Phase 4A direct authoring regression'),
    @('test/features/paper_composer/smart_paper_docx_round_trip_service_test.dart', 'Smart Word round-trip regression'),
    @('test/features/pdf/office_export_services_test.dart', 'PDF/DOCX export parity tests'),
    @('test/release/professional_formatting_phase4c_gate_test.dart', 'Phase 4C release gate')
  )

  foreach ($entry in $focusedTests) {
    Invoke-CheckedNative -Command 'flutter' -Arguments @('test', $entry[0]) -StepName $entry[1]
  }

  Write-Host '4/6 Release tests'
  Invoke-CheckedNative -Command 'flutter' -Arguments @('test', 'test/release') -StepName 'Release tests'

  Write-Host '5/6 Full regression suite'
  Invoke-CheckedNative -Command 'flutter' -Arguments @('test') -StepName 'Full regression suite'

  Write-Host '6/6 Manual smoke reminder'
  Write-Host 'Verify Free-form Geometry on narrow Android and resized Windows:' -ForegroundColor Yellow
  Write-Host 'Point/Line/Arrow/Circle/Angle/Axes/Number line, grid+snap, edit/undo/redo,' -ForegroundColor Yellow
  Write-Host 'geometry width/alignment/spacing/wrap controls, Smart<->Word, Preview, PDF and DOCX.' -ForegroundColor Yellow
  Write-Host ''
  Write-Host 'EduSheet Phase 4C automated gate PASSED.' -ForegroundColor Green
} catch {
  Write-Host ''
  Write-Host 'EduSheet Phase 4C gate FAILED.' -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  throw
}
