$ErrorActionPreference = "Stop"

$manifest = ".\android\app\src\main\AndroidManifest.xml"

if (-not (Test-Path $manifest)) {
    throw "AndroidManifest.xml not found. Run this script from the EduSheet project root."
}

$content = [System.IO.File]::ReadAllText($manifest)

$replacements = @(
    @('android:pathPattern=".*\\.eds"',  'android:pathPattern=".*\.eds"'),
    @('android:pathPattern=".*\\.EDS"',  'android:pathPattern=".*\.EDS"'),
    @('android:pathPattern=".*\\.edtp"', 'android:pathPattern=".*\.edtp"'),
    @('android:pathPattern=".*\\.EDTP"', 'android:pathPattern=".*\.EDTP"')
)

$changed = 0

foreach ($pair in $replacements) {
    $old = $pair[0]
    $new = $pair[1]

    if ($content.Contains($old)) {
        $content = $content.Replace($old, $new)
        $changed++
    }
}

if ($changed -gt 0) {
    [System.IO.File]::WriteAllText(
        $manifest,
        $content,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host ("Applied Android portable pathPattern hotfix. Replacements: " + $changed) -ForegroundColor Green
}
else {
    Write-Host "No double-escaped portable pathPattern entries were found." -ForegroundColor Yellow
}

$updated = [System.IO.File]::ReadAllText($manifest)

$required = @(
    'android:pathPattern=".*\.eds"',
    'android:pathPattern=".*\.EDS"',
    'android:pathPattern=".*\.edtp"',
    'android:pathPattern=".*\.EDTP"'
)

foreach ($value in $required) {
    if (-not $updated.Contains($value)) {
        throw ("Required manifest entry is missing after hotfix: " + $value)
    }
}

$forbidden = @(
    'android:pathPattern=".*\\.eds"',
    'android:pathPattern=".*\\.EDS"',
    'android:pathPattern=".*\\.edtp"',
    'android:pathPattern=".*\\.EDTP"'
)

foreach ($value in $forbidden) {
    if ($updated.Contains($value)) {
        throw ("Double-escaped manifest entry still exists: " + $value)
    }
}

Write-Host "Manifest verification PASS" -ForegroundColor Green
Write-Host ""
Write-Host "Run targeted regression:" -ForegroundColor Cyan
Write-Host "  flutter test test/features/document_reader/native_file_activation_phase5_test.dart"
Write-Host ""
Write-Host "Then rerun DF6:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tool\run_smart_editor_docx_df6_gate.ps1"
