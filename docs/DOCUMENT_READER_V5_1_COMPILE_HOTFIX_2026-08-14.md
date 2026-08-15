# EduSheet Document Reader v5.1 Compile Hotfix

Date: 2026-08-14

## Trigger
Windows Flutter QA on the v5 document-reader refactor reported 8 analyzer findings, including one blocking compile error in `pdf_document_viewer.dart` because `TextSearchOption.none` is unavailable in the project's pinned Syncfusion version.

## Fixes

1. `pdf_document_viewer.dart`
   - Removed the explicit `TextSearchOption.none` argument.
   - Uses `PdfViewerController.searchText(query)` so the viewer follows the package's default search behavior.
   - Removed the now-unneeded `syncfusion_flutter_pdf/pdf.dart` import from the viewer.

2. `presentation_parser_service.dart`
   - Removed redundant `dart:typed_data` import.
   - Removed impossible `ArchiveFile.content` runtime type branch and now returns the typed archive bytes directly.

3. `spreadsheet_parser_service.dart`
   - Removed redundant `dart:typed_data` import.
   - Removed impossible `ArchiveFile.content` runtime type branch and now returns the typed archive bytes directly.

4. `spreadsheet_document_viewer.dart`
   - Cleaned the separator callback parameter lint (`(_, _)`).

## Scope
No dependency versions were changed. No calculator, question-paper export, PDF export, Word export, database, or document activation architecture was modified by this hotfix.

## Required Windows verification

```powershell
flutter analyze
flutter test test/features/document_reader
flutter test
flutter run -d windows
```

Expected release gate: `flutter analyze` should have no findings caused by this hotfix and the document-reader tests should compile past the previous `TextSearchOption.none` blocker.

## Known unrelated output
The previously observed Noto font download failures / Helvetica fallback messages originate from PDF export tests and are not the document-reader compile failure fixed here.
