# EduSheet Professional Formatting Phase 4C — Completion Notes

## Scope

Phase 4C completes the planned Free-form Geometry and geometry-embed parity work without reopening the Step 8–10 / Formatting Phase 1–4B architecture.

## Architecture decisions

- `Paper` remains the only paper source of truth.
- Geometry continues to persist as `GeometryDiagram` primitives inside the Quill `geometry` embed.
- `GeometryEmbedLayout` is placement metadata, not a parallel document object.
- Existing Geometry recipes/templates remain supported.
- No DB migration.
- No dependency upgrade.
- No OS-wide floating tool.
- Phase 4B general-purpose Word Shapes remain separate from mathematical Geometry.

## Main user-facing changes

1. Free-form Geometry adds direct Axes and Number-line tools to Point/Line/Arrow/Circle/Angle.
2. Geometry embeds gain persistent width, height, alignment, top/bottom spacing and wrap/anchor intent.
3. Word Mode and Preview consume the same geometry embed renderer/metadata.
4. PDF export renders the canonical diagram as vector SVG instead of `[diagram]`.
5. DOCX export emits vector VML geometry with placement metadata instead of `[diagram]` while retaining the exact Smart Paper JSON envelope.
6. Smart↔Word safe-import protection for Math/Geometry remains unchanged.

## Important compatibility behavior

Legacy geometry embeds that contain only an id or the older id/height/width/alignment JSON remain readable. Missing Phase 4C values receive safe defaults.

For malformed/legacy geometry whose embedded diagram cannot be resolved, export falls back to `[diagram]` rather than failing the complete paper.

## QA

Assistant-side runtime Flutter execution is unavailable, therefore no analyzer/test pass is claimed here. The required user-side gate is:

```powershell
dart format .
.\tool\run_phase4c_gate.ps1
```

Phase 4C should be marked LOCKED only after that automated gate plus Windows/Android manual smoke succeeds.
