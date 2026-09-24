# EduSheet Word Maturity WM3 + WM4

## Scope

WM3 + WM4 extends the already-passing WM1 + WM2 foundation with Word paragraph flow, tab/leader, numbering-marker and table-layout fidelity. It is intentionally generic OOXML support rather than resume-template hard-coding.

### WM3 — Paragraph / Tabs / Numbering / Flow

- Preserves paragraph style identity.
- Resolves paragraph properties from style inheritance, numbering level properties and direct overrides.
- Preserves `keepNext`, `keepLines`, `widowControl`, `contextualSpacing`, explicit page breaks and paragraph borders.
- Resolves tab stops including left/center/right/decimal/bar alignment, clear overrides and leaders.
- Renders Word tab stops with leader paint rather than flattening tabs into spaces.
- Resolves exact numbering/bullet glyphs from `numbering.xml`, including numbering-level run font such as Wingdings/Symbol.
- Supports decimal, alpha, Roman, decimal-zero and ordinal numbering markers with level counters/start overrides.
- Renders paragraph borders and contextual-spacing suppression in the fidelity viewer.
- Carries list-marker styling into the DOCX-to-PDF path.

### WM4 — Word Table Engine

- Preserves table style ID and resolves inherited table properties.
- Resolves table width (fixed/percent/auto), fixed-vs-autofit layout, alignment, indent and cell spacing from table styles with direct-property precedence.
- Resolves table borders including inside horizontal/vertical edges and explicit `none` removal.
- Applies table-style conditional formatting for whole table, horizontal/vertical bands, first/last row, first/last column and corner cells.
- Resolves table/cell shading, table cell margins, paragraph/run formatting inside styled cells.
- Preserves row header/repeat intent, `cantSplit`, exact/atLeast row height.
- Preserves `gridSpan`, vertical merge restart/continuation, percent/fixed cell widths, vertical alignment and `noWrap` including false-valued direct overrides.
- Renders Word border styles in the fidelity viewer and Smart Editor table surface (single/double/dotted/dashed/dash-dot/dash-dot-dot/thick/wave approximations).
- Smart Editor interop payload now carries style ID, table shading/borders/layout, row split rules, cell borders/percent widths/no-wrap and preserves them through structured edits.
- DOCX export writes preserved table style ID and resolved table/cell geometry/borders/shading/no-wrap/cantSplit semantics.

## Regression coverage

New tests:

- `test/features/document_reader/word_wm3_wm4_paragraph_table_engine_test.dart`
- `test/features/smart_editor/smart_editor_docx_wm3_wm4_test.dart`

Gate:

`tool/run_word_maturity_wm3_wm4_gate.ps1`

The gate runs analyzer, WM3/WM4 contracts, WM1/WM2 contracts, Smart Editor crop round-trip, nested-table runtime regression, DF5 responsive/performance, DF4 Smart Editor DOCX round-trip, DF2 advanced layout and DF6 production-like DOCX regression.

## Run

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_word_maturity_wm3_wm4_gate.ps1
```

## Phase boundary

WM3 + WM4 does not claim completion of floating shapes/text-wrap/z-order or section/page/header/footer pagination parity. Those remain WM5 + WM6. Advanced fields, footnotes/endnotes/comments/equations and full unknown-OOXML round-trip preservation remain later maturity phases.
