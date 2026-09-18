$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $projectRoot
try {
  Write-Host "==> Static analysis" -ForegroundColor Cyan
  flutter analyze --no-pub
  if ($LASTEXITCODE -ne 0) { throw "Static analysis failed." }

  $testTargets = @(
    'test/core/navigation',
    'test/features/guided_experience',
    'test/features/teaching_planner/syllabus_manager_screen_test.dart',
    'test/features/teaching_planner/teaching_planner_screen_test.dart'
  )

  foreach ($target in $testTargets) {
    if (Test-Path $target) {
      Write-Host "==> $target" -ForegroundColor Cyan
      flutter test $target
      if ($LASTEXITCODE -ne 0) { throw "$target failed." }
    }
  }

  Write-Host "Phase 8 overlay precision gate PASSED." -ForegroundColor Green
}
finally {
  Pop-Location
}
