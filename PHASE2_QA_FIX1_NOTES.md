# EduSheet Professional Formatting Polish — Phase 2 QA Fix 1

Windows QA exposed one compile-blocking placement error plus two analyzer-cleanliness issues.

## Root cause

The new `formattedHeadingText` and `sectionMarksText` getters were accidentally inserted twice: once into `Paper` and once into `PaperSection`. The `Paper` copy referenced section-only fields (`prefix`, `showTitle`, `headingUppercase`, `sectionMarksDisplay`), so analyzer/compiler stopped before Phase 2 tests could run.

## Fixes

1. Removed the accidental getters from `Paper`; retained them only on `PaperSection`.
2. Wrapped the new Phase 2 one-line `if` bodies in braces for the project's lint policy.
3. Fixed Word Mode uppercase heading presentation properly: the editor now keeps canonical `section.title` unchanged and uses `displayTransform` only for the visual uppercase state. This also makes the previously-unused optional parameter real and removes the analyzer warning without destructive uppercase saves.
4. No schema change, dependency change, marks-calculation change, or editor architecture change.

## Re-run on Windows

```powershell
dart format .
flutter analyze
flutter test test/features/editor/professional_paper_formatting_test.dart
flutter test test/features/pdf/office_export_services_test.dart
flutter test test/release
flutter test
```

This assistant environment does not contain Flutter/Dart, so no runtime/analyzer pass is claimed until the Windows run confirms it.
