# Math Keyboard UX Phase 3 — Hotfix 3

Date: 2026-08-30

## Trigger

The full Flutter test run reached +214 with only two failures remaining. Both end-to-end failures opened the formula sheet successfully but the `math-build-button` was rendered one keyboard height below the 900 px test viewport (center y=973.5). That geometry is the hidden `AnimatedSlide` position of the app-level custom math keyboard, so the tests were finding a real keyboard widget that was not currently visible/hit-testable.

`flutter analyze` was clean in the same user run.

## Root cause addressed

`FormulaEditorSheet.show()` presented the sheet with the modal route's default focus-request behaviour while the formula editor also explicitly owns/request focus for its custom `MathField` session. Those two focus owners can race during modal presentation and detach the just-opened custom math keyboard.

The formula editor already owns its focus lifecycle explicitly through `_openStructuredMathKeyboard()`, so the modal route does not need to request focus.

## Production fix

`FormulaEditorSheet.show()` now passes `requestFocus: false` to `showAdaptiveModalBottomSheet`.

This preserves the formula editor's explicit custom-keyboard focus/session hand-off and avoids the route-level focus request sliding the keyboard back to its hidden position after auto-open.

No model, database, repository, migration, math-expression schema, or generated Riverpod code changed.

## Test hardening

The Create Paper and Question Bank end-to-end tests now inspect `mathKeyboardControllerProvider` after opening the formula sheet and assert:

- `isVisible == true`
- `type == KeyboardType.math`
- active controller is present
- active focus node is present

Only after that contract passes do they tap the Build key. This prevents false interaction with the always-mounted but off-screen keyboard overlay.

The Create Paper test still verifies the complete teacher journey:

1. Open Math from the shared composer.
2. Confirm the custom math session really auto-opened.
3. Open Build.
4. Scroll the local structure browser to Pythagoras.
5. Insert the ready formula.
6. Add it to the question.
7. Verify the Quill document contains a math embed and `a^2 + b^2 = c^2`.

Question Bank still verifies that `AddEditQuestionScreen` uses the same shared teacher Build flow.

## Recommended local validation

```powershell
flutter test test/features/math_keyboard/formula_editor_sheet_test.dart
flutter test test/features/paper_composer/question_composer_typing_viewport_test.dart
flutter test test/features/question_bank/question_bank_paper_composer_widget_test.dart
flutter test
flutter analyze
```

The container used to prepare this hotfix does not include Flutter/Dart, so these commands must be executed in the user's Flutter environment.
