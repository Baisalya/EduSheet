$ErrorActionPreference = "Stop"

$progId = "EduSheet.Document"
$appKey = "HKCU:\Software\Classes\Applications\edusheet.exe"
$extensions = @(
    ".pdf", ".doc", ".docx", ".rtf", ".odt",
    ".xls", ".xlsx", ".csv", ".ods",
    ".ppt", ".pptx", ".odp", ".txt"
)

foreach ($extension in $extensions) {
    $openWithKey = "HKCU:\Software\Classes\$extension\OpenWithProgids"
    if (Test-Path $openWithKey) {
        Remove-ItemProperty -Path $openWithKey -Name $progId -ErrorAction SilentlyContinue
    }
}

Remove-Item -Path "HKCU:\Software\Classes\$progId" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $appKey -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "EduSheet Open with registrations were removed for the current user."
