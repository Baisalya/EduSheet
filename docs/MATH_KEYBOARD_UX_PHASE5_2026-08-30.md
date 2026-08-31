# Math Keyboard UX Phase 5 — Production Hardening & Final Teacher Gates

Date: 2026-08-30
Baseline: Phase 4 full project, confirmed by the user with `+220: All tests passed!`

## Scope

Phase 5 is a hardening phase, not a new architecture rewrite. It preserves the Phase 1–4 data model, `MathExpression` serialization, shared Create Paper / Question Bank composer architecture, and the existing catalogue/template system.

## Production hardening

### 1. Rebuild-safe math session ownership

`MathKeyboardField.didUpdateWidget()` now preserves an active custom-math session when its parent rebuilds with a replacement `FocusNode`, editor controller, or both.

The controller exposes `transferMathSessionOwner(...)`, which moves ownership in one provider state emission. This avoids publishing a transient hidden/system-keyboard state that could make the custom keyboard animate away or flash the system IME on Windows.

A replacement FocusNode regains editing focus after the rebuilt child is attached, rather than trying to request focus before attachment.

A genuine move to a different normal text field still releases the custom math session.

### 2. 320 px + large-text structure layout

The Build and Ready Formula grids no longer rely on fixed child aspect ratios. Their row extent adapts to the active `TextScaler`, giving structure titles/hints enough vertical room at accessibility text sizes while keeping the browser scrollable.

### 3. Accessible keyboard controls

- The resize handle now exposes a readable semantic label/value plus increase/decrease actions, while drag-to-resize remains available for mouse/touch users.
- The Build entry exposes a semantic button action and teacher-readable description.

## Final regression gates added

- Active math session survives FocusNode replacement.
- Active math session transfers to a replacement editor controller.
- Moving to a genuine external text editor releases the session.
- Controller-level owner transfer keeps the keyboard visible and in math mode.
- Teacher can intentionally switch Math → Text → Math and regain the same formula session.
- 320 px keyboard at 2× text scale can open Build without overflow and renders enlarged structure cards.
- Resize and Build affordances remain accessible to assistive technology.

## Explicit non-goals

- No DB/schema change.
- No `MathExpression` serialization change.
- No Question Bank repository/model change.
- No generated Riverpod modification.
- No new package/dependency.
- No undocumented `math_keyboard` package API usage.

## Local validation

```powershell
dart format lib test
flutter test test/features/math_keyboard/math_keyboard_controller_build_test.dart
flutter test test/features/math_keyboard/math_keyboard_field_session_hardening_test.dart
flutter test test/features/math_keyboard/math_keyboard_extreme_layout_test.dart
flutter test test/features/math_keyboard/formula_editor_sheet_test.dart
flutter test
flutter analyze --no-pub
```
