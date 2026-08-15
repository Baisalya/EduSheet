# EduSheet Document Reader v5.2 — Phone Layout Hotfix

Date: 2026-08-14

## Trigger

Windows QA confirmed `flutter analyze` passes with no issues. The document-reader widget suite then exposed two UI issues:

1. Legacy Office files displayed the capability headline `External Office viewer recommended` twice: once in the global capability strip and once in the unsupported-viewer card.
2. The PPTX toolbar overflowed by 195 px at a 320 px viewport and exposed the desktop `Present` action instead of the compact `Play` action.

## Root causes

### Duplicate capability headline

`FilePreviewScreen` intentionally renders a capability strip above every viewer. `UnsupportedDocumentViewer` reused the exact same capability label as its card heading, creating redundant information and causing an exact-one widget assertion to fail.

### PPTX compact-mode mismatch

`PresentationDocumentViewer` correctly uses `LayoutBuilder` to adapt its main content to the actual allocated width. `_PresentationToolbar`, however, independently used `MediaQuery.sizeOf(context).width` to choose compact mode. In nested/resizable/free-form layouts the window width can differ from the toolbar's real allocation. That allowed desktop toolbar controls to be rendered inside a 320 px allocation.

## Fixes

- `_PresentationToolbar` now uses its own `LayoutBuilder` constraints as the responsive source of truth.
- Widths below 650 px use compact presentation controls and hide zoom controls.
- Widths below 360 px use an even smaller text-only `Play` button while preserving previous/next slide controls and slide position.
- `UnsupportedDocumentViewer` now uses `Open with another app` as the card heading for `externalOnly` formats. The capability strip retains `External Office viewer recommended`, so the capability classification remains visible without duplicate copy.
- No document parsing, activation, export, calculator, dependency, or storage behavior was changed.

## Expected QA after applying v5.2

```powershell
flutter analyze
flutter test test/features/document_reader
flutter test
flutter run -d windows
```

Expected result for the two previously failing document-reader tests:

- `legacy Office format stays capability-honest on a phone` — pass.
- `PPTX viewer adapts between phone and desktop layouts` — pass with no RenderFlex overflow at 320x720; `Play` visible on phone and `Present` visible on desktop.

## Scope

Production source changes:

- `lib/features/document_reader/presentation/widgets/viewers/presentation_document_viewer.dart`
- `lib/features/document_reader/presentation/widgets/viewers/unsupported_document_viewer.dart`

New QA document:

- `docs/DOCUMENT_READER_V5_2_PHONE_LAYOUT_HOTFIX_2026-08-14.md`

The existing tests were intentionally left unchanged because the failures represented real production UX issues rather than incorrect test assumptions.
