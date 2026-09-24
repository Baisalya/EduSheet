$ErrorActionPreference = "Stop"

$path = ".\tool\run_smart_editor_docx_df6_gate.ps1"

if (-not (Test-Path $path)) {
    throw "DF6 gate not found: $path"
}

$content = [System.IO.File]::ReadAllText($path)

# Idempotent: do nothing if the safe native stderr handling is already present.
if ($content.Contains('$nativeExitCode = $global:LASTEXITCODE') -and
    $content.Contains('$ErrorActionPreference = "Continue"')) {
    Write-Host "DF6 native stderr warning hotfix is already applied." -ForegroundColor Yellow
}
else {
    $original = $content

    # 1) Preserve the caller's ErrorActionPreference after LASTEXITCODE reset.
    $pattern1 = '(?m)^(\s*)\$global:LASTEXITCODE\s*=\s*0\s*$'
    $content = [regex]::Replace(
        $content,
        $pattern1,
        {
            param($m)
            $indent = $m.Groups[1].Value
            return $m.Value + "`r`n" +
                $indent + '$previousErrorActionPreference = $ErrorActionPreference'
        },
        1
    )

    if ($content -eq $original) {
        throw "Could not find LASTEXITCODE reset inside Invoke-Step."
    }

    # 2) Wrap native execution so stderr warnings stay logged but do not become
    # terminating PowerShell errors under Windows PowerShell 5.1.
    $beforeAction = $content
    $pattern2 = '(?m)^(\s*)&\s*\$Action\s+2>&1\s*\|\s*Tee-Object\s+-FilePath\s+\$LogPath\s+-Append\s*$'
    $content = [regex]::Replace(
        $content,
        $pattern2,
        {
            param($m)
            $indent = $m.Groups[1].Value
            return (
                $indent + '$ErrorActionPreference = "Continue"' + "`r`n" +
                $m.Value + "`r`n" +
                $indent + '$nativeExitCode = $global:LASTEXITCODE' + "`r`n" +
                $indent + '$ErrorActionPreference = $previousErrorActionPreference'
            )
        },
        1
    )

    if ($content -eq $beforeAction) {
        throw "Could not find the DF6 native action/Tee-Object line."
    }

    # 3) Change only the first post-action native exit-code check.
    $beforeCheck = $content
    $content = [regex]::Replace(
        $content,
        'if\s*\(\s*\$global:LASTEXITCODE\s*-ne\s*0\s*\)',
        'if ($nativeExitCode -ne 0)',
        1
    )
    $content = [regex]::Replace(
        $content,
        'throw\s*\(\s*"Native command exit code "\s*\+\s*\$global:LASTEXITCODE\s*\)',
        'throw ("Native command exit code " + $nativeExitCode)',
        1
    )

    if ($content -eq $beforeCheck) {
        throw "Could not replace the DF6 native exit-code check."
    }

    # 4) Restore ErrorActionPreference on exception before the failure report.
    # Anchor to the catch whose next statement calculates elapsed time.
    $beforeCatch = $content
    $pattern4 = '(?ms)(catch\s*\{\s*)(\$elapsed\s*=\s*\(Get-Date\)\s*-\s*\$started)'
    $content = [regex]::Replace(
        $content,
        $pattern4,
        {
            param($m)
            return $m.Groups[1].Value +
                '$ErrorActionPreference = $previousErrorActionPreference' + "`r`n" +
                '        ' + $m.Groups[2].Value
        },
        1
    )

    if ($content -eq $beforeCatch) {
        throw "Could not patch the DF6 Invoke-Step catch block."
    }

    # 5) Final structural verification before writing anything.
    $required = @(
        '$previousErrorActionPreference = $ErrorActionPreference',
        '$ErrorActionPreference = "Continue"',
        '$nativeExitCode = $global:LASTEXITCODE',
        'if ($nativeExitCode -ne 0)',
        'throw ("Native command exit code " + $nativeExitCode)'
    )

    foreach ($token in $required) {
        if (-not $content.Contains($token)) {
            throw ("Patched DF6 gate is missing required token: " + $token)
        }
    }

    # Keep Windows PowerShell 5.1-safe UTF-8 BOM.
    [System.IO.File]::WriteAllText(
        $path,
        $content,
        [System.Text.UTF8Encoding]::new($true)
    )

    Write-Host "Applied DF6 native stderr warning hotfix v2." -ForegroundColor Green
}

Write-Host ""
Write-Host "Probe Android release build first:" -ForegroundColor Cyan
Write-Host "  flutter build appbundle --release --no-pub"
Write-Host ""
Write-Host "If it ends with Built ... app-release.aab, rerun full DF6:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tool\run_smart_editor_docx_df6_gate.ps1"
