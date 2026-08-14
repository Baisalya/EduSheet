> **Superseded:** Create Paper now supports both PDF and Word export. See `PDF_AND_WORD_CREATE_PAPER_EXPORT_2026-08-14.md`. This file is retained only as historical implementation context.

# EduSheet Word-only question-paper export

Date: 2026-08-14

## Goal

Make Word (.docx) the only teacher-facing export format for question papers while preserving in-app preview, saved paper editing, existing templates, and unrelated tools such as the standalone OMR Generator.

## Architecture

A new `QuestionPaperExportService` is the single teacher-facing question-paper export entry point. `QuestionPaperExportPolicy` exposes only `QuestionPaperExportFormat.word`.

The service resolves the selected paper template through the existing `PaperTemplateResolver` and delegates DOCX generation to the existing `WordExportService`. No persistence or dependency changes were introduced.

## Teacher UX

### Create Paper
- In-app Preview remains available.
- Expanded Windows layout exposes a prominent `Export Word` action.
- Compact/mobile layouts expose `Export Word` in Paper actions.
- PDF export and PDF/print-preview export routes were removed from the paper action menu.
- The right inspector now offers `Export Word (.docx)` instead of PDF/print preview.

### Saved Papers
- Actions are now `Edit`, `Export Word`, and Delete.
- PDF, Excel, and PowerPoint question-paper actions are removed.
- Word export opens the generated DOCX after saving.

## Existing services

PDF/Spreadsheet/Presentation service implementations were not deleted because they are internal/legacy utilities and deleting them is unnecessary for the user-facing requirement. They are no longer called by question-paper Create Paper or Saved Papers UI.

The standalone OMR Generator remains unchanged because it is a separate feature. When a paper has `includeOmr`, Word export now explains that the OMR sheet is not embedded and should be generated with the OMR Generator; it no longer tells the teacher to use a paper PDF export that is unavailable.

## QA coverage

Added tests verify:
- question-paper export policy supports Word only;
- the centralized export service creates a `.docx` file;
- generated DOCX still contains paper content.

Static QA in this environment verified:
- no missing local `package:edusheet` imports;
- no delimiter/brace structural errors in changed Dart files;
- no user-facing `Export PDF`, PDF/print preview, Excel, or PPT actions remain in Create Paper / Inspector / Saved Papers;
- no direct `PdfService`, `SpreadsheetExportService`, or `PresentationExportService` usage remains in those question-paper UI surfaces.

Flutter/Dart CLI is not available in this environment, so run the final analyzer/test gate locally.

## Local validation

```powershell
flutter analyze
flutter test test/features/pdf/office_export_services_test.dart
flutter test
flutter test integration_test/question_creation_journey_test.dart -d windows
```

Manual checks:
1. Create Paper on Windows: confirm `Export Word` is visible and no PDF export is shown.
2. Create Paper on a narrow/mobile layout: Paper actions should contain `Export Word` only for export.
3. Saved Papers: confirm only `Export Word` is offered alongside Edit/Delete.
4. Export a paper with header/template, inline math, and geometry; open the resulting DOCX.
5. Export a paper with `includeOmr=true`; confirm Word contains the OMR Generator guidance note.
