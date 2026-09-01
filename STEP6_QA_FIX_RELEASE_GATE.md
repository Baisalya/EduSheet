# EduSheet Step 6 — Release Gate QA Fix

This patch addresses the concrete issues reported by the Step 6 release-gate run without changing the Smart Paper data model, database schema, export semantics, or teacher workflow.

## Fixes

1. **Analyzer cleanup**
   - Replaced redundant named wildcard parameters (`__`, `___`) with Dart wildcards (`_`) in image error builders.
   - Replaced deprecated `DropdownButtonFormField.value` with `initialValue` in the stimulus editor.

2. **Preview semantic parity gate**
   - The preview intentionally renders the section prefix and title together (for example `A. Section A`).
   - The gate now validates normalized readable text from the preview document instead of requiring every semantic marker to exist as a standalone `Text` widget.

3. **PDF / Word semantic parity gate**
   - PDF text extraction can emit a line break between every visual token even when the rendered PDF is correct.
   - The gate now normalizes whitespace before checking semantic markers.
   - Word content is parsed from `word/document.xml` using the project's existing `xml` dependency and checked as normalized plain text.
   - The `Maximum Marks:` single-occurrence and `Assigned marks` exclusion checks remain enforced.

4. **Phone responsive gate**
   - `Add` is a legitimate label in several advanced-editor controls, so a global exact-count assertion was ambiguous.
   - The gate now scopes `Add` and `Math` to the keyed sticky mobile authoring toolbar (`question-mobile-authoring-tools`). This verifies the actual Step 3 phone authoring contract rather than unrelated nested controls.

## Files changed

- `lib/features/paper_composer/presentation/widgets/paper_preview_page.dart`
- `lib/features/paper_composer/presentation/widgets/question_advanced_content_panel.dart`
- `lib/features/paper_composer/presentation/widgets/question_image_attachment_sheet.dart`
- `lib/features/paper_composer/presentation/widgets/question_stimulus_sheet.dart`
- `test/release/smart_paper_export_parity_gate_test.dart`
- `test/release/smart_paper_responsive_gate_test.dart`
- `STEP6_QA_FIX_RELEASE_GATE.md`

## Validation to run on the development machine

```powershell
dart format .
flutter analyze
flutter test test/release
flutter test
```

Or use the existing Step 6 release-gate runner:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_smart_paper_release_gate.ps1
```
