$ErrorActionPreference = 'Stop'

function Fail-GateStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [int]$ExitCode = 1
    )

    Write-Host "`nWord Converter Phase 4 gate FAILED at: $Name" -ForegroundColor Red
    exit $ExitCode
}

function Invoke-GateStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command
    )

    Write-Host "`n==> $Name"
    try {
        & $Command
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        Fail-GateStep -Name $Name -ExitCode 1
    }

    $exitCode = $LASTEXITCODE
    if ($null -ne $exitCode -and $exitCode -ne 0) {
        Fail-GateStep -Name $Name -ExitCode $exitCode
    }
}

Write-Host 'EduSheet Word Converter Phase 4 release gate'
Write-Host 'Scope: production conversion UX, progress, cancellation, save safety, history and temp cleanup'

Invoke-GateStep -Name 'Dependency resolution' -Command {
    flutter pub get
}

Invoke-GateStep -Name 'Android permission dependency contract' -Command {
    $lock = Get-Content -LiteralPath '.\pubspec.lock' -Raw

    $handlerMatch = [regex]::Match(
        $lock,
        '(?ms)^  permission_handler:\r?\n.*?^    version: "([^"]+)"'
    )
    $androidMatch = [regex]::Match(
        $lock,
        '(?ms)^  permission_handler_android:\r?\n.*?^    version: "([^"]+)"'
    )

    if (-not $handlerMatch.Success -or -not $androidMatch.Success) {
        throw 'Could not verify permission_handler versions in pubspec.lock.'
    }

    $handlerVersion = $handlerMatch.Groups[1].Value
    $androidVersion = $androidMatch.Groups[1].Value

    Write-Host "permission_handler=$handlerVersion; permission_handler_android=$androidVersion"

    if ($handlerVersion -ne '12.0.3') {
        throw "Expected permission_handler 12.0.3 for the API-36 baseline, resolved $handlerVersion."
    }

    $androidMajorText = ($androidVersion -split '\.')[0]
    $androidMajor = 0
    if (-not [int]::TryParse($androidMajorText, [ref]$androidMajor)) {
        throw "Could not parse permission_handler_android version '$androidVersion'."
    }
    if ($androidMajor -ge 14) {
        throw "permission_handler_android $androidVersion requires Android API 37 symbols; API-36 release baseline must resolve below 14.x."
    }
}

Invoke-GateStep -Name 'Static analysis' -Command {
    flutter analyze --no-pub
}

Invoke-GateStep -Name 'Phase 1+2 DOCX parser regression' -Command {
    flutter test test/features/word_converter/docx_conversion_parser_test.dart
}

Invoke-GateStep -Name 'Phase 3 editable PDF geometry regression' -Command {
    flutter test test/features/word_converter/pdf_editable_reconstructor_test.dart
}

Invoke-GateStep -Name 'Editable DOCX writer regression' -Command {
    flutter test test/features/word_converter/editable_docx_writer_test.dart
}

Invoke-GateStep -Name 'Conversion job cancellation/progress contract' -Command {
    flutter test test/features/word_converter/conversion_job_test.dart
}

Invoke-GateStep -Name 'Recent conversion history persistence' -Command {
    flutter test test/features/word_converter/conversion_history_service_test.dart
}

Invoke-GateStep -Name 'Converter service production workflow regression' -Command {
    flutter test test/features/word_converter/word_converter_service_test.dart
}

Invoke-GateStep -Name 'Converter production UI regression' -Command {
    flutter test test/features/word_converter/word_converter_screen_test.dart
}

Invoke-GateStep -Name 'Android PDF renderer Java compile' -Command {
    Push-Location android
    try {
        .\gradlew.bat :app:compileDebugJavaWithJavac
    }
    finally {
        Pop-Location
    }
}

Write-Host "`nWord Converter Phase 4 gate PASSED" -ForegroundColor Green
exit 0
