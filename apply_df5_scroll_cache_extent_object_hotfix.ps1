$ErrorActionPreference = "Stop"

$path = ".\lib\features\document_reader\presentation\widgets\viewers\word_fidelity_document_view.dart"

if (-not (Test-Path $path)) {
    throw "File not found: $path"
}

$content = [System.IO.File]::ReadAllText($path)

$wrongNew = 'scrollCacheExtent: math.max(800, constraints.maxHeight * 1.5),'
$oldDeprecated = 'cacheExtent: math.max(800, constraints.maxHeight * 1.5),'
$fixed = 'scrollCacheExtent: ScrollCacheExtent.pixels(' + "`r`n" +
         '  math.max(800.0, constraints.maxHeight * 1.5).toDouble(),' + "`r`n" +
         '),'

if ($content.Contains($fixed)) {
    Write-Host "DF5 ScrollCacheExtent object hotfix already applied." -ForegroundColor Yellow
}
elseif ($content.Contains($wrongNew)) {
    $content = $content.Replace($wrongNew, $fixed)
    [System.IO.File]::WriteAllText(
        $path,
        $content,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "Replaced raw scrollCacheExtent number with ScrollCacheExtent.pixels(...)." -ForegroundColor Green
}
elseif ($content.Contains($oldDeprecated)) {
    $content = $content.Replace($oldDeprecated, $fixed)
    [System.IO.File]::WriteAllText(
        $path,
        $content,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "Migrated deprecated cacheExtent to ScrollCacheExtent.pixels(...)." -ForegroundColor Green
}
else {
    throw "Expected DF5 cache extent line was not found. No file was changed."
}

Write-Host ""
Write-Host "Now run:" -ForegroundColor Cyan
Write-Host "  flutter analyze --no-pub"
Write-Host ""
Write-Host "Only if analyze is clean, run:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tool\run_smart_editor_docx_df5_gate.ps1"
