EduSheet PDF + Word export patch

Baseline:
  EduSheet_question_bank_test_compile_fix_full.zip

Apply:
1. Extract this modified-files ZIP into the EduSheet project root.
2. Allow it to overwrite the listed files.
3. No files need to be deleted for this patch.
4. No pubspec/dependency or database/schema change is included.

Teacher-facing result:
- Create Paper exposes Export PDF and Export Word.
- Expanded Windows layout shows compact PDF + Word actions.
- Compact/Android/free-form Paper Actions menu contains both formats.
- Windows inspector contains both formats.
- Saved Papers contains both formats.

Recommended verification:
  flutter analyze
  flutter test test/features/pdf/office_export_services_test.dart
  flutter test
  flutter test integration_test/question_creation_journey_test.dart -d windows
