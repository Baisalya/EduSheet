# Professional Formatting Phase 4C — Free-form Geometry + final anchoring/export parity

Status: **IMPLEMENTATION COMPLETE — Windows Flutter QA required before LOCK**

Baseline: Phase 4B QA Fix 1, automated gate +346 green. Phase 4C does not fork the paper model, geometry JSON schema, database, or dependency graph.

## Completed

### Direct free-form Geometry Studio

- Dedicated direct-draw toolbar: Select, Point, Line, Arrow, Circle, Angle, Axes and Number line.
- Free-form tools are transient editor state only; persisted output reuses canonical `GeometryDiagram`, `GeometryPoint`, `GeometryShape`, `GeometryLabel` and `GeometryMark`.
- Point: tap to add editable A/B/C… points.
- Line / Arrow: drag endpoint-to-endpoint.
- Circle: drag from center to radius edge.
- Angle: tap vertex, first ray, second ray; creates two editable lines plus an angle-arc mark.
- Axes: drag from origin outward to size x/y coordinate axes.
- Number line: drag from one end to the other; canonical number-line ticks remain renderer/export concerns.
- Existing grid/snap settings apply to direct drawing.
- Drag tools show a live draft; staged angles show pending construction.
- Esc cancels a draft/tool before clearing selection/closing Geometry Studio.
- Template/recipe figures and free-form primitives can coexist in one canonical diagram.

### Canonical geometry embed placement

Added `GeometryEmbedLayout` as metadata inside the existing Quill `geometry` embed. No second paper/document model is introduced.

Persisted placement now includes:

- height
- relative width
- left/center/right alignment
- top and bottom spacing
- anchor/wrap intent: Inline block / Square left / Square right / Top & bottom
- exact embedded `GeometryDiagram` JSON for offline persistence and Smart↔Word safety

Legacy geometry embed payloads without the Phase 4C fields continue to resolve with compatible defaults.

### Word Mode + Preview

`GeometryEmbedBuilder` is still the single shared Flutter renderer used by editable Word Mode and read-only question Preview. The same canonical placement metadata therefore drives both surfaces.

Selected diagrams now expose:

- Edit
- left / center / right alignment
- half / three-quarter / full width
- wrap/anchor intent
- compact / normal / spacious vertical spacing
- drag-to-position
- corner resize
- remove

EduSheet intentionally keeps geometry as a safe block embed inside Quill. Square-left/right express anchor intent and side alignment without converting assessment questions into absolute-positioned page objects.

### PDF parity

PDF rich-text export now detects canonical geometry embeds instead of replacing them with `[diagram]`.

- The embedded diagram JSON is rendered as vector SVG through the existing `pdf` package SVG widget.
- width, height, alignment and vertical spacing are consumed from `GeometryEmbedLayout`.
- free-form Line/Arrow/Circle/Angle/Axes/Number-line primitives and point/label text are emitted by the upgraded deterministic `GeometrySvgService`.
- legacy id-only embeds safely fall back to `[diagram]` rather than breaking the rest of the paper.

### DOCX parity

Word export no longer prints `[diagram]` for canonical Phase 4C embeds.

- geometry is emitted as vector VML inside `word/document.xml`
- width, height, left/center/right alignment, square-left/right/top-bottom placement intent and spacing metadata are preserved
- arrows/axes/number lines/circles/polygons/free-form labels are represented as Word vector drawing content
- exact canonical geometry remains inside the EduSheet Smart Paper custom XML round-trip envelope, so Word interoperability never becomes the source of truth
- Word edits that would threaten Math/Geometry embed positions remain protected by the existing safe-import rules

### QA coverage added

- `test/features/geometry_builder/geometry_freeform_phase4c_test.dart`
- `test/features/geometry_builder/geometry_embed_layout_phase4c_test.dart`
- Phase 4C PDF/DOCX assertions in `test/features/pdf/office_export_services_test.dart`
- `test/release/professional_formatting_phase4c_gate_test.dart`
- `tool/run_phase4c_gate.ps1`

## Lock criteria

Run on the user's Windows Flutter environment:

```powershell
dart format .
.\tool\run_phase4c_gate.ps1
```

Then manually verify on resized Windows and narrow Android:

- Point / Line / Arrow / Circle / Angle / Axes / Number line
- grid + snap
- select/edit/undo/redo/delete
- geometry width/alignment/spacing/wrap controls
- Smart → Word → Smart preservation
- Preview parity
- exported PDF contains the actual diagram, not `[diagram]`
- exported DOCX displays vector geometry and retains the canonical Smart Paper round-trip

## Runtime claim

The assistant environment does not provide Dart/Flutter/PowerShell runtime validation. Implementation and static package checks can be performed here, but Phase 4C is not LOCKED until the user-side gate and manual smoke pass.
