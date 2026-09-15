# Math Keyboard Phase 11 — Accessibility + Keyboard Productivity

Phase 11 makes the Phase 1–10 math system usable without touch or a mouse and
strengthens the semantics exposed to screen readers. It does not change saved
question data, math syntax, the database, PDF/Word formats, or dependencies.

## Hardware-key productivity contract

`MathKeyboardProductivityShortcuts` is the single source of truth for the
hardware-key actions shown in the in-product shortcut reference and resolved by
the keyboard wrapper:

- `Ctrl+Shift+M` — toggle the custom math keyboard for the active field.
- `Ctrl+K` — open math symbol/formula search.
- `Ctrl+/` — open the keyboard-shortcut reference.
- `Ctrl+Shift+1` — insert a fraction structure.
- `Ctrl+Shift+2` — insert a square-root structure.
- `Ctrl+Shift+3` — insert a power box.
- `Ctrl+Shift+4` — insert a subscript box.
- `Esc` — return to the normal text keyboard.
- `Tab` — move to the next structured formula slot.
- `Shift+Tab` — move to the previous structured formula slot.

Productivity commands are executed centrally by `MathKeyboardController`. An
active `MathKeyboardField` gets first chance to resolve modifier shortcuts before
ordinary hardware characters are inserted, while `MathKeyboardWrapper` remains
an ancestor fallback for math-capable surfaces that do not use that field
wrapper. The focused editor therefore keeps ownership while commands act on its
existing cursor. Tab/Shift+Tab use the same command path for structured slot
navigation before normal focus traversal can take over.

Alt/AltGr and mixed Meta combinations fail closed and are not stolen from
normal text input.

## Reverse structured-slot navigation

Phase 11 adds a reverse adapter boundary (`moveToPreviousSlot`) rather than
mapping Shift+Tab to a blind focus change.

`MathFieldEditorAdapter` includes semantic reverse handling for:

- normal structured formula nodes;
- runtime dynamic structures such as matrices, cases and systems;
- seeded derivative numerator/denominator slots;
- adjacent lower/upper script structures.

If an editor does not support structured reverse navigation, the controller
falls back to `FocusScope.previousFocus()`.

## Screen-reader semantics

The keyboard now exposes:

- selected-state semantics on primary category pills with stable spoken labels
  that do not change when compact visual labels switch between `123` and
  `Common`;
- a live, non-visual keyboard status region;
- spoken status for keyboard mode changes, structure/symbol insertion,
  deletion and next/previous-slot movement;
- a live result-count announcement in math search;
- explicit search-result insertion labels and favourite status;
- a screen-reader-labelled shortcut reference.

The existing formula accessibility text and safe-fallback semantics remain the
source of truth for spoken mathematical content.

## Reduced motion

`mathKeyboardMotionDuration` centralizes motion suppression. When the platform
reports `MediaQuery.disableAnimations == true`:

- keyboard slide duration becomes zero;
- local-panel switch duration becomes zero;
- Formula Editor math-inset animation becomes zero;
- math-key press/release and preview-bubble animation durations become zero.

Functionality, focus ownership and input timing do not depend on animation
completion.

## Regression gates

Phase 11 adds:

- `math_keyboard_productivity_shortcuts_test.dart`
  - unique discoverable shortcut labels;
  - deterministic key/modifier resolution;
  - fail-closed Alt/Meta behavior.
- `math_keyboard_accessibility_productivity_test.dart`
  - shortcut-reference semantics;
  - selected category semantics;
  - live status semantics;
  - reduced-motion overlay behavior;
  - end-to-end keyboard-only fraction insertion and math search.
- `math_keyboard_reverse_slot_navigation_test.dart`
  - denominator → numerator reverse navigation;
  - combined subscript/superscript reverse navigation.

Existing accessibility, 2× text-scale, windowed-input, focus-session and
responsive math-keyboard tests remain part of the release gate.

## Compatibility guarantees

Phase 11 adds no database migration, no persistence schema change, no package
upgrade and no new dependency. Phase 9 safe validation and Phase 10 production
budgets remain unchanged.
