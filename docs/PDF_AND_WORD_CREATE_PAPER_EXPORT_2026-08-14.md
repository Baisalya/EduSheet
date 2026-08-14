# PDF + Word export in Create Paper

## Goal
Create Paper exposes exactly the two teacher-facing formats requested for a question paper:

- **PDF** for a print-ready paper.
- **Word (.docx)** for an editable teacher copy.

The export paths share `QuestionPaperExportService`, which resolves the selected `PaperTemplate` before delegating to the existing `PdfService` or `WordExportService`. No new storage schema or package is introduced.

## UX

### Windows / expanded composer
The app bar shows compact **PDF** and **Word** actions side by side. The inspector also lists both formats with purpose-focused descriptions.

### Android / compact / free-form
The existing Paper Actions menu contains **Export PDF** and **Export Word**, avoiding extra permanent buttons on small screens.

## Compatibility
- Existing PDF renderer and template/header architecture are reused.
- Existing Word exporter is unchanged.
- Question Bank, inline Math, Smart Geometry and paper persistence contracts are unchanged.
- `pubspec.yaml` and `pubspec.lock` are unchanged.

## QA
`office_export_services_test.dart` now asserts that the public question-paper export policy supports PDF and Word and that the centralized coordinator can create both file types.


## Saved Papers
Saved Papers exposes the same **Export PDF** and **Export Word** pair so the teacher does not have to reopen the composer just to choose a format.
