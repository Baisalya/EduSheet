$ErrorActionPreference = "Stop"

$path = ".\test\features\document_reader\word_fidelity_nested_table_runtime_regression_test.dart"

if (-not (Test-Path $path)) {
    throw "Regression test not found: $path"
}

$content = [System.IO.File]::ReadAllText($path)

$replacements = @(
    @(
        "expect(find.text('Nested left'), findsOneWidget);",
        "expect(find.text('Nested left', findRichText: true), findsOneWidget);"
    ),
    @(
        "expect(find.text('Nested right'), findsOneWidget);",
        "expect(find.text('Nested right', findRichText: true), findsOneWidget);"
    )
)

$changed = 0
foreach ($pair in $replacements) {
    $old = $pair[0]
    $new = $pair[1]

    if ($content.Contains($new)) {
        continue
    }

    if (-not $content.Contains($old)) {
        throw ("Expected assertion not found: " + $old)
    }

    $content = $content.Replace($old, $new)
    $changed++
}

if ($changed -gt 0) {
    [System.IO.File]::WriteAllText(
        $path,
        $content,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host ("Applied RichText finder hotfix. Replacements: " + $changed) -ForegroundColor Green
}
else {
    Write-Host "RichText finder hotfix already applied." -ForegroundColor Yellow
}

$updated = [System.IO.File]::ReadAllText($path)

if (-not $updated.Contains("find.text('Nested left', findRichText: true)")) {
    throw "Verification failed for Nested left assertion."
}
if (-not $updated.Contains("find.text('Nested right', findRichText: true)")) {
    throw "Verification failed for Nested right assertion."
}

Write-Host "Regression-test verification PASS" -ForegroundColor Green
Write-Host ""
Write-Host "Run targeted test first:" -ForegroundColor Cyan
Write-Host "  flutter test test/features/document_reader/word_fidelity_nested_table_runtime_regression_test.dart"
Write-Host ""
Write-Host "Then rerun full runtime gate:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tool\run_df6_word_real_document_runtime_hotfix_gate.ps1"
