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

function Assert-ReleaseArtifact {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$CandidatePaths,

    [Parameter(Mandatory = $true)]
    [string]$ArtifactName
  )

  foreach ($candidate in $CandidatePaths) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      $file = Get-Item -LiteralPath $candidate
      if ($file.Length -le 0) {
        throw "$ArtifactName exists but is empty: $candidate"
      }

      $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $candidate
      Write-Host "$ArtifactName verified: $candidate" -ForegroundColor Green
      Write-Host "  Size: $($file.Length) bytes"
      Write-Host "  SHA256: $($hash.Hash)"
      return
    }
  }

  throw "$ArtifactName was not found. Checked: $($CandidatePaths -join ', ')"
}

try {
  Write-Host 'EduSheet RC Candidate 2 final validation gate' -ForegroundColor Cyan
  Write-Host 'Baseline: Professional Formatting Phase 3 QA Fix 1'

  Write-Host '1/7 Formatting check'
  $formatTargets = @('lib', 'test')
  if (Test-Path -LiteralPath 'integration_test' -PathType Container) {
    $formatTargets += 'integration_test'
  }
  $formatArgs = @('format', '--output=none', '--set-exit-if-changed') + $formatTargets
  Invoke-CheckedNative `
    -Command 'dart' `
    -Arguments $formatArgs `
    -StepName 'Formatting check'

  Write-Host '2/7 Static analysis'
  Invoke-CheckedNative `
    -Command 'flutter' `
    -Arguments @('analyze') `
    -StepName 'Static analysis'

  Write-Host '3/7 RC2 focused production tests'
  $focusedTests = @(
    @('test/features/pdf/pdf_export_theme_service_test.dart', 'Offline PDF font-plan tests'),
    @('test/features/editor/autosave_coordinator_test.dart', 'Autosave coordinator tests'),
    @('test/features/editor/large_paper_performance_test.dart', 'Large-paper performance tests'),
    @('test/features/editor/paper_page_layout_test.dart', 'Page-layout tests'),
    @('test/features/paper_composer/dual_editor_mode_test.dart', 'Dual-editor tests'),
    @('test/features/paper_composer/wysiwyg_header_phase3_test.dart', 'WYSIWYG header tests'),
    @('test/features/paper_composer/smart_paper_docx_round_trip_service_test.dart', 'Smart/Word DOCX round-trip tests'),
    @('test/features/pdf/office_export_services_test.dart', 'Office export tests'),
    @('test/release/rc_candidate_2_final_gate_test.dart', 'RC2 final integration gate')
  )

  foreach ($entry in $focusedTests) {
    Invoke-CheckedNative `
      -Command 'flutter' `
      -Arguments @('test', $entry[0]) `
      -StepName $entry[1]
  }

  Write-Host '4/7 Release gates'
  Invoke-CheckedNative `
    -Command 'flutter' `
    -Arguments @('test', 'test/release') `
    -StepName 'Release gates'

  Write-Host '5/7 Full regression suite'
  Invoke-CheckedNative `
    -Command 'flutter' `
    -Arguments @('test') `
    -StepName 'Full regression suite'

  Write-Host '6/7 Optional production builds'
  if ($BuildWindows) {
    Write-Host 'Building Windows release...'
    Invoke-CheckedNative `
      -Command 'flutter' `
      -Arguments @('build', 'windows', '--release') `
      -StepName 'Windows release build'

    Assert-ReleaseArtifact `
      -CandidatePaths @(
        'build\windows\x64\runner\Release\edusheet.exe',
        'build\windows\runner\Release\edusheet.exe'
      ) `
      -ArtifactName 'Windows release executable'
  }

  if ($BuildAndroid) {
    Write-Host 'Building Android release APK...'
    Invoke-CheckedNative `
      -Command 'flutter' `
      -Arguments @('build', 'apk', '--release') `
      -StepName 'Android release APK build'

    Assert-ReleaseArtifact `
      -CandidatePaths @('build\app\outputs\flutter-apk\app-release.apk') `
      -ArtifactName 'Android release APK'
  }

  if (-not $BuildWindows -and -not $BuildAndroid) {
    Write-Host 'Build step skipped. Re-run with -BuildWindows -BuildAndroid for the production build gate.'
  }

  Write-Host '7/7 Manual real-device release gate reminder'
  Write-Host 'Automated validation is green only if this script reaches this point.' -ForegroundColor Green
  Write-Host 'RC2 is NOT release-locked until Windows + Android manual smoke passes,' -ForegroundColor Yellow
  Write-Host 'including offline English/Hindi/Odia/math PDF glyph inspection.' -ForegroundColor Yellow
  Write-Host ''
  Write-Host 'EduSheet RC Candidate 2 automated gate PASSED.' -ForegroundColor Green
} catch {
  Write-Host ''
  Write-Host 'EduSheet RC Candidate 2 gate FAILED.' -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  throw
}
