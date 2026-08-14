# Template/Header Refactor QA Fix — 2026-08-14

This repair is based on the professional Template/Header refactor and addresses the user's local analyzer/test output.

## Repairs

- Keeps the refactored `PaperTemplate` architecture; no rollback to `effectiveLayout` on the domain model.
- Explicitly removes obsolete pre-refactor template widgets that still reference `template.effectiveLayout` when old files remain in a working tree.
- Carries forward the Geometry hit-test hierarchy where an exact vertex selects the point and the visible right-angle corner selects the mark.
- Carries forward the updated Geometry regression test for that interaction.
- Carries forward the Geometry painter brace cleanup.
- Adds braces around the Paper Setup logo branch.
- Simplifies the marks string interpolation.
- Uses Dart's null-aware map-value element for optional header text color.

## Compatibility

No persistence schema, enum ordering, dependency, or template JSON contract is changed by this QA repair.
