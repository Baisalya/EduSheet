# EduSheet Word Converter — Phase 1 + Phase 2 Handoff

Baseline: `EduSheet_Phase8_WordReader_SmoothPerformance_Hotfix_Full.zip`

Scope completed in this package:

- Phase 1: conversion architecture + honest user modes/platform capability.
- Phase 2: professional-v1 Word → PDF fidelity path.

## Architecture

Word → PDF no longer uses `word/document.xml -> plain paragraph strings -> new PDF`.

New path:

`DOCX package -> DocxConversionParser -> ConversionDocument model -> DocxPdfRenderer -> PDF`

The model separates sections, page settings, paragraphs, runs, tables, images and header/footer content so later converter upgrades do not have to grow inside one service method.

## Word → PDF fidelity implemented

Supported in the new structured path:

- Word paragraph/run text instead of filename-generated content.
- Paragraph styles plus direct formatting inheritance.
- Font size, bold, italic, underline, strike, text color and highlight.
- Common Windows Word font-family resolution when the matching installed font exists; safe PDF theme fallback otherwise.
- Paragraph alignment and before/after spacing.
- Numbered lists and safe bullet normalization.
- Tables, header-row hint, basic cell shading and common border preservation.
- Embedded raster images with OOXML drawing dimensions.
- External hyperlinks.
- Page size, orientation through page dimensions, margins and section boundaries.
- Explicit page-break handling.
- Header/footer text.
- Dynamic PAGE and NUMPAGES fields in header/footer output.
- Header/footer inheritance across sections when a later section does not redefine them.

The previous artificial filename heading is removed. Converter output does not intentionally add document content that was not present in the Word file.

## Honest PDF → Word modes

UI naming is now:

- `PDF to Word: Editable Document`
- `PDF to Word: Preserve Appearance`

`Preserve Appearance` explicitly says that text may not be directly editable.

The native page renderer exists in the current source only on Android. Therefore the Preserve Appearance action is disabled on unsupported desktop platforms instead of presenting an enabled action that fails after the user selects a file.

The existing PDF → Word engines are preserved; this phase does not replace their financial/document logic with a parallel converter.

## Intentionally not claimed as exact yet

These remain later fidelity tiers rather than fabricated support:

- Floating text boxes/shapes and advanced anchored drawing positioning.
- Word equations/OMML exact rendering.
- SmartArt/charts.
- Complex multi-column flow.
- Full theme/style-table semantics and every custom font.
- Pixel-identical pagination for every Microsoft Word layout behavior.
- Geometry-aware editable PDF → Word reconstruction (Phase 3).
- Windows native Preserve Appearance renderer parity (separate implementation still required).
- Production progress/cancel/save/recent-conversion UX (Phase 4).

## Regression coverage added

- `test/features/word_converter/docx_conversion_parser_test.dart`
  - styles/defaults
  - section/page geometry
  - hyperlink
  - numbering
  - table
  - image
  - header/footer
  - PAGE/NUMPAGES dynamic fields
- `test/features/word_converter/word_converter_service_test.dart`
  - Word → PDF content regression proving the source filename is not injected as document content
  - existing editable/exact PDF → Word regressions retained
- `test/features/word_converter/word_converter_screen_test.dart`
  - honest mode names and unsupported-platform disabled state

## Local release gate

Run from the EduSheet repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_word_converter_phase12_gate.ps1
```

Equivalent individual commands:

```powershell
flutter analyze --no-pub
flutter test test/features/word_converter/docx_conversion_parser_test.dart
flutter test test/features/word_converter/word_converter_service_test.dart
flutter test test/features/word_converter/word_converter_screen_test.dart
```

## Validation status in this handoff environment

The source/diff/package structure was checked here, but this execution environment does not contain a Flutter/Dart SDK. Therefore `flutter analyze` and Flutter tests were not falsely reported as passed. Run the gate above on the local EduSheet Flutter environment and return any analyzer/test output for root-cause correction.
