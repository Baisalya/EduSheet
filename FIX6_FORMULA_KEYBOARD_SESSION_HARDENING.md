# EduSheet Formula Keyboard Session Fix 6

## Why Fix 5 still had one failing widget test

The remaining failure was not a compile/analyzer error. The formula keyboard session test was still asserting session state indirectly through the text of the `Open math keyboard` button. In addition, the keyboard controller was still an auto-dispose Riverpod notifier, which is not ideal for an app-wide overlay/session coordinator that must survive focus and nested-Navigator transitions.

## Fix 6 changes

1. `MathKeyboardController` is now a keep-alive Riverpod notifier so overlay ownership cannot be reset by a transient listener gap.
2. `FormulaEditorSheet` tracks whether the structured math session is intentionally requested.
3. If a visible math session is accidentally detached while its type is still `KeyboardType.math`, the formula editor recovers ownership on the next frame.
4. Recovery never fights an explicit user choice to switch to the system keyboard because `showSystemKeyboard()` / `hideKeyboard()` switch the type back to `KeyboardType.system`.
5. External Advanced text fields explicitly cancel the structured session before taking focus.
6. Formula-session regression tests now inspect the Riverpod session state directly (`isVisible`, `type`, active controller and focus owner) instead of inferring it from a button label during animated layout/overlay transitions.

## Validation commands

```powershell
dart format lib test
flutter analyze
flutter test test/features/math_keyboard/formula_editor_sheet_test.dart
flutter test test/features/math_keyboard/math_keyboard_modal_presenter_test.dart
flutter test
```
