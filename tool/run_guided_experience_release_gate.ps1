param(
    [switch]$FullSuite,
    [switch]$BuildAndroid,
    [switch]$BuildWindows
)

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

function Invoke-FlutterTestFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Invoke-GateCommand `
        -Label "Test: $Path" `
        -Executable 'flutter' `
        -Arguments @('test', $Path)
}

Push-Location $projectRoot
try {
    Invoke-GateCommand `
        -Label 'Static analysis' `
        -Executable 'flutter' `
        -Arguments @('analyze', '--no-pub')

    Invoke-GateCommand `
        -Label 'Windows Esc/navigation regression suite' `
        -Executable 'flutter' `
        -Arguments @('test', 'test/core/navigation')

    Invoke-GateCommand `
        -Label 'Guided Experience regression suite' `
        -Executable 'flutter' `
        -Arguments @('test', 'test/features/guided_experience')

    $focusedTests = @(
        'test/features/paper_composer/question_composer_manual_first_test.dart',
        'test/features/paper_composer/question_composer_typing_viewport_test.dart',
        'test/features/paper_composer/paper_preview_advanced_content_test.dart',
        'test/features/question_bank/question_bank_paper_composer_widget_test.dart',
        'test/features/question_bank/presentation/question_bank_picker_responsive_test.dart',
        'test/features/teaching_planner/teaching_planner_release_gate_test.dart',
        'test/features/teaching_planner/syllabus_manager_screen_test.dart',
        'test/features/teaching_planner/teaching_planner_screen_test.dart',
        'test/features/teaching_planner/teaching_planner_setup_model_test.dart',
        'test/features/teaching_planner/teaching_planner_navigation_contract_test.dart',
        'test/features/teaching_planner/lesson_detail_model_test.dart'
    )

    foreach ($testFile in $focusedTests) {
        Invoke-FlutterTestFile -Path $testFile
    }

    if ($FullSuite) {
        Invoke-GateCommand `
            -Label 'Full EduSheet regression suite' `
            -Executable 'flutter' `
            -Arguments @('test')
    }

    if ($BuildAndroid) {
        Invoke-GateCommand `
            -Label 'Android debug build' `
            -Executable 'flutter' `
            -Arguments @('build', 'apk', '--debug')
    }

    if ($BuildWindows) {
        Invoke-GateCommand `
            -Label 'Windows debug build' `
            -Executable 'flutter' `
            -Arguments @('build', 'windows', '--debug')
    }

    Write-Host "`nGuided Experience release gate PASSED." -ForegroundColor Green
}
finally {
    Pop-Location
}
