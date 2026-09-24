$ErrorActionPreference = "Stop"

$path = ".\tool\run_smart_editor_docx_df6_gate.ps1"

if (-not (Test-Path $path)) {
    throw "DF6 gate not found: $path"
}

$content = [System.IO.File]::ReadAllText($path)

$old = @'
    # PowerShell-only steps do not update LASTEXITCODE. Reset it so a stale or
    # null value cannot fail a successful preflight/integrity step.
    $global:LASTEXITCODE = 0

    try {
        & $Action 2>&1 | Tee-Object -FilePath $LogPath -Append
        if ($global:LASTEXITCODE -ne 0) {
            throw ("Native command exit code " + $global:LASTEXITCODE)
        }
    }
    catch {
'@

$new = @'
    # PowerShell-only steps do not update LASTEXITCODE. Reset it so a stale or
    # null value cannot fail a successful preflight/integrity step.
    $global:LASTEXITCODE = 0
    $previousErrorActionPreference = $ErrorActionPreference

    try {
        # Windows PowerShell 5.1 turns native stderr into ErrorRecord objects.
        # Flutter/Gradle legitimately writes warnings to stderr even when the
        # native process succeeds. Keep those warnings in the log and decide
        # success only from the native exit code.
        $ErrorActionPreference = "Continue"
        & $Action 2>&1 | Tee-Object -FilePath $LogPath -Append
        $nativeExitCode = $global:LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference

        if ($nativeExitCode -ne 0) {
            throw ("Native command exit code " + $nativeExitCode)
        }
    }
    catch {
        $ErrorActionPreference = $previousErrorActionPreference
'@

if ($content.Contains($new)) {
    Write-Host "DF6 native stderr warning hotfix already applied." -ForegroundColor Yellow
}
elseif ($content.Contains($old)) {
    $content = $content.Replace($old, $new)
    [System.IO.File]::WriteAllText(
        $path,
        $content,
        [System.Text.UTF8Encoding]::new($true)
    )
    Write-Host "Applied DF6 native stderr warning hotfix." -ForegroundColor Green
}
else {
    throw "Expected DF6 Invoke-Step block was not found. No file was changed."
}

$updated = [System.IO.File]::ReadAllText($path)

if (-not $updated.Contains('$ErrorActionPreference = "Continue"')) {
    throw "Hotfix verification failed: Continue mode was not inserted."
}

if (-not $updated.Contains('$nativeExitCode = $global:LASTEXITCODE')) {
    throw "Hotfix verification failed: native exit-code capture is missing."
}

Write-Host "DF6 gate verification PASS" -ForegroundColor Green
Write-Host ""
Write-Host "First probe the Android release build:" -ForegroundColor Cyan
Write-Host "  flutter build appbundle --release --no-pub"
Write-Host ""
Write-Host "If that finishes with Built ... app-release.aab, rerun full DF6:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tool\run_smart_editor_docx_df6_gate.ps1"
