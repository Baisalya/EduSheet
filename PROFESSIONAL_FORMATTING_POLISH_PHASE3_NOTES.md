# EduSheet — Professional Formatting Polish Phase 3 QA Notes

## Baseline

Professional Formatting Phase 2 QA Fix 1 was user-verified on Windows:

- `flutter analyze` — no issues
- professional formatting tests — `+4`
- office/export tests — `+17`
- release tests — `+15`
- full suite — `+321`

## Phase 3 changed areas

- shared Preview/Word page-canvas metrics
- shared editable/read-only header renderer
- professional built-in header geometry and metadata ordering
- Word Mode header arrangement designer
- custom-template save/apply flow
- Word Mode template border/font/two-column parity
- PDF/DOCX shared header-field resolution
- Phase-3 WYSIWYG tests and release gate

## Static QA completed in assistant environment

- changed `package:edusheet/...` imports resolve
- changed Dart files pass delimiter/string/comment structural scan
- no merge-conflict markers
- clean patch generated from the Phase-2 QA Fix 1 baseline
- patch apply-check performed against a fresh baseline copy
- modified/full ZIP archive integrity verified

Flutter/Dart executables are not available in the assistant container, so no
analyzer/runtime pass is claimed for Phase 3 until the Windows run confirms it.

## Windows QA

```powershell
dart format .
flutter analyze

flutter test test/features/paper_composer/wysiwyg_header_phase3_test.dart
flutter test test/features/paper_composer/dual_editor_mode_test.dart
flutter test test/release/professional_formatting_phase3_gate_test.dart
flutter test test/features/pdf/office_export_services_test.dart
flutter test test/release
flutter test
```

## Manual WYSIWYG smoke test

1. Choose Centered formal, Board classic, Academic and Modern compact styles.
2. Compare Word Mode and Preview at A4 portrait, A4 landscape and Letter.
3. Change margins and verify Word/Preview page padding changes together.
4. Edit School, Exam title and header metadata directly in Word Mode.
5. Open `Arrange header`, drag/resize an element, save, and verify Preview and
   PDF reflect the custom geometry.
6. Use a two-column template and verify Preview and Word Mode show the same
   two-column question flow.
7. Insert a manual page break and verify the section safely falls back to
   single-column flow rather than breaking the document structure.
8. Export PDF and DOCX; confirm metadata order/content is preserved.
