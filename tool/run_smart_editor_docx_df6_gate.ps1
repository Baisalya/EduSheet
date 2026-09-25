param(
    [switch]$CleanBuild
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ProjectRoot = (Get-Location).Path
$CertificationDir = Join-Path $ProjectRoot "build\df6_certification"
$LogPath = Join-Path $CertificationDir "DF6_RUN_LOG.txt"
$ReportPath = Join-Path $CertificationDir "DF6_PRODUCTION_CERTIFICATION.txt"

New-Item -ItemType Directory -Force -Path $CertificationDir | Out-Null
if (Test-Path $LogPath) {
    Remove-Item $LogPath -Force
}

function Write-Both {
    param([string]$Text = "")
    Write-Host $Text
    Add-Content -Path $LogPath -Value $Text
}

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    Write-Both ""
    Write-Both ("==> " + $Name)
    $started = Get-Date

    # PowerShell-only steps do not update LASTEXITCODE. Reset it so a stale or
    # null value cannot fail a successful preflight/integrity step.
    $global:LASTEXITCODE = 0


    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $Action 2>&1 | Tee-Object -FilePath $LogPath -Append

        $nativeExitCode = $global:LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference
        if ($nativeExitCode -ne 0) {
            throw ("Native command exit code " + $nativeExitCode)
        }
    }
    catch {
        $ErrorActionPreference = $previousErrorActionPreference
        $elapsed = (Get-Date) - $started
        Write-Both ""
        Write-Both ("DF6 FAILED at: " + $Name)
        Write-Both ("Elapsed: {0:N1}s" -f $elapsed.TotalSeconds)
        Write-Both ("Reason: " + $_.Exception.Message)

        $failureReport = @(
            "EduSheet DOCX DF6 - PRODUCTION CERTIFICATION",
            "Status: FAILED",
            ("Failed step: " + $Name),
            ("Timestamp: " + (Get-Date -Format o)),
            ("Log: " + $LogPath)
        )
        Set-Content -Path $ReportPath -Value $failureReport -Encoding UTF8
        throw
    }

    $elapsed = (Get-Date) - $started
    Write-Both ("PASS: {0} ({1:N1}s)" -f $Name, $elapsed.TotalSeconds)
}

Write-Both "EduSheet Smart Editor DOCX DF6 - Real-World Production Certification"
Write-Both "Target: QA-only DF1-DF6 regression chain (no release artifact build)"
Write-Both ("Started: " + (Get-Date -Format o))

Invoke-Step "Project preflight" {
    if (-not (Test-Path ".\pubspec.yaml")) {
        throw "Run this gate from the EduSheet project root. pubspec.yaml was not found."
    }

    $FidelityView = ".\lib\features\document_reader\presentation\widgets\viewers\word_fidelity_document_view.dart"
    if (-not (Test-Path $FidelityView)) {
        throw ("Missing file: " + $FidelityView)
    }

    $source = Get-Content $FidelityView -Raw
    if ($source -notmatch 'ScrollCacheExtent\.pixels\s*\(') {
        throw "DF5 ScrollCacheExtent.pixels(...) hotfix is not present."
    }

    if ($source -match '(?m)^\s*cacheExtent\s*:') {
        throw "Deprecated raw cacheExtent argument is still present."
    }

    if (-not (Test-Path ".\tool\run_smart_editor_docx_df5_gate.ps1")) {
        throw "DF5 gate is missing."
    }

    if (-not (Test-Path ".\test\features\document_reader\word_docx_df6_production_certification_test.dart")) {
        throw "DF6 production certification test is missing."
    }

    Write-Host "Project and DF5 migration preflight PASS"
}

Invoke-Step "Flutter version" {
    flutter --version
}

Invoke-Step "Dart version" {
    dart --version
}

if ($CleanBuild) {
    Invoke-Step "Clean build workspace" {
        flutter clean
    }
}

Invoke-Step "Dependency resolution" {
    flutter pub get
}

Invoke-Step "Static analysis" {
    flutter analyze --no-pub
}

Invoke-Step "DF6 production-like DOCX certification" {
    flutter test test/features/document_reader/word_docx_df6_production_certification_test.dart
}

Invoke-Step "DF5 complete DOCX regression gate" {
    powershell -ExecutionPolicy Bypass -File .\tool\run_smart_editor_docx_df5_gate.ps1
}

Invoke-Step "Document reader regression suite" {
    flutter test test/features/document_reader
}

Invoke-Step "Smart Editor regression suite" {
    flutter test test/features/smart_editor
}

$testReport = @(
    "EduSheet DOCX DF6 - TEST CERTIFICATION",
    "Status: PASSED (QA only; no release artifact was built)",
    ("Timestamp: " + (Get-Date -Format o)),
    "",
    "Passed",
    "------",
    "- static analysis",
    "- DF6 production-like DOCX certification",
    "- complete DF5 regression gate",
    "- document_reader regression suite",
    "- smart_editor regression suite",
    "",
    "AAB/MSIX generation is a separate packaging action.",
    "",
    ("Run log: " + $LogPath)
)

Set-Content -Path $ReportPath -Value $testReport -Encoding UTF8
Write-Both ""
Write-Both "============================================================"
Write-Both "DF6 REAL-WORLD QA CERTIFICATION PASSED"
Write-Both ("Report: " + $ReportPath)
Write-Both ("Log:    " + $LogPath)
Write-Both "============================================================"
