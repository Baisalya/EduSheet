# EduSheet — Professional Formatting Phase 4B completion notes

## What changed

Phase 4B adds Word-like general drawing objects while preserving the canonical Smart Paper model.

Teacher-facing behavior:
- Shapes is a dedicated Word Mode insert tool, separate from Geometry.
- Insert into the currently active assessment question, or as free Word content when no assessment question is active.
- Drag and resize in the arrangement canvas.
- Choose Inline, Square Left, Square Right, Top & Bottom, Behind Text or In Front of Text.
- Bring Forward / Send Backward operate one layer at a time.
- Text Box and Callout content is editable after insertion.
- Word Mode and Preview share the same Flutter flow renderer.
- PDF consumes the same metadata.
- DOCX emits editable VML drawing objects with wrap/layer metadata rather than flattening shapes into screenshots.

## Safety / compatibility

- No database migration.
- No new dependency.
- No Geometry schema change.
- Smart Mode question semantics, numbering, marks and OMR continue to ignore free Word shape blocks.
- Shape state is persisted through existing `Question.metadata`, so canonical Paper round-trip and Step 10 DOCX envelope remain intact.

## Recommended Windows QA

```powershell
dart format .
.\tool\run_phase4b_gate.ps1
```

If you want to run the checks individually:

```powershell
flutter analyze
flutter test test/features/paper_composer/word_shapes_phase4b_test.dart
flutter test test/features/paper_composer/word_shape_preview_phase4b_test.dart
flutter test test/features/paper_composer/word_direct_authoring_phase4a_test.dart
flutter test test/features/paper_composer/dual_editor_mode_test.dart
flutter test test/features/pdf/office_export_services_test.dart
flutter test test/release/professional_formatting_phase4b_gate_test.dart
flutter test test/release
flutter test
```

## Runtime claim

The assistant environment used for this completion does not contain Flutter/Dart/PowerShell, so no runtime analyzer/test/build pass is claimed here. Static/package verification is performed before delivery; Phase 4B is only locked after the user's Windows QA is green.
