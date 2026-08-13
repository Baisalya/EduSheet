# Formula Composer — Real-world Teacher UX / QA

## Goal

A teacher should never need LaTeX knowledge for normal question creation. The
primary path is now:

`Question -> Math -> visual formula -> Save formula`

Editing is:

`Tap existing formula -> visual formula + math keyboard -> Save formula`

Geometry remains a separate authoring tool.

## UX decisions implemented

- One **Math** action replaces the competing **Math keyboard** and **Formula block** choices.
- New and existing formulas use the same visual `MathField` workflow.
- The math keyboard opens automatically when the visual formula editor opens.
- Existing TeX is loaded back into the visual field through the public
  `TeXParser` + `MathFieldEditingController.updateValue` path when supported.
- If an older/advanced formula cannot be loaded into the visual editor, its
  source and rendered fallback remain available; nothing is discarded.
- LaTeX source is under **Advanced**, not the default editor.
- Accessibility text is generated automatically. Teachers can override it under
  **Advanced**, but it is no longer a mandatory form field.
- Formula cards are clickable across the full row; the pencil-sized target is
  no longer required to edit.
- `Display` is presented as the teacher-friendly **New line** choice.
- Formula editor header adapts for narrow phone/free-form widths.
- The primary save action stays above the custom math keyboard.

## Real-world scenarios covered

1. New formula in a new question.
2. New formula in an existing question.
3. Edit an existing formula by tapping the formula card.
4. Fraction/root/power/subscript/integral/sum entry through the structured field.
5. Windows physical-keyboard input while the math field owns focus.
6. Reopen the math keyboard after hiding it.
7. Switch to Advanced source editing without losing the last valid visual tree.
8. Invalid source: block save and preserve the last valid formula.
9. Advanced/legacy source not supported by the visual parser: keep source and
   rendered fallback available instead of crashing or clearing the expression.
10. Cancel: close keyboard and return without changing the question draft.
11. Save: preserve expression ID/metadata when editing an existing formula.
12. Accessibility description omitted: generate a deterministic fallback.
13. Teacher-written accessibility description: preserve it unless they choose
    **Use automatic description**.
14. Small phone/free-form window: responsive header + scrollable content.
15. Math keyboard overlay: save/cancel remain above it.
16. Multiple formulas in one question: each card remains independently editable.
17. Inline vs new-line formula display remains persisted through the existing
    `MathExpressionDisplay` contract.
18. Existing saved papers remain compatible; no schema or dependency changed.

## Regression tests added/updated

- `test/features/editor/create_paper_save_sheet_test.dart`
  - one Math action
  - opens structured `MathField`
  - no mandatory readable-description form
- `test/features/math_keyboard/formula_editor_sheet_test.dart`
  - existing formulas open visually before advanced source
  - advanced source/accessibility controls remain available
- `test/features/math_keyboard/math_accessible_text_service_test.dart`
  - known formula fallbacks
  - nested root/power description
  - empty input behavior

## Manual QA still required on the developer machine

Run:

```powershell
flutter analyze
flutter test
flutter test integration_test/question_creation_journey_test.dart -d windows
flutter run -d windows
```

Then manually verify at 320/360/430 px emulated widths and normal Windows size:

- add formula, edit it, hide/reopen keyboard, switch Advanced on/off,
- cancel and verify no mutation,
- save and reopen the same formula,
- create multiple formulas,
- test long formulas while keyboard is visible,
- test an older formula that cannot be converted back into the visual parser.
