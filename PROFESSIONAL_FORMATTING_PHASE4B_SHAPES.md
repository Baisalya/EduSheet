# Professional Formatting Phase 4B — Shapes, Placement, Wrapping & Layers

Status: **IMPLEMENTATION COMPLETE — awaiting Windows runtime QA before lock**

Baseline: Professional Formatting Phase 4A QA Fix 2 (Windows QA green, full suite +337).

## Scope completed

- General **Shapes** tool remains separate from Math and Geometry.
- Shape kinds: Rectangle, Rounded Rectangle, Ellipse, Line, Arrow, Double Arrow, Text Box and Callout.
- Canonical metadata-backed `WordShapeObject` ownership inside the owning `Question.metadata` under `edusheet.wordShapes`.
- Shapes can belong to an assessment question or to a non-assessment free Word block.
- Normalized `x / y / width / height`, rotation-ready metadata, wrap mode and `zIndex` survive `Paper.toJson()` / `Paper.fromJson()`.
- Word Mode ribbon inserts a shape into the active assessment question, otherwise creates a free non-assessment shape block.
- Direct Word Mode arrangement surface supports drag, resize, wrap selection, Bring Forward, Send Backward and Delete.
- Text Box and Callout now have direct editable text via the selected-object toolbar.
- Word page view now previews the selected wrap intent around the live question editor.
- Preview uses the same Flutter shape-flow renderer as Word Mode.
- Wrap behavior implemented for Inline, Square Left, Square Right, Top & Bottom, Behind Text and In Front of Text.
- Layer order is deterministic and one-step Bring Forward / Send Backward mutations are canonical.
- PDF renderer consumes the same shape metadata and renders flow, square and overlay modes without flattening the Paper model.
- DOCX export writes editable VML drawing objects with shape text, square/top-bottom wrapping intent, absolute behind/in-front placement and z-index layer metadata.
- Existing Smart ↔ Word canonical Paper architecture is unchanged; no DB migration and no Geometry schema mutation.

## QA coverage added

- `test/features/paper_composer/word_shapes_phase4b_test.dart`
- `test/features/paper_composer/word_shape_preview_phase4b_test.dart`
- `test/release/professional_formatting_phase4b_gate_test.dart`
- Phase 4B PDF/DOCX parity cases in `test/features/pdf/office_export_services_test.dart`
- `tool/run_phase4b_gate.ps1`

## Lock rule

Phase 4B can be marked **LOCKED** only after the user's Windows environment reports:

1. `dart format .` clean
2. `flutter analyze` clean
3. Phase 4B focused tests pass
4. Office export tests pass
5. `flutter test test/release` passes
6. full `flutter test` passes
7. manual Windows + Android smoke confirms drag/resize/wrap/layers/Text Box/Callout and Preview/PDF/DOCX behavior.

## Architecture rule

`Paper` remains the single source of truth. Phase 4B does not introduce a second Word document model, a database migration, or generic-shape behavior into Geometry.
