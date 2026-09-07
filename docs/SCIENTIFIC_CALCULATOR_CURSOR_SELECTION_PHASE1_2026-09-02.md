# Scientific Calculator Cursor & Selection Foundation — Phase 1

Date: 2026-09-02

## Scope

This phase is intentionally limited to calculator editing state and domain/controller behavior. It does not yet replace the rendered `Math.tex` display with an interactive caret surface and does not yet redesign responsive layout. Those remain Phase 2 and Phase 4 work.

## Architectural change

The calculator no longer treats the expression as an append-only string at controller level.

A dedicated domain editing model now owns:

- expression text
- selection base offset
- selection extent offset
- collapsed caret state
- normalized/clamped offsets

`CalculatorState.equation` remains available as a compatibility getter so existing rendering, engine, history, and tests do not need a disruptive one-shot rewrite.

## Cursor-aware input editor

`CalculatorInputEditor` now supports:

- insertion at the current caret
- replacement of selected expression text
- token-aware backward deletion
- token-aware forward deletion
- selection deletion
- caret movement left/right
- move to expression start/end
- extending a selection while moving
- token-aware jumps across known multi-character calculator tokens
- decimal validation around the caret rather than only at expression end
- sign toggling for the operand at the caret
- adjacent operator normalization at the caret
- post-result `Ans` continuation without losing the editing model

Legacy append-only helpers remain as compatibility wrappers and delegate to the new editing implementation.

## Controller foundation

`CalculatorController` now exposes editing operations required by the later interactive UI phase:

- `setSelection(...)`
- `selectAll()`
- `moveCursorLeft(...)`
- `moveCursorRight(...)`
- `moveCursorToStart(...)`
- `moveCursorToEnd(...)`
- `deleteBackward()`
- `deleteForward()`

The existing `delete()` API is retained as a backward-delete compatibility alias for the current keypad.

Loading a saved history expression places the caret at the end. The in-progress history draft now preserves its full editing value, including caret/selection, so returning from history does not lose the user's editing position. Moving the caret after a completed calculation exits `justEvaluated` mode so the previous expression can be edited instead of forcing `Ans` continuation.

## Input correctness fix included

The previous editor reset the literal expression `0` before every next token. That meant entering `0` followed by `+` could erase the zero/operator sequence. The new editor keeps `0` for operators and decimal input while still replacing a leading zero when another digit is entered.

## Tests added/expanded

Phase 1 tests cover:

- editing-value normalization
- reversed selections
- insertion in the middle of an expression
- selected-range replacement
- backward selection deletion
- token-aware backward deletion
- token-aware forward deletion
- decimal insertion/duplicate guarding at caret
- operator replacement at caret
- zero/operator regression
- sign toggle at caret
- atomic movement across known calculator tokens
- selection extension/collapse
- controller caret tracking
- controller selection replacement
- controller backward/forward delete
- controller cursor navigation
- editing a prior expression after `=`
- history entry caret placement
- history draft text + selection restoration

## Deliberately deferred

The following are not part of Phase 1:

- visible blinking caret in the calculator display
- tap/mouse hit-testing to place the caret
- drag selection UI
- keyboard Left/Right/Home/End/Delete routing
- responsive/free-form layout redesign
- formula-variable workflow redesign
- math-engine/parser hardening

Those belong to the subsequent phases so the change remains testable and reversible.

## Validation status

This packaging environment does not contain Flutter or Dart executables, so `dart format`, `flutter analyze`, and `flutter test` cannot be truthfully reported as executed here.

Required validation on the normal EduSheet Flutter machine:

```powershell
flutter pub get
dart format lib/features/calculator test/features/calculator
flutter analyze
flutter test test/features/calculator
flutter test
```

Phase 2 should begin only after the Phase 1 calculator tests pass on the Flutter development machine.
