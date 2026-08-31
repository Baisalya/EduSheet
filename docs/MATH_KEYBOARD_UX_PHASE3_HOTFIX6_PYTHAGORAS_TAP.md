# Phase 3 Hotfix 6 — Pythagoras card hit-target correction

## Trigger
The Create Paper E2E test could scroll the ready formula label `Pythagoras` into view, but `tester.tap(find.text('Pythagoras'))` warned that the text render object was not hit-testable. The label entered the viewport at the lower edge while the real tappable surface is the surrounding `_StructureChoiceCard` / `InkWell`.

Question Bank's shared Build-flow test already passed in the same run.

## Correction
The Create Paper test now:

1. scrolls the keyed `math-structure-browser` until the `Pythagoras` label is built;
2. performs one additional upward drag so the card is comfortably inside the keyboard's interactive region;
3. resolves the actual Pythagoras template card by its existing canonical key;
4. resolves the surrounding `InkWell` from the label and taps that real hit target;
5. continues the existing E2E assertions: Add formula closes the editor, Quill receives a math embed, and the stored formula contains `a^2 + b^2 = c^2`.

## Scope
Test-only correction. No production `lib/` files, models, repositories, persistence, database schema, or generated files changed.
