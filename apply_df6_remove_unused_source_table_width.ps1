$ErrorActionPreference = "Stop"

$path = ".\lib\features\document_reader\presentation\widgets\viewers\word_fidelity_document_view.dart"

if (-not (Test-Path $path)) {
    throw "Renderer file not found: $path"
}

$content = [System.IO.File]::ReadAllText($path)

$startMarker = "double _sourceTableWidth(ConversionTable table) {"
$nextMarker = "TextStyle _runStyle("

$start = $content.IndexOf($startMarker)

if ($start -lt 0) {
    Write-Host "_sourceTableWidth is already absent. Nothing to change." -ForegroundColor Yellow
    exit 0
}

$next = $content.IndexOf($nextMarker, $start)

if ($next -le $start) {
    throw "Could not safely locate the end of _sourceTableWidth. No file was changed."
}

$before = $content.Substring(0, $start).TrimEnd()
$after = $content.Substring($next).TrimStart()

$updated = $before + [Environment]::NewLine + [Environment]::NewLine + $after

if ($updated.Contains($startMarker)) {
    throw "Verification failed: _sourceTableWidth still exists."
}

[System.IO.File]::WriteAllText(
    $path,
    $updated,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Removed obsolete _sourceTableWidth helper." -ForegroundColor Green
Write-Host ""
Write-Host "Re-run:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tool\run_df6_word_real_document_runtime_hotfix_gate.ps1"
