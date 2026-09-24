$ErrorActionPreference = "Stop"

$path = ".\tool\run_smart_editor_docx_df6_gate.ps1"

if (-not (Test-Path $path)) {
    throw "DF6 gate not found: $path"
}

$content = [System.IO.File]::ReadAllText($path)

$old = 'flutter build appbundle --release --no-pub'
$new = 'flutter build appbundle --release'

if ($content.Contains($new) -and -not $content.Contains($old)) {
    Write-Host "DF6 Android release build hotfix is already applied." -ForegroundColor Yellow
}
elseif ($content.Contains($old)) {
    $content = $content.Replace($old, $new)

    # Add an explanatory comment once, immediately above the command.
    $content = $content.Replace(
        '        flutter build appbundle --release',
        '        # Do not use --no-pub here. Flutter can otherwise generate a release' + "`r`n" +
        '        # registrant that still references the dev-only integration_test plugin.' + "`r`n" +
        '        flutter build appbundle --release'
    )

    [System.IO.File]::WriteAllText(
        $path,
        $content,
        [System.Text.UTF8Encoding]::new($true)
    )

    Write-Host "Applied DF6 Android release build no-pub hotfix." -ForegroundColor Green
}
else {
    throw "Expected DF6 Android appbundle build command was not found."
}

$updated = [System.IO.File]::ReadAllText($path)

if ($updated.Contains('flutter build appbundle --release --no-pub')) {
    throw "Verification failed: Android DF6 build still uses --no-pub."
}
if (-not $updated.Contains('flutter build appbundle --release')) {
    throw "Verification failed: corrected Android appbundle command is missing."
}

Write-Host "DF6 Android build command verification PASS" -ForegroundColor Green
Write-Host ""
Write-Host "Now probe Android release WITHOUT --no-pub:" -ForegroundColor Cyan
Write-Host "  flutter build appbundle --release"
Write-Host ""
Write-Host "If it builds app-release.aab, rerun full DF6:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tool\run_smart_editor_docx_df6_gate.ps1"
