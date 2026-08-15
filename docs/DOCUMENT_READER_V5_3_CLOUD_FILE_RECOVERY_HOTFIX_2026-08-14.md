# EduSheet Document Reader v5.3 — Cloud File Recovery Hotfix

Date: 2026-08-14

## Trigger

Windows PPTX opening failed for a OneDrive-backed file with `FileSystemException` OS error 362 (`The cloud file provider is not running`). Pressing Retry also triggered Flutter's `setState() callback argument returned a Future` assertion.

## Root causes

1. PPTX/XLSX parser services read directly from `File.readAsBytes()` and did not classify cloud-placeholder availability failures.
2. Presentation and spreadsheet retry handlers used arrow callbacks such as `setState(() => _future = _load())`. The assignment expression returns the `Future`, violating Flutter's synchronous `setState` callback contract.

## Structural fix

- Added `DocumentFileReadService` as the shared OOXML byte-access boundary.
- Added typed `DocumentFileReadException` and `DocumentFileReadFailure` classifications.
- Windows OS error 362 is classified as `cloudProviderUnavailable`.
- PPTX and XLSX parser services now use the shared byte-access service.
- PPTX displays an actionable OneDrive/offline recovery state instead of a generic unreadable-presentation message.
- Spreadsheet viewer receives the same protection for equivalent cloud-placeholder failures.
- Retry handlers now use block-bodied synchronous `setState` callbacks.
- Existing parser/renderer architecture and dependencies are unchanged.

## User recovery behavior

When Windows exposes a OneDrive placeholder but the OneDrive provider is stopped, EduSheet cannot obtain the file bytes. The app now remains stable and instructs the user to start OneDrive or make the file available offline, then press Retry. Once Windows can provide the bytes, the same PPTX parser resumes normally.

## Regression coverage

- PPTX cloud-placeholder failure renders a recoverable error state.
- PPTX Retry does not return a `Future` from `setState`.
- Spreadsheet cloud-placeholder Retry has the same safety coverage.
- Existing phone/desktop presentation and spreadsheet tests are preserved.

## Runtime gate

This environment does not include Flutter/Dart, so final verification must be run on the Windows Flutter environment:

```powershell
flutter analyze
flutter test test/features/document_reader
flutter test
flutter run -d windows
```
