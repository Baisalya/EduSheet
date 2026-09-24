$ErrorActionPreference = "Stop"

$path = ".\lib\features\document_reader\presentation\widgets\viewers\word_fidelity_document_view.dart"

if (-not (Test-Path $path)) {
    throw "File not found: $path"
}

$content = [System.IO.File]::ReadAllText($path)
$old = 'cacheExtent: math.max(800, constraints.maxHeight * 1.5),'
$new = 'scrollCacheExtent: math.max(800, constraints.maxHeight * 1.5),'

if ($content.Contains($new)) {
    Write-Host "DF5 hotfix already applied." -ForegroundColor Yellow
} elseif ($content.Contains($old)) {
    $content = $content.Replace($old, $new)
    [System.IO.File]::WriteAllText(
        $path,
        $content,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "Applied DF5 scrollCacheExtent hotfix." -ForegroundColor Green
} else {
    throw "Expected cacheExtent line was not found. No file was changed."
}

Write-Host ""
Write-Host "Run:" -ForegroundColor Cyan
Write-Host "  flutter analyze --no-pub"
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tool\run_smart_editor_docx_df5_gate.ps1"
