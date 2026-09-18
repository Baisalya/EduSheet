$ErrorActionPreference = 'Stop'

function Invoke-GateStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    Write-Host ""
    Write-Host "==> $Name"
    & $Action
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Question editor Material surface hotfix gate FAILED at: $Name"
        exit $LASTEXITCODE
    }
}

Write-Host "EduSheet Question Editor Material Surface Hotfix release gate"
Write-Host "Scope: keep ListTile/Quill ink on a real Material surface in light and dark themes"

Invoke-GateStep -Name 'Static analysis' -Action {
    flutter analyze --no-pub
}

Invoke-GateStep -Name 'Question editor Material surface regression' -Action {
    flutter test test/features/paper_composer/question_editor_material_surface_test.dart
}

Invoke-GateStep -Name 'Question composer typing viewport regression' -Action {
    flutter test test/features/paper_composer/question_composer_typing_viewport_test.dart
}

Invoke-GateStep -Name 'Question composer manual-first regression' -Action {
    flutter test test/features/paper_composer/question_composer_manual_first_test.dart
}

Write-Host ""
Write-Host "Question editor Material surface hotfix gate PASSED"
