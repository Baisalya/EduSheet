param(
    [switch]$SkipDependencyResolution
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)] [scriptblock]$Command
    )

    $global:LASTEXITCODE = 0
    & $Command
    $nativeExitCode = $global:LASTEXITCODE
    if ($nativeExitCode -ne 0) {
        throw ("Native command exit code " + $nativeExitCode)
    }
}

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter(Mandatory = $true)] [scriptblock]$Action
    )

    Write-Host ""
    Write-Host ("==> " + $Name) -ForegroundColor Cyan
    $global:LASTEXITCODE = 0
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $Action
        $nativeExitCode = $global:LASTEXITCODE
        $ErrorActionPreference = $previous
        if ($nativeExitCode -ne 0) {
            throw ("Native command exit code " + $nativeExitCode)
        }
    }
    catch {
        $ErrorActionPreference = $previous
        Write-Host ""
        Write-Host ("WM7+WM8 gate FAILED at: " + $Name) -ForegroundColor Red
        throw
    }
}

Write-Host "EduSheet Word Maturity WM7 + WM8 Gate" -ForegroundColor Green
Write-Host "Scope: fields/notes/bookmarks/comments/hyperlinks/OMML/background/watermark + unified Smart Editor objects + WM1-WM6/DF regressions"

if (-not $SkipDependencyResolution) {
    Invoke-Step "Dependency resolution" {
        Invoke-Native { flutter pub get }
    }
}
else {
    Write-Host ""
    Write-Host "==> Dependency resolution (reusing top-level resolved packages)" -ForegroundColor DarkGray
}

Invoke-Step "Static analysis" {
    Invoke-Native { flutter analyze --no-pub }
}

Invoke-Step "WM7 advanced Word canonical/viewer contracts" {
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_wm7_advanced_content_test.dart }
}

Invoke-Step "WM8 unified Smart Editor DOCX round-trip contracts" {
    Invoke-Native { flutter test --no-pub test/features/smart_editor/smart_editor_docx_wm7_wm8_test.dart }
}

Invoke-Step "WM5 + WM6 regressions" {
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_wm5_wm6_layout_engine_test.dart }
    Invoke-Native { flutter test --no-pub test/features/smart_editor/smart_editor_docx_wm5_wm6_test.dart }
}

Invoke-Step "WM3 + WM4 regressions" {
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_wm3_wm4_paragraph_table_engine_test.dart }
    Invoke-Native { flutter test --no-pub test/features/smart_editor/smart_editor_docx_wm3_wm4_test.dart }
}

Invoke-Step "WM1 + WM2 regressions" {
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_wm1_wm2_ooxml_style_media_test.dart }
    Invoke-Native { flutter test --no-pub test/features/smart_editor/smart_editor_docx_wm1_wm2_test.dart }
}

Invoke-Step "DF Word fidelity regressions" {
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_layout_fidelity_df2_test.dart }
    Invoke-Native { flutter test --no-pub test/features/smart_editor/smart_editor_docx_df4_test.dart }
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_docx_df5_responsive_performance_test.dart }
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_docx_df6_production_certification_test.dart }
    Invoke-Native { flutter test --no-pub test/features/document_reader/word_fidelity_nested_table_runtime_regression_test.dart }
}

Write-Host ""
Write-Host "WORD MATURITY WM7 + WM8 GATE PASSED" -ForegroundColor Green
