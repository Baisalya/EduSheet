$ErrorActionPreference = 'Stop'

function Invoke-GateStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Command
    )

    Write-Host "`n=== $Name ===" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Release gate failed: $Name (exit code $LASTEXITCODE)"
    }
}

Invoke-GateStep 'Format Teaching Planner' {
    dart format lib/features/teaching_planner test/features/teaching_planner
}

Invoke-GateStep 'Flutter analyze' {
    flutter analyze --no-fatal-infos
}

Invoke-GateStep 'Syllabus navigation policy' {
    flutter test test/features/teaching_planner/syllabus_navigation_policy_test.dart
}

Invoke-GateStep 'Adaptive syllabus editor' {
    flutter test test/features/teaching_planner/syllabus_manager_screen_test.dart
}

Invoke-GateStep 'Syllabus attachments and portable EDS' {
    flutter test test/features/teaching_planner/syllabus_attachments_phase5_6_test.dart
}

Invoke-GateStep 'Teaching Planner regression suite' {
    flutter test test/features/teaching_planner
}

Write-Host "`nTEACHING PLANNER SYLLABUS RELEASE GATE: PASS" -ForegroundColor Green
