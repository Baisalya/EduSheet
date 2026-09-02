# Phase 4A QA Fix 1

Baseline: Professional Formatting Phase 4A direct authoring completion package.

## Windows QA failures addressed

1. Direct Word question test expected the grammatically correct Smart Mode section summary `1 question · 1 mark`, while the section card always rendered the plural `marks`.
   - `PaperSectionCard` now uses singular `mark` only when total marks equals 1.
   - Existing plural output remains unchanged for 0, decimals and values other than 1.

2. `word_paper_editor.dart` introduced a direct `showModalBottomSheet` for logo actions, violating the app-wide adaptive modal gate.
   - Logo Choose/Replace/Remove now uses `showAdaptiveModalBottomSheet`.
   - This preserves finite full-width modal constraints on compact Windows and Android.

3. The Phase 4A logo rendering widget test used `pumpAndSettle()` while a Windows `FileImage` decode remained pending, causing the 10-minute test timeout and a temp-directory file-lock cleanup error.
   - The structural test now pumps once, verifies the actual `FileImage` path directly, disposes the widget, evicts the image provider and clears live/cache entries.
   - Temp directory cleanup includes a short bounded retry for Windows file-handle release.
   - Production logo rendering behavior is unchanged.

## Scope

No Paper schema, database, dependency, export model, Smart/Word canonical architecture, marks calculation, question image model or Phase 4A feature behavior was changed beyond the singular UI label and adaptive logo action presentation.

## Windows QA rerun

```powershell
dart format .
flutter analyze
flutter test test/features/paper_composer/word_direct_authoring_phase4a_test.dart
flutter test test/shared/presentation/adaptive_modal_usage_test.dart
flutter test test/features/paper_composer/dual_editor_mode_test.dart
flutter test test/release/professional_formatting_phase4a_gate_test.dart
flutter test test/features/pdf/office_export_services_test.dart
flutter test test/release
flutter test
```

Do not lock Phase 4A until the rerun is green.
