# EduSheet Step 9 — Word-style Page & Layout Tools

## Goal

Step 9 adds document/page-layout controls on top of the Step-8 dual Smart/Word editor without introducing a second paper model. The canonical `Paper` remains the source of truth for Word Mode, Smart Mode, preview, PDF and DOCX export.

## Implemented

### Canonical page layout

A new backward-compatible `PaperPageLayout` value is persisted inside `Paper` JSON. Old papers without this field load safe defaults automatically.

Supported settings:

- Page size: paper style/template, A4, A5, A3, Letter, Legal
- Portrait / landscape
- Independent top/right/bottom/left margins
- Header distance
- Footer distance
- Line spacing: 1.0 / 1.15 / 1.5 / 2.0 from the authoring UI
- Paragraph spacing
- Page-number position: footer center, footer right, header right
- Repeated header text
- Repeated footer text
- Page numbers on/off

No database migration and no new package dependency are required.

### Android + Windows page setup

Word Mode now exposes a `Layout` / `Page setup` action.

- Phone/compact mode: scrollable bottom sheet
- Windows/wide mode: bounded dialog
- Margin presets: Normal, Narrow, Moderate
- Numeric margin entry uses millimetres for teacher-friendly editing
- Settings are applied back to the same `Paper` through the editor provider

### Word Mode canvas

The Word canvas reacts to page size, orientation, margins, line spacing and paragraph spacing. Running header/footer/page-number previews are shown in the document surface.

### Manual page break

Word Mode can insert a real manual page-break block.

The block is compatibility-safe metadata-backed Word content, therefore it:

- consumes 0 marks
- consumes no question number
- does not affect Answer Any N
- does not enter OMR counts
- does not become a Question Bank assessment item

Smart Mode preserves it as Word content rather than destructively converting it.

### Preview parity

Paper preview now reflects:

- selected page proportions
- portrait/landscape orientation
- asymmetric margins
- line spacing
- paragraph spacing
- running header/footer/page-number position
- section page-break markers
- manual Word page-break markers

### PDF parity

Normal Create Paper PDF export now uses the canonical page-layout settings when no explicit specialist export override is supplied:

- page size and orientation
- asymmetric margins
- running header/footer
- page numbers and position
- manual page breaks
- section page breaks
- paragraph spacing around section/question flow

Existing `PaperExportConfig` remains an explicit export override for specialist output modes.

### DOCX parity

The handmade OpenXML exporter now writes page-layout information into the DOCX package:

- `w:pgSz` for selected page size
- `w:orient="landscape"` where applicable
- asymmetric `w:pgMar`
- header/footer distances
- proper header/footer package parts and relationships
- styles relationship + `word/styles.xml`
- document line/paragraph spacing defaults
- PAGE and NUMPAGES fields
- footer-center / footer-right / header-right page-number placement
- real `<w:br w:type="page"/>` manual page breaks

When a manual page break exists inside a two-column template section, Word export intentionally falls back to linear section flow for that section so the explicit page break is not trapped inside a table cell.

## QA added

- Legacy Paper JSON gets page-layout defaults
- Step-9 page settings survive Paper JSON round-trip
- Unsafe persisted page-layout values are bounded
- Manual page break consumes no assessment ordinal/marks
- DOCX page size/orientation/margins are asserted
- DOCX header/footer/styles relationships are asserted
- PAGE/NUMPAGES fields are asserted
- Manual page break is asserted in `word/document.xml`

## Validation performed in this packaging environment

The packaging environment does not contain Flutter/Dart, so runtime Flutter tests cannot be executed here. Static checks performed before packaging:

- `git diff --check`
- all changed `package:edusheet/...` imports resolve
- string/comment-aware delimiter scan across changed Dart files
- no merge conflict markers in changed files
- ZIP CRC/integrity validation

## Required workstation gate

Run after applying the modified ZIP:

```powershell
dart format .
flutter analyze
flutter test test/features/editor/paper_page_layout_test.dart
flutter test test/features/pdf/office_export_services_test.dart
flutter test test/release
flutter test
```

Step 9 should be locked only after the real Flutter workstation reports a clean analyzer and passing tests.
