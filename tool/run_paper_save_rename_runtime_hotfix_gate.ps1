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
Run-Step 'Smart Work activity frame-safety regression' { flutter test test/features/guided_experience/smart_work_activity_host_test.dart }
Run-Step 'New paper first-save policy regression' { flutter test test/features/editor/editor_state_workflow_test.dart test/features/editor/syllabus_paper_context_test.dart }
Run-Step 'Saved Papers rename action regression' { flutter test test/features/editor/saved_papers_rename_action_test.dart }
Run-Step 'Professional theme regression' { powershell -ExecutionPolicy Bypass -File .\tool\run_professional_theme_gate.ps1 }
Run-Step 'Full Phase 12 + Phase 11 regression' { powershell -ExecutionPolicy Bypass -File .\tool\run_portable_eds_v3_gate.ps1 }

Write-Host "`nPaper save/rename/runtime hotfix gate passed." -ForegroundColor Green
