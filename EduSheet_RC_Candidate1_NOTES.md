# EduSheet RC Candidate 1 — QA Notes

Baseline: Step 10 QA-locked project. User-reported baseline status before RC1:

- `flutter analyze` clean
- Smart Paper DOCX round-trip tests passed
- Office export tests passed
- `flutter test test/release` passed
- full `flutter test` passed with `+308`

## RC1 production changes

1. Added `PdfExportThemeService`.
   - Windows: local Nirmala UI + Segoe UI Symbol/Arial variants first.
   - Android: local Noto Sans + math/symbol/Indic fallbacks first.
   - Existing `PdfGoogleFonts` path remains compatibility fallback.
   - Built-in Helvetica/Symbol last-resort theme prevents a failed font download from becoming an export exception.
   - Theme is cached and shared.

2. `QuestionPaperService` now uses the shared offline-first PDF theme.

3. `WordConverterService.convertDocxToPdf` now uses the same shared theme instead of a separate network-first font load.

4. Added release/real-device gates.
   - 360px Android Word Mode keeps Paragraph in the initially reachable toolbar area.
   - Paragraph remains tappable and opens rich authoring.
   - Math, Geometry and Import Word remain available.
   - 520px free-form Windows Word Mode renders without layout exceptions.
   - Windows/Android release font plans are validated.
   - On a Windows test host, Nirmala UI and Segoe UI Symbol presence is explicitly checked.

5. Added one-command RC gate:
   `tool/run_rc_candidate_1_gate.ps1`

## No architecture churn

- no DB/schema migration
- no dependency upgrades
- no document-model split
- no Smart/Word round-trip redesign
- no app/store version bump
- no font files added to the project

## Static QA completed in the assistant environment

- changed `package:edusheet/...` imports resolve
- Dart delimiter/string/comment balance scan clean for changed Dart files
- no merge conflict markers
- `git diff --check` clean
- patch generated from the Step 10 baseline
- ZIP CRC/integrity checked after packaging

Flutter/Dart are not installed in the assistant container, so RC1 runtime/analyzer pass is intentionally not claimed here.

## Recommended Windows validation

```powershell
dart format .
flutter analyze
flutter test test/features/pdf/pdf_export_theme_service_test.dart
flutter test test/release/rc_candidate_1_production_gate_test.dart
flutter test test/features/editor/autosave_coordinator_test.dart
flutter test test/features/editor/large_paper_performance_test.dart
flutter test test/features/paper_composer/dual_editor_mode_test.dart
flutter test test/release
flutter test
```

Or run:

```powershell
.\tool\run_rc_candidate_1_gate.ps1
```

For actual release binaries:

```powershell
.\tool\run_rc_candidate_1_gate.ps1 -BuildWindows -BuildAndroid
```

## Manual offline export smoke test

Disable Wi-Fi/mobile data, then export a paper containing:

- English
- Hindi/Devanagari
- Odia
- `− × ÷ √ π`

Open/share the generated PDF and confirm the scripts/symbols render correctly.
