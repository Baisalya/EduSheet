$ErrorActionPreference = "Stop"

$path = ".\android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java"

if (-not (Test-Path $path)) {
    throw "GeneratedPluginRegistrant.java not found: $path"
}

$content = [System.IO.File]::ReadAllText($path)

if (-not $content.Contains("IntegrationTestPlugin")) {
    Write-Host "IntegrationTestPlugin registration is already absent." -ForegroundColor Yellow
}
else {
    $original = $content

    # Preferred: remove the complete try/catch registration block containing
    # the integration_test plugin. This preserves every production plugin.
    $blockPattern = '(?ms)\s*try\s*\{\s*flutterEngine\.getPlugins\(\)\.add\(\s*new\s+dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\s*\)\s*;\s*\}\s*catch\s*\(\s*Exception\s+\w+\s*\)\s*\{.*?\}\s*'

    $content = [regex]::Replace(
        $content,
        $blockPattern,
        "`r`n",
        1
    )

    # Fallback for variants where the registrant contains only the add line or
    # uses different generated catch formatting.
    if ($content.Contains("IntegrationTestPlugin")) {
        $linePattern = '(?m)^[^\r\n]*dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)[^\r\n]*\r?\n?'
        $content = [regex]::Replace(
            $content,
            $linePattern,
            "",
            1
        )
    }

    if ($content.Contains("IntegrationTestPlugin")) {
        throw "Could not safely remove IntegrationTestPlugin registration."
    }

    if ($content -eq $original) {
        throw "No registrant change was made."
    }

    [System.IO.File]::WriteAllText(
        $path,
        $content,
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host "Removed stale integration_test registration from Android release registrant." -ForegroundColor Green
}

$updated = [System.IO.File]::ReadAllText($path)

if ($updated.Contains("IntegrationTestPlugin")) {
    throw "Verification failed: IntegrationTestPlugin is still present."
}

Write-Host "Registrant verification PASS" -ForegroundColor Green
Write-Host ""
Write-Host "Now run a clean Android release build:" -ForegroundColor Cyan
Write-Host "  flutter clean"
Write-Host "  flutter pub get"
Write-Host "  flutter build appbundle --release --no-pub"
Write-Host ""
Write-Host "If the AAB builds successfully, rerun DF6:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tool\run_smart_editor_docx_df6_gate.ps1"
