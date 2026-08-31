# Math Keyboard UX Phase 5 — Hotfix 1

Date: 2026-08-30
Baseline: `EduSheet_Math_UX_Phase5_Full_2026-08-30.zip`

## Why this hotfix exists

The Phase 5 targeted test run exposed four related hardening defects:

1. `math_keyboard_controller_build_test.dart` used platform text-input channels without initializing a Flutter test binding.
2. `MathKeyboardField.didUpdateWidget()` synchronously transferred/unregistered/registered Riverpod state while the widget tree was building. Riverpod correctly rejects provider mutation from lifecycle methods.
3. The resize handle exposed accessibility increase/decrease actions with a current `value`, but omitted the required `increasedValue` / `decreasedValue` semantics values.
4. The extreme-layout test called a `SemanticsNode.hasAction` API that is not available in the installed Flutter SDK.

The provider and semantics failures cascaded into multiple scheduler/render/MathField teardown errors in `formula_editor_sheet_test.dart`; those are treated as secondary effects of the two production defects rather than separate feature regressions.

## Production fixes

### Post-frame editor-owner synchronization

`MathKeyboardField.didUpdateWidget()` now only updates local widget/focus bookkeeping synchronously. Any Riverpod keyboard-session mutation is deferred until the rebuilt editor is attached in a post-frame callback.

The handoff re-checks the current keyboard owner before transferring, so a stale rebuild callback cannot steal a newer math session.

The visible math keyboard remains visible during a legitimate FocusNode/controller replacement; no temporary hidden/system-keyboard state is published.

### Safe reveal during teardown

`_ensureVisibleAboveKeyboard()` now verifies the render object is still attached and treats `Scrollable.ensureVisible` as best-effort. Route teardown/re-parenting can detach a ScrollPosition between frames; that must never break formula input.

### Complete resize accessibility semantics

The resize handle now supplies:

- current value
- increased value
- decreased value
- increase action
- decrease action

The announced values follow the existing 240–520 px keyboard-height clamp.

## Test fixes

- Initialize `TestWidgetsFlutterBinding` in the controller build test before platform-channel use.
- Validate resize actions with Flutter's supported `isSemantics(...)` matcher instead of `SemanticsNode.hasAction`.

## Scope

Production files changed:

- `lib/features/math_keyboard/presentation/widgets/math_keyboard_field.dart`
- `lib/features/math_keyboard/presentation/widgets/math_keyboard_view.dart`

Test files changed:

- `test/features/math_keyboard/math_keyboard_controller_build_test.dart`
- `test/features/math_keyboard/math_keyboard_extreme_layout_test.dart`

No database, repository, MathExpression schema, Question Bank persistence, migration, or generated Riverpod file was changed.

## Local validation

Run:

```powershell
dart format lib test
flutter test test/features/math_keyboard/math_keyboard_controller_build_test.dart
flutter test test/features/math_keyboard/math_keyboard_field_session_hardening_test.dart
flutter test test/features/math_keyboard/math_keyboard_extreme_layout_test.dart
flutter test test/features/math_keyboard/formula_editor_sheet_test.dart
flutter test
flutter analyze --no-pub
```
