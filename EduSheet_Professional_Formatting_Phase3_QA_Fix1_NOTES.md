# EduSheet — Professional Formatting Phase 3 QA Fix 1

Baseline: Professional Formatting Phase 3 implementation package.

## Windows QA findings fixed

1. `flutter analyze` reported two `use_build_context_synchronously` infos in the
   header arrange/save callback. The callback now guards the exact captured
   `BuildContext` with `context.mounted` after each async gap.
2. On compact Word Mode the only `Add section` control sat below the full WYSIWYG
   paper canvas. On 430x900 and 360x760 viewports it was physically off-screen,
   so automated taps missed it and the following Paragraph action had no section
   to target. That cascaded into missing Quill editors.
3. Compact Word Mode now keeps one `Add section` action directly below the ribbon,
   outside the scrolling paper canvas. Desktop/non-compact Word Mode retains the
   bottom-of-document action.
4. Regression tests now assert that the compact `Add section` control is inside
   the viewport before tapping it.

## Scope safety

- No document model/schema migration.
- No dependency changes.
- No Phase 3 WYSIWYG/header architecture rollback.
- No Smart/Word canonical paper split.
- No test-only workaround such as scrolling the old off-screen button into view;
  the actual compact UX is fixed.

## Windows re-run

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

Do not lock Phase 3 until analyzer, focused tests, release tests and the full
suite are green on the Windows release workstation.
