$ErrorActionPreference = 'Stop'

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Action
  )
  Write-Host "`n== $Name ==" -ForegroundColor Cyan
  & $Action
  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE."
  }
}

Write-Host 'EduSheet Professional Final Authoring Polish gate' -ForegroundColor Green
Write-Host 'Baseline: Professional Formatting Phase 4C QA Fix 2'

Invoke-Step '1/8 Formatting check' { dart format --output=none --set-exit-if-changed . }
Invoke-Step '2/8 Static analysis' { flutter analyze }
Invoke-Step '3/8 Autosave lifecycle tests' { flutter test test/features/editor/autosave_coordinator_test.dart }
Invoke-Step '4/8 Word/Smart dual editor tests' { flutter test test/features/paper_composer/dual_editor_mode_test.dart }
Invoke-Step '5/8 Direct Word authoring tests' { flutter test test/features/paper_composer/word_direct_authoring_phase4a_test.dart }
Invoke-Step '6/8 Geometry + office export regression tests' {
  flutter test test/features/geometry_builder/geometry_freeform_phase4c_test.dart test/features/pdf/office_export_services_test.dart
}
Invoke-Step '7/8 Release gates' { flutter test test/release }
Invoke-Step '8/8 Full test suite' { flutter test }

Write-Host "`nEduSheet Professional Final Authoring Polish gate PASSED." -ForegroundColor Green
