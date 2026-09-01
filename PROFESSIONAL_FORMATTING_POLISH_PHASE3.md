# Professional Formatting Polish — Phase 3

Baseline: Professional Formatting Phase 2 QA Fix 1, user-verified on Windows
with analyzer clean, focused formatting/export/release gates green, and full
regression `+321`.

## Goal

Make Create Paper templates more professional and make Word Mode a practical
WYSIWYG authoring surface without splitting the canonical `Paper` model or
turning long exam papers into unsafe absolute-position documents.

## Completed

### Shared WYSIWYG page geometry

- Added `PaperPageCanvasMetrics` as the shared page geometry contract used by
  Preview and Word Mode.
- Both surfaces now resolve the same page size, orientation, margins, page
  width scaling, and minimum paper height.
- Word Mode receives the resolved `PaperTemplate`, not only a page-size enum.

### Shared header renderer

- Added `PaperHeaderLayoutCanvas`.
- Preview and Word Mode now render the same canonical header geometry from
  `PaperHeaderLayoutFactory` / `CustomLayout`.
- Word Mode swaps editable nodes into the shared canvas for school name, paper
  title, and editable metadata fields; the layout geometry itself remains the
  same as Preview.

### Professional built-in headers

Built-in layouts were refined around real academic hierarchies instead of
brand-specific decoration:

- Centered formal
- Identity/logo left
- Identity/logo right
- Modern compact/coaching
- Minimal
- Academic/university
- Structured formal
- Board classic

Curated metadata ordering now supports common fields such as Subject, Class,
Time, Date, Batch, Set, Semester, Course Code, Paper Code and Roll No while
still preserving teacher-added custom header fields.

### Header Arrange — safe free placement

Word Mode now exposes `Arrange header`.

The header designer supports:

- drag positioning
- 6-point snap grid on/off
- X/Y controls
- width and supported height controls
- left/center/right alignment
- font size and bold controls
- add text
- add horizontal line
- add logo slot
- canvas height
- reset
- save/apply as a custom header template

Built-in styles are never overwritten: arranging a built-in header creates and
applies a custom template. Editing an existing custom header updates that
custom template.

The body intentionally remains flow-based. This preserves long-paper
pagination, Smart Mode semantics, Question Bank insertion, Math/Geometry
content, and safe PDF/DOCX export.

### Preview / Word body parity

- Word Mode now mirrors template border, question font size, line spacing and
  page margins from the same page geometry used by Preview.
- Two-column templates render two-column question flow in both Preview and
  Word Mode when no manual page-break block requires safe single-column flow.
- Existing Phase-1/2 section formatting remains canonical in both surfaces.

### Export alignment

- PDF header rendering continues to use exact canonical `CustomLayout` x/y
  geometry.
- DOCX and PDF now share the same header metadata-field resolver, preventing
  template field order from drifting between exporters.
- DOCX remains a flow-oriented Word format; absolute header x/y geometry is
  not falsely represented as pixel-identical Word drawing objects.

## Safety / compatibility

- no DB/schema migration
- no dependency upgrades
- no second Word document model
- no change to question/marks calculation
- no change to Step-10 safe DOCX round-trip contract
- no unsafe absolute positioning for questions
