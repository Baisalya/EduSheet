# EduSheet Step 8 — QA Fix 2

## Trigger
The Step 8 QA-fix build now has a clean analyzer and the dedicated release suite passes, but the complete `flutter test` run reported one widget-test failure in `dual_editor_mode_test.dart`.

## Root cause
The production behavior is correct: the Word free paragraph does **not** consume an assessment question. The failing assertion used:

```dart
find.textContaining('0 questions')
```

After switching back to Smart Mode there are legitimately two visible UI summaries containing that phrase:

- the section summary: `0 questions · 0 marks`
- the app-bar autosave summary: `1 section · 0 questions · Saving changes`

The test incorrectly required that broad finder to match exactly one widget.

## Fix
The regression test now asserts the exact section accounting summary:

```dart
find.text('0 questions · 0 marks')
```

This is stronger for the original requirement because it verifies both:

- the Word free paragraph consumed **zero questions**
- the Word free paragraph contributed **zero marks**

No production code, data model, database schema, package dependency, Smart Mode behavior, Word Mode behavior, preview, PDF, or DOCX export code changed.

## Changed files
- `test/features/paper_composer/dual_editor_mode_test.dart`

## QA performed in this environment
- `git diff --check` — clean
- patch reviewed — one assertion only
- ZIP integrity checked

Flutter/Dart is not available in this execution environment, so runtime tests must be run on the user's Flutter machine.

## Re-run
```powershell
dart format .
flutter analyze
flutter test test/release
flutter test
```
