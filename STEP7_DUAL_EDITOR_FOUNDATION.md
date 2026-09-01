# EduSheet Step 7 — Dual Editor Foundation

## Goal
Add a second, Word-style editing surface inside Create Paper without creating a second paper file or flattening the existing Smart Paper structure.

## Architecture decision
`Paper` remains the single source of truth.

- Smart Mode reads/writes the existing structured `Paper -> PaperSection -> Question` graph.
- Word Mode reads/writes that same provider state.
- Switching modes performs no export/import, serialization conversion, cloning, or document migration.
- Rich question bodies are not flattened to plain text. Word Mode opens the existing rich question editor for those blocks, preserving Quill deltas, formula embeds, geometry embeds, tables, images, sub-questions, OR choices and metadata.

This is intentionally the safe foundation for Step 8. Step 8 can add inline Word-style rich editing on top of the same source model rather than introducing a parallel DOCX/Quill document that would drift from Smart Mode.

## Implemented
- Smart / Word mode switch inside Create Paper on Android and Windows layouts.
- Mode state stays on the Create Paper screen while rich question editors are opened and closed.
- Word Mode A4-like document surface.
- Direct inline editing for:
  - school / institution name
  - paper title
  - header field values
  - general instruction
  - section title
  - section instruction
- Placeholder header fields become real values when typed so PDF/Word export does not keep printing an underscore placeholder.
- Word Mode renders the current Smart Paper question content instead of a copied representation:
  - rich question text
  - math / geometry embeds through existing rich preview
  - MCQ/options
  - stimulus / passage / case-study text
  - word bank
  - table/data
  - image/diagram attachments when the local file exists
  - sub-questions
  - internal OR alternatives
  - marks
- Tapping a rich question opens the existing lossless Question Composer, with the current Math and Geometry tools.
- Add Section and Add Question actions are available from Word Mode and mutate the same Smart Paper document.
- Inline text fields synchronize with external Smart Mode changes and undo/redo when they are not actively focused.
- Mobile layout avoids the desktop outline/inspector chrome and keeps the document scrollable.

## Files
Production:
- `lib/features/paper_composer/presentation/screens/paper_composer_screen.dart`
- `lib/features/paper_composer/presentation/widgets/word_paper_editor.dart` (new)

Tests:
- `test/features/editor/create_paper_save_sheet_test.dart`
- `test/features/paper_composer/dual_editor_mode_test.dart` (new)

## Deliberately deferred to Step 8
The following are not faked in Step 7:
- arbitrary rich paragraph insertion anywhere on the page
- font family / font size ribbon
- bold / italic / underline for arbitrary Word-mode paragraphs
- paragraph alignment / indentation / line spacing
- draggable text boxes
- inline editing of structured rich questions directly on the Word page
- page rulers and precise Word-like tab stops

Those require a proper inline rich-document editing layer. Step 7 establishes the non-destructive dual-editor boundary first so those features can be added without breaking Smart Mode.

## Local QA command
```powershell
dart format .
flutter analyze
flutter test
```

The ChatGPT execution container used for this phase does not include Flutter/Dart, so these commands must be run on the development machine before locking Step 7.
