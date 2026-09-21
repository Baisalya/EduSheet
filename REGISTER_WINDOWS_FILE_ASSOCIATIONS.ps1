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
$appKey = "HKCU:\Software\Classes\Applications\edusheet.exe"
$documentProgId = "EduSheet.Document"
$packageProgId = "EduSheet.Package"
$teachingPackProgId = "EduSheet.TeachingPack"

function Set-OpenCommand([string]$ProgId, [string]$Description) {
    $progKey = "HKCU:\Software\Classes\$ProgId"
    New-Item -Path $progKey -Force | Out-Null
    Set-Item -Path $progKey -Value $Description
    New-Item -Path "$progKey\DefaultIcon" -Force | Out-Null
    Set-Item -Path "$progKey\DefaultIcon" -Value ('"{0}",0' -f $ExePath)
    New-Item -Path "$progKey\shell\open\command" -Force | Out-Null
    Set-Item -Path "$progKey\shell\open\command" -Value ('"{0}" "%1"' -f $ExePath)
}

Set-OpenCommand $documentProgId "EduSheet Document"
Set-OpenCommand $packageProgId "EduSheet Package"
Set-OpenCommand $teachingPackProgId "EduSheet Teaching Pack"

New-Item -Path $appKey -Force | Out-Null
New-ItemProperty -Path $appKey -Name "FriendlyAppName" -Value "EduSheet" -PropertyType String -Force | Out-Null
New-Item -Path "$appKey\DefaultIcon" -Force | Out-Null
Set-Item -Path "$appKey\DefaultIcon" -Value ('"{0}",0' -f $ExePath)
New-Item -Path "$appKey\shell\open\command" -Force | Out-Null
Set-Item -Path "$appKey\shell\open\command" -Value ('"{0}" "%1"' -f $ExePath)
New-Item -Path "$appKey\SupportedTypes" -Force | Out-Null

# Common document formats are offered through "Open with EduSheet" only.
# Existing Windows default-app choices are not changed.
$documentExtensions = @(
    ".pdf", ".doc", ".docx", ".rtf", ".odt",
    ".xls", ".xlsx", ".csv", ".ods",
    ".ppt", ".pptx", ".odp", ".txt"
)

foreach ($extension in $documentExtensions) {
    $openWithKey = "HKCU:\Software\Classes\$extension\OpenWithProgids"
    New-Item -Path $openWithKey -Force | Out-Null
    New-ItemProperty -Path $openWithKey -Name $documentProgId -Value "" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path "$appKey\SupportedTypes" -Name $extension -Value "" -PropertyType String -Force | Out-Null
}

# .eds and .edtp are EduSheet-owned portable formats. Register their type
# metadata and open command, while still allowing Windows/user policy to decide
# the effective default application.
$ownedTypes = @(
    @{ Extension = ".eds"; ProgId = $packageProgId; ContentType = "application/vnd.baishalya.edusheet"; PerceivedType = "document" },
    @{ Extension = ".edtp"; ProgId = $teachingPackProgId; ContentType = "application/vnd.baishalya.edusheet-teaching-pack"; PerceivedType = "document" }
)

foreach ($type in $ownedTypes) {
    $extensionKey = "HKCU:\Software\Classes\$($type.Extension)"
    New-Item -Path $extensionKey -Force | Out-Null
    # These extensions are EduSheet-owned. Setting the class default enables
    # double-click on fresh installs; a Windows UserChoice made by the user
    # still takes precedence.
    Set-Item -Path $extensionKey -Value $type.ProgId
    New-ItemProperty -Path $extensionKey -Name "Content Type" -Value $type.ContentType -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $extensionKey -Name "PerceivedType" -Value $type.PerceivedType -PropertyType String -Force | Out-Null

    $openWithKey = "$extensionKey\OpenWithProgids"
    New-Item -Path $openWithKey -Force | Out-Null
    New-ItemProperty -Path $openWithKey -Name $type.ProgId -Value "" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path "$appKey\SupportedTypes" -Name $type.Extension -Value "" -PropertyType String -Force | Out-Null
}

# Refresh Explorer's association cache without changing user-selected defaults.
Add-Type -Namespace Win32 -Name ShellNotify -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("shell32.dll")]
public static extern void SHChangeNotify(int wEventId, uint uFlags, System.IntPtr dwItem1, System.IntPtr dwItem2);
'@
[Win32.ShellNotify]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)

Write-Host "EduSheet native file registration updated."
Write-Host "Portable types: .eds, .edtp"
Write-Host "Only EduSheet-owned .eds/.edtp classes are registered for double-click; common document defaults are unchanged."
Write-Host "Executable: $ExePath"
