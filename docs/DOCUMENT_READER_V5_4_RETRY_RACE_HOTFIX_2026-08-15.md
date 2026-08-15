# EduSheet Document Reader v5.4 — Retry Race Hotfix

## Scope
This hotfix addresses the two remaining document-reader widget-test failures after v5.3. `flutter analyze` was already clean; the failures occurred only when Retry was tapped on immediately-failing PPTX/XLSX cloud-placeholder loads.

## Root cause
`FutureBuilder` was already showing the original cloud-file error correctly. On Retry, however, the viewer created a new parser Future inside `setState`. A parser that failed immediately could complete with an error before the rebuilt `FutureBuilder` had subscribed to that new Future. Flutter Test therefore surfaced `DocumentFileReadException` as an unhandled exception even though the UI had an error-state builder.

This is a subscription timing race, not a parser-format failure and not the older "setState callback returned a Future" assertion.

## Fix
Both `PresentationDocumentViewer` and `SpreadsheetDocumentViewer` now:

1. Create a `Completer<T>` for the next load.
2. Install `completer.future` synchronously in `setState`.
3. Start the actual parser load from a post-frame callback, after `FutureBuilder` has rebuilt and subscribed.
4. Complete the controlled Future with either the parsed result or the caught error.
5. Re-check `mounted` and completion state after the async read so navigating away during OneDrive hydration cannot publish into a disposed viewer.

No dependency changes were made.

## Files changed from v5.3
- `lib/features/document_reader/presentation/widgets/viewers/presentation_document_viewer.dart`
- `lib/features/document_reader/presentation/widgets/viewers/spreadsheet_document_viewer.dart`
- `docs/DOCUMENT_READER_V5_4_RETRY_RACE_HOTFIX_2026-08-15.md`

## Expected verification
Run:

```powershell
flutter analyze
flutter test test/features/document_reader
flutter test
```

Expected document-reader behavior:
- OneDrive/offline PPTX shows the recoverable cloud-file message.
- Tapping Retry does not emit an unhandled exception.
- XLSX behaves the same way.
- If the file becomes locally available before Retry, the same viewer can load it normally.
- Closing the viewer while a retry is in progress does not publish state into a disposed widget.

## Unrelated warnings
The Noto/Helvetica messages from PDF export tests are unrelated font-download/fallback warnings and are outside this hotfix.
