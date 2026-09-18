$ErrorActionPreference = 'Stop'

function Run-Step {
    param(
        [string]$Label,
        [scriptblock]$Command
    )
    Write-Host "`n==> $Label" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

Run-Step 'Static analysis' { flutter analyze --no-pub }
Run-Step 'Professional light/dark theme contract' { flutter test test/shared/design/app_theme_test.dart }
Run-Step 'Home screen visual smoke' { flutter test test/widget_test.dart }
Run-Step 'Teaching Planner light/dark theme regression' { flutter test test/features/teaching_planner/teaching_planner_design_system_test.dart }
Run-Step 'Phase 12 portable .eds v3 regression' { flutter test test/features/teaching_planner/portable_eds_v3_test.dart }

Write-Host "`nProfessional Theme + Home Planner gate passed." -ForegroundColor Green
