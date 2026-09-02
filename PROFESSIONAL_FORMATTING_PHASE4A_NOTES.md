# EduSheet — Professional Formatting Phase 4A QA Notes

## Baseline

Phase 4A starts from the RC Candidate 2 automated-green / Professional Formatting Phase 3 QA Fix 1 tree. Phase 3 and RC2 are not reopened architecturally.

## Teacher-facing changes

- Word Mode creates assessment questions directly on the page.
- Math/Geometry continue to use the active inline rich-text session.
- Picture inserts into the active assessment question and exposes Replace/Remove.
- Header logo slots are direct Choose/Replace/Remove targets and render the real selected image in the shared Word/Preview header canvas.
- Paper Setup shows a real logo thumbnail.

## Reliability hardening included during completion

- Picture targeting explicitly ignores free Word-content blocks, preventing a free paragraph from silently becoming the owner of an assessment-picture attachment.
- Picture replacement preserves the existing attachment id.
- Picture management controls are shown only for image attachments, so file/geometry attachment kinds are not accidentally replaced through the image picker.
- DOCX logo serialization preserves canonical logo-slot indexes even when earlier logo slots are empty and even when the custom layout's element order differs from Word's visual x/y serialization order.

## Static QA in assistant environment

- All changed `package:edusheet/...` imports resolve.
- Changed Dart files pass delimiter/string/comment structural scan.
- No merge-conflict markers in changed files.
- Patch will be generated against the exact RC2 baseline and apply-checked against a fresh copy.
- Modified/full ZIP CRC integrity will be verified.

Flutter/Dart executables are not installed in the assistant container, so no analyzer/runtime test pass is claimed here. Windows QA is authoritative.

## Windows QA

```powershell
dart format .
flutter analyze
flutter test test/features/paper_composer/word_direct_authoring_phase4a_test.dart
flutter test test/features/paper_composer/dual_editor_mode_test.dart
flutter test test/features/paper_composer/wysiwyg_header_phase3_test.dart
flutter test test/release/professional_formatting_phase4a_gate_test.dart
flutter test test/features/pdf/office_export_services_test.dart
flutter test test/release
flutter test
```

Do not lock Phase 4A until analyzer, focused tests, release tests and full regression are green and Windows/Android manual smoke confirms direct typing, Math/Geometry focus, logo Choose/Replace/Remove, question Picture Add/Replace/Remove, Preview/PDF/DOCX parity and autosave/reopen persistence.
