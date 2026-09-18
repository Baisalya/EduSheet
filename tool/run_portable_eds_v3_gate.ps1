$ErrorActionPreference = "Stop"

function Run-Step {
    param(
        [string]$Label,
        [string[]]$Command
    )
    Write-Host ""
    Write-Host "==> $Label" -ForegroundColor Cyan
    & $Command[0] $Command[1..($Command.Length - 1)]
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

Run-Step "Static analysis" @("flutter", "analyze", "--no-pub")
Run-Step "Portable .eds v3 papers/assets/conflicts" @(
    "flutter", "test", "test/features/teaching_planner/portable_eds_v3_test.dart"
)
Run-Step "Legacy planner backup compatibility" @(
    "flutter", "test", "test/features/teaching_planner/planner_insights_backup_phase18_test.dart"
)
Run-Step "Portable planner attachment regression" @(
    "flutter", "test", "test/features/teaching_planner/syllabus_attachments_phase5_6_test.dart"
)
Run-Step "Phase 11 paper resources regression" @(
    "flutter", "test", "test/features/teaching_planner/syllabus_paper_resources_phase11_test.dart"
)
Run-Step "Phase 11 Resources & Papers gate" @(
    "powershell", "-ExecutionPolicy", "Bypass", "-File", ".\\tool\\run_syllabus_resources_papers_gate.ps1"
)

Write-Host ""
Write-Host "Phase 12 Portable .eds v3 gate passed." -ForegroundColor Green
