# EduSheet Word Converter Phase 3 Handoff

## Scope
Phase 3 upgrades **PDF -> Word / Editable Document** from plain extracted lines to geometry-aware reconstruction. Phase 1+2 Word -> PDF fidelity and PDF -> Word / Preserve Appearance remain intact.

## Implemented
- Syncfusion `extractTextLines()` line/word geometry path for selectable PDFs.
- Page-aware reconstruction model preserving original PDF page size and inferred content margins.
- Reading-order analysis with conservative two-column detection.
- Wrapped-line paragraph joining and conservative de-hyphenation.
- Heading inference from relative font size / bold metadata.
- Direct Word run formatting for source font family, size, bold, italic, underline and strike where available.
- Conservative simple-table inference from repeated aligned word geometry; ambiguous layouts remain paragraphs rather than fabricated tables.
- Structured Android OCR fallback using ML Kit blocks/lines/elements with bounding boxes instead of only final OCR text.
- Editable DOCX writer with semantic Heading 1 / Heading 2 styles, editable Word tables, per-page section geometry, portrait/landscape page sizes and inferred margins.
- Existing Preserve Appearance mode remains image-per-page and is not changed by this phase.

## Deliberate limits
- Advanced arbitrary PDF graphics, floating text boxes, vector diagrams and complex nested tables are not reconstructed as editable Word objects.
- OCR geometry fallback still depends on the existing Android native PDF page renderer. Windows scanned-PDF OCR parity remains a later platform-renderer item.
- Table inference is intentionally conservative to avoid turning two-column prose into fake tables.
- Exact original fonts can only be represented by their source family names; Word will fall back if a font is not installed on the destination device.

## Local release gate
Run from the EduSheet repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_word_converter_phase3_gate.ps1
```

The gate is fail-fast and covers analyzer, Phase 1+2 parser regression, Phase 3 geometry reconstruction, DOCX writer structure, converter service regression and converter UI regression.
