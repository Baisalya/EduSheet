# Professional Formatting Polish — Phase 2

This phase builds on the Phase 1 alignment/divider/instruction controls and keeps the existing `Paper` / `PaperSection` model as the canonical source of truth.

## Added teacher controls

- Section heading presets: Plain, Underline, Ruled, Boxed.
- Independent top/bottom rules remain available after applying a preset.
- Section heading typography: bold toggle, uppercase display, Small / Normal / Large size.
- Section marks: Hidden, inline after heading, or right edge.
- Section spacing: Compact / Normal / Spacious.
- Keep section heading with the first suitable question.
- Question marks placement: inline or right edge.

## Output parity

The new settings are consumed by Create Paper preview, Word Mode, PDF export and DOCX export. DOCX right-edge marks use a real right tab stop and section keep-with-first-question uses `w:keepNext` chains. PDF uses an unbreakable heading + first-question unit only when the first question is small/safe enough; complex first questions fall back to normal pagination instead of risking an oversized unbreakable PDF widget.

## Compatibility

Old papers default to the previous visual behavior:

- Bold normal-size section heading.
- No uppercase or box.
- Normal section spacing.
- Section marks hidden.
- Question marks at the right edge.
- Existing `keepTogether` default remains enabled.

No database migration, dependency change, or second document model was introduced.
