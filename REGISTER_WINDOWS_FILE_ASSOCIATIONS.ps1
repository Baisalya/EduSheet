param(
    [string]$ExePath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ExePath)) {
    $release = Join-Path $PSScriptRoot "build\windows\x64\runner\Release\edusheet.exe"
    $debug = Join-Path $PSScriptRoot "build\windows\x64\runner\Debug\edusheet.exe"
    if (Test-Path $release) {
        $ExePath = $release
    } elseif (Test-Path $debug) {
        $ExePath = $debug
    } else {
        throw "EduSheet Windows executable not found. Build the app first or pass -ExePath."
    }
}

$ExePath = (Resolve-Path $ExePath).Path
$progId = "EduSheet.Document"
$appKey = "HKCU:\Software\Classes\Applications\edusheet.exe"
$progKey = "HKCU:\Software\Classes\$progId"
$extensions = @(
    ".pdf", ".doc", ".docx", ".rtf", ".odt",
    ".xls", ".xlsx", ".csv", ".ods",
    ".ppt", ".pptx", ".odp", ".txt"
)

New-Item -Path $progKey -Force | Out-Null
Set-Item -Path $progKey -Value "EduSheet Document"
New-Item -Path "$progKey\DefaultIcon" -Force | Out-Null
Set-Item -Path "$progKey\DefaultIcon" -Value ('"{0}",0' -f $ExePath)
New-Item -Path "$progKey\shell\open\command" -Force | Out-Null
Set-Item -Path "$progKey\shell\open\command" -Value ('"{0}" "%1"' -f $ExePath)

New-Item -Path "$appKey\shell\open\command" -Force | Out-Null
Set-Item -Path "$appKey\shell\open\command" -Value ('"{0}" "%1"' -f $ExePath)
New-Item -Path "$appKey\SupportedTypes" -Force | Out-Null

foreach ($extension in $extensions) {
    $openWithKey = "HKCU:\Software\Classes\$extension\OpenWithProgids"
    New-Item -Path $openWithKey -Force | Out-Null
    New-ItemProperty -Path $openWithKey -Name $progId -Value "" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path "$appKey\SupportedTypes" -Name $extension -Value "" -PropertyType String -Force | Out-Null
}

Write-Host "EduSheet was added to Windows Open with for supported document types."
Write-Host "No default application was changed."
Write-Host "Executable: $ExePath"
