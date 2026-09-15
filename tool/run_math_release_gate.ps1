$ErrorActionPreference = 'Stop'

function Invoke-Gate {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Command
    )

    Write-Host "`n=== $Name ===" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Math release gate failed: $Name (exit $LASTEXITCODE)"
    }
}

Invoke-Gate 'Formatting contract' {
    dart format `
        lib/features/math_keyboard `
        test/features/math_keyboard `
        test/features/paper_composer `
        test/features/pdf `
        test/release
}

Invoke-Gate 'Analyzer' {
    flutter analyze --no-pub
}

Invoke-Gate 'Phase 12 universal certification audit' {
    flutter test test/features/math_keyboard/math_release_certification_test.dart
}

Invoke-Gate 'Phase 12 golden booklet export + exact DOCX restore' {
    flutter test test/features/pdf/math_release_export_certification_test.dart
}

Invoke-Gate 'Universal booklet baseline' {
    flutter test test/features/math_keyboard/math_universal_booklet_baseline_test.dart
}

Invoke-Gate 'Parser / renderer / PDF / Word compatibility' {
    flutter test test/features/math_keyboard/math_parser_renderer_compatibility_test.dart
}

Invoke-Gate 'Strong validation + safe failure' {
    flutter test test/features/math_keyboard/math_safety_validation_service_test.dart
    flutter test test/features/paper_composer/question_math_validation_service_test.dart
}

Invoke-Gate 'Production hardening + stress' {
    flutter test test/features/math_keyboard/math_production_hardening_test.dart
    flutter test test/features/paper_composer/question_math_stress_test.dart
    flutter test test/features/pdf/math_export_stress_test.dart
}

Invoke-Gate 'Accessibility + keyboard productivity' {
    flutter test test/features/math_keyboard/math_keyboard_accessibility_productivity_test.dart
    flutter test test/features/math_keyboard/math_keyboard_productivity_shortcuts_test.dart
    flutter test test/features/math_keyboard/math_keyboard_reverse_slot_navigation_test.dart
}

Invoke-Gate 'Math import identity' {
    flutter test test/features/math_keyboard/math_internal_import_identity_test.dart
}

Invoke-Gate 'Smart Paper Word round-trip release gate' {
    flutter test test/release/smart_paper_word_round_trip_gate_test.dart
}

Invoke-Gate 'Adaptive modal architecture' {
    flutter test test/shared/presentation/adaptive_modal_usage_test.dart
}

Invoke-Gate 'Complete math keyboard suite' {
    flutter test test/features/math_keyboard
}

Invoke-Gate 'Complete paper composer suite' {
    flutter test test/features/paper_composer
}

Invoke-Gate 'Complete PDF / Word suite' {
    flutter test test/features/pdf
}

Invoke-Gate 'Full project regression suite' {
    flutter test
}

Write-Host "`nMATH RELEASE CERTIFICATION: PASS" -ForegroundColor Green
