param(
  [switch]$FullRegression,
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
  Write-Host 'EduSheet Calculator Phase 7 release gate' -ForegroundColor Cyan
  Write-Host 'Baseline: Phase 7 Full QA + QA Fix 4'

  Write-Host '1/7 Calculator formatting check'
  Invoke-CheckedNative `
    -Command 'dart' `
    -Arguments @(
      'format',
      '--output=none',
      '--set-exit-if-changed',
      'lib/features/calculator',
      'test/features/calculator'
    ) `
    -StepName 'Calculator formatting check'

  Write-Host '2/7 Static analysis'
  Invoke-CheckedNative `
    -Command 'flutter' `
    -Arguments @('analyze') `
    -StepName 'Static analysis'

  Write-Host '3/7 Cross-phase calculator release contracts'
  $releaseTests = @(
    'test/features/calculator/calculator_release_gate_test.dart',
    'test/features/calculator/calculator_screen_release_gate_test.dart'
  )
  foreach ($testPath in $releaseTests) {
    Invoke-CheckedNative `
      -Command 'flutter' `
      -Arguments @('test', $testPath) `
      -StepName "Release contract: $testPath"
  }

  Write-Host '4/7 Full calculator regression suite'
  Invoke-CheckedNative `
    -Command 'flutter' `
    -Arguments @('test', 'test/features/calculator') `
    -StepName 'Full calculator regression suite'

  Write-Host '5/7 Optional whole-app regression suite'
  if ($FullRegression) {
    Invoke-CheckedNative `
      -Command 'flutter' `
      -Arguments @('test') `
      -StepName 'Whole-app regression suite'
  } else {
    Write-Host 'Whole-app regression skipped. Re-run with -FullRegression before a store release.' -ForegroundColor Yellow
  }

  Write-Host '6/7 Optional production builds'
  if ($BuildWindows) {
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
    Invoke-CheckedNative `
      -Command 'flutter' `
      -Arguments @('build', 'apk', '--release') `
      -StepName 'Android release APK build'

    Assert-ReleaseArtifact `
      -CandidatePaths @('build\app\outputs\flutter-apk\app-release.apk') `
      -ArtifactName 'Android release APK'
  }

  if (-not $BuildWindows -and -not $BuildAndroid) {
    Write-Host 'Build gate skipped. Add -BuildWindows and/or -BuildAndroid when validating production artifacts.' -ForegroundColor Yellow
  }

  Write-Host '7/7 Manual calculator smoke gate' -ForegroundColor Cyan
  Write-Host 'Windows: resize 500x480, 700x500, 900x500, 1100x760; verify no overflow.'
  Write-Host 'Windows: mouse caret, selection, Backspace/Delete, Home/End, Shift+Arrow, Ctrl+A, numpad.'
  Write-Host 'Android: tap caret, selection handles, keypad insertion, long-expression horizontal scrolling.'
  Write-Host 'Both: DEG/RAD trig, factorial/nCr/nPr, EXP tiny/large values, division-by-zero/domain errors.'
  Write-Host 'Both: Physics + Chemistry formula solver, validation, Insert result, Insert calculation, history reuse.'
  Write-Host ''
  Write-Host 'Calculator automated release gate PASSED.' -ForegroundColor Green
  if (-not $FullRegression) {
    Write-Host 'Store release still requires -FullRegression plus required production builds and manual smoke.' -ForegroundColor Yellow
  }
} catch {
  Write-Host ''
  Write-Host 'Calculator release gate FAILED.' -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  throw
}
