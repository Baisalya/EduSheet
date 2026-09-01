# EduSheet Step 8 QA Fix

This hotfix is for the Step 8 Word Editing Surface after running `dart format .` and `flutter analyze`.

## Reported analyzer issues fixed

1. `PaperStructureService` undefined in `paper_composer_screen.dart`
   - Added the missing `paper_structure_service.dart` import.
   - This resolves both the delete-section assessment count reference and `_questionCount()`.
   - The reported `double` -> `int` fold closure error was a cascade from the unresolved service symbol; `assessmentQuestionCount()` returns `int`.

2. `curly_braces_in_flow_control_structures` in `word_paper_editor.dart`
   - Wrapped the compact `if` bodies in blocks.

3. `unnecessary_non_null_assertion` in `word_paper_editor.dart`
   - Removed `file!` where Dart flow analysis already proves the file is non-null inside the image branch.

## Scope

- No DB/schema change.
- No package/dependency change.
- No Smart/Word model behavior change.
- No test was weakened or removed.
- Only 2 production files changed.

## Validate locally

```powershell
dart format .
flutter analyze
flutter test test/release
flutter test
```
