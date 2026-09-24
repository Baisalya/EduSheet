param(
    [switch]$SkipReleaseBuilds,
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
Write-Both "Targets: Windows release + Android App Bundle + DF1-DF6 regression chain"
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

if (-not $SkipReleaseBuilds) {
    Invoke-Step "Windows release build" {
        flutter build windows --release --no-pub
    }

    Invoke-Step "Android production App Bundle" {
        # Do not use --no-pub here. Flutter can otherwise generate a release
        # registrant that still references the dev-only integration_test plugin.
        flutter build appbundle --release
    }

    $WindowsRelease = ".\build\windows\x64\runner\Release"
    $WindowsExe = Get-ChildItem `
        -Path $WindowsRelease `
        -Filter *.exe `
        -File `
        -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending |
        Select-Object -First 1

    $AndroidAab = ".\build\app\outputs\bundle\release\app-release.aab"

    Invoke-Step "Release artifact integrity" {
        if ($null -eq $WindowsExe) {
            throw "Windows release EXE was not found."
        }

        if (-not $WindowsExe.Exists -or $WindowsExe.Length -le 0) {
            throw "Windows release EXE is empty."
        }

        if (-not (Test-Path $AndroidAab)) {
            throw "Android app-release.aab was not found."
        }

        $aab = Get-Item $AndroidAab
        if ($aab.Length -le 0) {
            throw "Android app-release.aab is empty."
        }

        Write-Host (
            "Windows EXE: {0} ({1:N0} bytes)" -f
            $WindowsExe.FullName,
            $WindowsExe.Length
        )
        Write-Host (
            "Android AAB: {0} ({1:N0} bytes)" -f
            $aab.FullName,
            $aab.Length
        )
    }

    $WindowsHash = (Get-FileHash -Algorithm SHA256 $WindowsExe.FullName).Hash
    $AndroidItem = Get-Item $AndroidAab
    $AndroidHash = (Get-FileHash -Algorithm SHA256 $AndroidItem.FullName).Hash

    $successReport = @(
        "EduSheet DOCX DF6 - PRODUCTION CERTIFICATION",
        "Status: PASSED",
        ("Timestamp: " + (Get-Date -Format o)),
        "",
        "Certified scope",
        "---------------",
        "- Flutter static analysis",
        "- DF6 production-like academic DOCX parsing",
        "- malformed-DOCX deterministic failure handling",
        "- 320x520 responsive/lazy Word viewport",
        "- 1440x900 desktop Word viewport",
        "- complete DF5 gate",
        "- document_reader regression suite",
        "- smart_editor regression suite",
        "- Windows release build",
        "- Android production App Bundle build",
        "- release artifact size verification",
        "- SHA-256 release hashes",
        "",
        "Windows artifact",
        "----------------",
        ("Path: " + $WindowsExe.FullName),
        ("Size: " + $WindowsExe.Length + " bytes"),
        ("SHA256: " + $WindowsHash),
        "",
        "Android artifact",
        "----------------",
        ("Path: " + $AndroidItem.FullName),
        ("Size: " + $AndroidItem.Length + " bytes"),
        ("SHA256: " + $AndroidHash),
        "",
        "Run log",
        "-------",
        $LogPath
    )

    Set-Content -Path $ReportPath -Value $successReport -Encoding UTF8
}
else {
    $testReport = @(
        "EduSheet DOCX DF6 - TEST CERTIFICATION",
        "Status: PASSED (release builds intentionally skipped)",
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
        "Release binaries were NOT certified because -SkipReleaseBuilds was supplied.",
        "",
        ("Run log: " + $LogPath)
    )

    Set-Content -Path $ReportPath -Value $testReport -Encoding UTF8
}

Write-Both ""
Write-Both "============================================================"
Write-Both "DF6 REAL-WORLD PRODUCTION CERTIFICATION PASSED"
Write-Both ("Report: " + $ReportPath)
Write-Both ("Log:    " + $LogPath)
Write-Both "============================================================"
