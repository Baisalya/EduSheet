param(
  [switch]$BuildWindows,
  [switch]$BuildAndroid
)

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
  Write-Host 'EduSheet RC Candidate 1 production gate' -ForegroundColor Cyan

  Write-Host '1/6 Formatting check'
  Invoke-CheckedNative `
    -Command 'dart' `
    -Arguments @('format', '--output=none', '--set-exit-if-changed', 'lib', 'test') `
    -StepName 'Formatting check'

  Write-Host '2/6 Static analysis'
  Invoke-CheckedNative `
    -Command 'flutter' `
    -Arguments @('analyze') `
    -StepName 'Static analysis'

  Write-Host '3/6 RC1 focused production tests'
  Invoke-CheckedNative `
    -Command 'flutter' `
    -Arguments @('test', 'test/features/pdf/pdf_export_theme_service_test.dart') `
    -StepName 'PDF export theme tests'
  Invoke-CheckedNative `
    -Command 'flutter' `
    -Arguments @('test', 'test/features/editor/autosave_coordinator_test.dart') `
    -StepName 'Autosave coordinator tests'
  Invoke-CheckedNative `
    -Command 'flutter' `
    -Arguments @('test', 'test/features/editor/large_paper_performance_test.dart') `
    -StepName 'Large paper performance tests'
  Invoke-CheckedNative `
    -Command 'flutter' `
    -Arguments @('test', 'test/features/paper_composer/dual_editor_mode_test.dart') `
    -StepName 'Dual editor mode tests'

  Write-Host '4/6 Release gates'
  Invoke-CheckedNative `
    -Command 'flutter' `
    -Arguments @('test', 'test/release') `
    -StepName 'Release gates'

  Write-Host '5/6 Full regression suite'
  Invoke-CheckedNative `
    -Command 'flutter' `
    -Arguments @('test') `
    -StepName 'Full regression suite'

  Write-Host '6/6 Optional production builds'
  if ($BuildWindows) {
    Write-Host 'Building Windows release...'
    Invoke-CheckedNative `
      -Command 'flutter' `
      -Arguments @('build', 'windows', '--release') `
      -StepName 'Windows release build'
  }
  if ($BuildAndroid) {
    Write-Host 'Building Android release APK...'
    Invoke-CheckedNative `
      -Command 'flutter' `
      -Arguments @('build', 'apk', '--release') `
      -StepName 'Android release APK build'
  }
  if (-not $BuildWindows -and -not $BuildAndroid) {
    Write-Host 'Build step skipped. Use -BuildWindows and/or -BuildAndroid when desired.'
  }

  Write-Host 'EduSheet RC Candidate 1 gate passed.' -ForegroundColor Green
} catch {
  Write-Host ''
  Write-Host 'EduSheet RC Candidate 1 gate FAILED.' -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  throw
}
