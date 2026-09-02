# Professional Formatting Phase 4A — QA Fix 2

## Why this fix exists

Windows QA after QA Fix 1 exposed two remaining analyzer warnings and one Windows-only test harness timeout.

### Analyzer warnings

The Dart analyzer reported `unnecessary_non_null_assertion` in:

- `paper_details_sheet.dart`
- `paper_header_layout_canvas.dart`

Both branches already prove the `File` is non-null through the `canPreview` / `canShowImage` guards, so the redundant `!` operators were removed. No runtime behavior changes.

### Selected-logo widget test timeout

The production header logo rendering was correct, but the test created its PNG inside the same temporary directory used by the mocked path-provider. On Windows, `Image.file`/`FileImage` can keep a source handle alive briefly. QA Fix 1 then explicitly awaited `FileImage.evict()`, which could remain pending until the test's 10-minute timeout. The timeout was followed by a temp-directory deletion error because Windows still saw the logo file as in use.

QA Fix 2 makes the test deterministic:

- use the repository fixture `assets/Applogo.png` instead of creating a PNG inside the path-provider temp directory;
- still verify that the shared header canvas builds an `Image` backed by `FileImage` and that its path is exactly the selected logo path;
- dispose the widget with a bounded `pump`;
- do **not** await `FileImage.evict()` in the widget test.

This removes the Windows file-handle lifecycle from the assertion while still testing the selected-logo render path.

## Scope

No editor architecture, Paper schema, database, export format, dependency, question semantics, or logo behavior was changed.

## Files changed

1. `lib/features/paper_composer/presentation/widgets/paper_details_sheet.dart`
2. `lib/features/paper_composer/presentation/widgets/paper_header_layout_canvas.dart`
3. `test/features/paper_composer/word_direct_authoring_phase4a_test.dart`
4. `PHASE4A_QA_FIX2_NOTES.md`

## Windows QA

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

Do not upgrade the unrelated outdated packages during this focused QA pass.
