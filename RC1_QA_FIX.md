# EduSheet RC Candidate 1 — QA Fix 1

## Why RC1 did not actually pass

The Windows run exposed two independent release-gate defects:

1. The font gate treated `C:\Windows\Fonts\Nirmala.ttf` as mandatory. That is too strict: Windows installations can lack that exact optional font file even when stable local base fonts such as Segoe UI or Arial are available.
2. Windows PowerShell 5.1 does not make a non-zero native process exit code a terminating error merely because `$ErrorActionPreference = 'Stop'`. The RC script therefore continued after failed `flutter test` commands and printed a false green `gate passed` message.

The same run also showed that the PDF theme fell through to Google-font downloads because the local Windows plan had Nirmala UI as its only base font. When that file was absent, the complete local plan was abandoned.

## Fixes

### Offline-first Windows PDF font resolution

- Nirmala UI remains the preferred Indian-script font when present.
- Segoe UI and Arial are now valid local Windows base fonts, so absence of Nirmala UI no longer forces a network request.
- Added common optional Windows Indic fallback faces, including Mangal (Devanagari) and Kalinga (Odia/Oriya), plus other legacy Indian-script fonts.
- Segoe UI Symbol remains a local symbol candidate and the PDF engine's built-in Symbol font remains the final math fallback.
- `%WINDIR%` is honored instead of assuming Windows must be installed on `C:`.
- Linux/macOS plans that already existed are now also usable by the local resolver, which improves deterministic CI/desktop behavior.
- Added a host resolver API used by QA to check available local candidates without requiring one exact optional font.

Important: absolute offline Indic coverage on every possible Windows installation still depends on at least one suitable OS script font being installed. This fix removes the incorrect *Nirmala-only* requirement and prevents needless Google-font fallback when a stable local base font exists. The final RC smoke test should still export a real Hindi/Odia/math paper with Wi-Fi disabled.

### Honest PowerShell release gate

`tool/run_rc_candidate_1_gate.ps1` now wraps every Dart/Flutter/build command and checks `$LASTEXITCODE` explicitly. Any non-zero result throws immediately and the final green `gate passed` line is unreachable.

This is compatible with Windows PowerShell 5.1 and PowerShell 7.

## Changed project files

- `lib/features/pdf/services/pdf_export_theme_service.dart`
- `test/features/pdf/pdf_export_theme_service_test.dart`
- `test/release/rc_candidate_1_production_gate_test.dart`
- `tool/run_rc_candidate_1_gate.ps1`
- `RC1_QA_FIX.md`

## Re-run

```powershell
dart format .
flutter analyze
flutter test test/features/pdf/pdf_export_theme_service_test.dart
flutter test test/release/rc_candidate_1_production_gate_test.dart
flutter test test/release
flutter test
```

Then run the one-command gate again:

```powershell
.\tool\run_rc_candidate_1_gate.ps1
```

A failed command must now stop the script and print `EduSheet RC Candidate 1 gate FAILED.` instead of continuing to a false pass.
