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
        Write-Host "Smart Editor Phase W3 gate FAILED at: $Name"
        exit $LASTEXITCODE
    }
}

Write-Host "EduSheet Smart Editor Phase W3 production gate"
Write-Host "Scope: W1/W2 regressions, editable Math embeds, editable Geometry embeds, portable object payloads"

Invoke-GateStep -Name 'Static analysis' -Action {
    flutter analyze --no-pub
}

Invoke-GateStep -Name 'Smart Editor W1 regression' -Action {
    flutter test test/features/smart_editor/smart_editor_w1_test.dart
}

Invoke-GateStep -Name 'Smart Editor W2 regression' -Action {
    flutter test test/features/smart_editor/smart_editor_w2_test.dart
}

Invoke-GateStep -Name 'Smart Editor W3 Math + Geometry certification' -Action {
    flutter test test/features/smart_editor/smart_editor_w3_test.dart
}

Invoke-GateStep -Name 'Math editor regression' -Action {
    flutter test test/features/math_keyboard/formula_editor_sheet_test.dart
    flutter test test/features/math_keyboard/math_keyboard_controller_build_test.dart
}

Invoke-GateStep -Name 'Geometry editor/embed regression' -Action {
    flutter test test/features/geometry_builder/geometry_embed_layout_phase4c_test.dart
    flutter test test/features/geometry_builder/geometry_editor_session_test.dart
}

Invoke-GateStep -Name 'Help/manual regression' -Action {
    flutter test test/features/guided_experience/user_manual_guide_coverage_test.dart
}

Write-Host ""
Write-Host "Smart Editor Phase W3 gate PASSED"
