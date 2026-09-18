param(
    [switch]$FullSuite,
    [switch]$BuildAndroid,
    [switch]$BuildWindows
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

function Invoke-GateCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [Parameter(Mandatory = $true)]
        [string]$Executable,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    Write-Host "`n==> $Label" -ForegroundColor Cyan
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
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

Push-Location $projectRoot
try {
    Write-Host 'EduSheet Document Reader Phase 8 production release gate' -ForegroundColor Cyan
    Write-Host 'Baseline: Phase 7 Presentation Overflow + Analyzer Hotfix'

    Invoke-GateCommand `
        -Label 'Static analysis' `
        -Executable 'flutter' `
        -Arguments @('analyze', '--no-pub')

    $focusedTests = @(
        'test/features/document_reader/document_reader_phase8_responsive_gate_test.dart',
        'test/features/document_reader/word_document_viewer_loading_regression_test.dart',
        'test/features/document_reader/word_document_viewer_performance_regression_test.dart',
        'test/features/document_reader/document_viewport_policy_test.dart',
        'test/features/document_reader/presentation_stage_policy_test.dart',
        'test/features/document_reader/document_viewer_widget_test.dart',
        'test/features/document_reader/presentation_animation_timeline_test.dart',
        'test/features/document_reader/presentation_animation_parser_test.dart',
        'test/features/document_reader/presentation_theme_master_layout_test.dart',
        'test/features/document_reader/presentation_parser_service_test.dart',
        'test/features/document_reader/document_open_architecture_test.dart',
        'test/features/document_reader/spreadsheet_parser_service_test.dart',
        'test/release/document_reader_phase8_production_gate_test.dart'
    )

    foreach ($testFile in $focusedTests) {
        Invoke-GateCommand `
            -Label "Document Reader regression: $testFile" `
            -Executable 'flutter' `
            -Arguments @('test', $testFile)
    }

    if ($FullSuite) {
        Invoke-GateCommand `
            -Label 'Full EduSheet regression suite' `
            -Executable 'flutter' `
            -Arguments @('test')
    }

    if ($BuildAndroid) {
        Invoke-GateCommand `
            -Label 'Android release build' `
            -Executable 'flutter' `
            -Arguments @('build', 'apk', '--release')

        Assert-ReleaseArtifact `
            -CandidatePaths @('build\app\outputs\flutter-apk\app-release.apk') `
            -ArtifactName 'Android release APK'
    }

    if ($BuildWindows) {
        Invoke-GateCommand `
            -Label 'Windows release build' `
            -Executable 'flutter' `
            -Arguments @('build', 'windows', '--release')

        Assert-ReleaseArtifact `
            -CandidatePaths @(
                'build\windows\x64\runner\Release\edusheet.exe',
                'build\windows\runner\Release\edusheet.exe'
            ) `
            -ArtifactName 'Windows release executable'
    }

    Write-Host "`nAutomated Document Reader Phase 8 gate PASSED." -ForegroundColor Green
    Write-Host 'Manual RC lock still requires real-file smoke tests on Android and Windows:' -ForegroundColor Yellow
    Write-Host '  PDF: fit width, fit page, search, zoom, page jump.' -ForegroundColor Yellow
    Write-Host '  DOCX: phone fit-width, search, pinch zoom, desktop print layout.' -ForegroundColor Yellow
    Write-Host '  PPTX: theme/master fidelity, animation sequence, overview, fullscreen enter/exit.' -ForegroundColor Yellow
}
catch {
    Write-Host "`nDocument Reader Phase 8 gate FAILED." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    throw
}
finally {
    Pop-Location
}
