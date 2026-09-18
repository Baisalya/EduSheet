# EduSheet Document Reader — Phase 8 Production Responsive Regression + Release Gate

## Baseline

Phase 8 is applied on top of:

`EduSheet_Phase7_PresentationOverflow_AnalyzerHotfix_Full.zip`

No Phase 4–7 presentation capability was removed or replaced.

## Phase 8 objective

Phase 8 is a stabilization/release-certification phase. It does not add a new reader feature. It locks the existing PDF, Word, PPTX, spreadsheet and document-open architecture behind repeatable responsive and regression gates.

## Production hardening change

`lib/features/document_reader/presentation/screens/file_preview_screen.dart`

The document capability strip previously decided compact/wide presentation from the outer `MediaQuery` width. That can be wrong when the reader is rendered inside a narrower allocation, including Android free-form, split panes, resizable Windows panes and widget-test containers.

Phase 8 moves this decision to a local `LayoutBuilder.constraints.maxWidth` contract. This matches the Phase 7 presenter-chrome hotfix and removes the remaining outer-width responsive dependency inside `lib/features/document_reader`.

## New responsive gate

`test/features/document_reader/document_reader_phase8_responsive_gate_test.dart`

The test certifies the following viewport matrix:

- 320×720
- 360×800
- 390×844
- 600×700
- 720×540
- 1280×800

It validates:

1. Word phone/tablet Fit Width remains inside the actual viewport.
2. 320px → 304px Word page width with 8px gutters.
3. 360px → 344px Word page width with 8px gutters.
4. 390px → 374px Word page width with 8px gutters.
5. Desktop Word remains print-layout-oriented and bounded.
6. PPT 16:9 stage is contained without crop/stretch.
7. Capability strip responds to its real local allocation, not outer `MediaQuery` width.
8. A deliberately long document name does not create narrow-pane overflow.
9. PPT preview → Present → slide overview → jump → exit remains overflow-safe across all release viewports.

## New global release contract

`test/release/document_reader_phase8_production_gate_test.dart`

This test is intentionally placed under `test/release` so the normal EduSheet release test suite also covers the Document Reader Phase 8 contract.

It locks:

- In-app preview support: PDF, DOCX, XLSX, CSV, PPTX, TXT.
- Capability-honest external-only behavior: DOC, RTF, ODT, XLS, ODS, PPT, ODP.
- 320/360/390 Word Fit Width cannot be policy-forced wider than the viewport.

## Executable production gate

Run from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_document_reader_phase8_gate.ps1
```

The default gate runs:

1. `flutter analyze --no-pub`
2. Phase 8 responsive matrix test
3. Document viewport policy tests
4. Presentation stage policy tests
5. Document viewer widget tests
6. PPT animation timeline tests
7. PPT animation parser tests
8. PPT Theme/Master/Layout tests
9. PPT parser tests
10. Document-open architecture tests
11. Spreadsheet parser tests
12. Phase 8 release contract test

Optional full EduSheet regression:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_document_reader_phase8_gate.ps1 -FullSuite
```

Optional production builds:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_document_reader_phase8_gate.ps1 -BuildAndroid -BuildWindows
```

For the strongest automated gate:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_document_reader_phase8_gate.ps1 -FullSuite -BuildAndroid -BuildWindows
```

When build switches are supplied, the script also verifies the release artifact exists, is non-empty, and prints SHA-256.

## Manual RC lock

Automated green is required but does not replace real-file smoke testing.

### Android phone

Test at least one real 320/360/390-class or resized viewport:

- PDF opens Fit Width without initial horizontal scrolling.
- PDF Fit Page / Fit Width switching works.
- PDF search, page jump and pinch/double-tap zoom work.
- DOCX opens Fit Width and remains readable without policy-forced horizontal scrolling.
- DOCX search and pinch zoom work.
- PPTX preview keeps the whole slide visible at default zoom.
- Present mode enters/exits cleanly.
- Slide overview opens and jump works.
- On Click / With Previous / After Previous sequences still progress correctly.
- Theme/master/layout visual fidelity remains intact.

### Windows

- Resize the document window down to a narrow/free-form size and back to desktop size.
- Word switches to the correct effective default based on current allocation.
- PDF toolbar/search does not overflow.
- PPT preview remains aspect-ratio safe.
- F5 starts presentation from slide 1.
- Present mode restores previous window size/position after exit.
- Esc exits cleanly.
- Slide overview, black screen (B), white screen (W), arrows, Space and PageUp/PageDown work.

## Release decision rule

Document Reader Phase 8 can be marked release-ready only when:

- `flutter analyze --no-pub` reports no issues.
- `tool/run_document_reader_phase8_gate.ps1` reaches PASSED.
- If release builds are required, the selected build switches complete successfully.
- Android and Windows manual real-file smoke checks pass.

This phase does not claim runtime validation inside the ChatGPT execution container because Flutter/Dart SDK executables are not installed there. Local output is the authoritative runtime gate.
