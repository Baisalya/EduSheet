# Math Keyboard UX Phase 3 — Test Hotfix 2 (2026-08-30)

## Scope

This hotfix changes test harness code only. Production math keyboard, formula editor,
question composer, repositories, models, persistence, and generated files are unchanged.

## Failures addressed

1. `question_composer_typing_viewport_test.dart` failed to compile because a non-const
   `MaterialApp.builder` closure was nested under `const ProviderScope` / const construction.
2. `question_bank_paper_composer_widget_test.dart` had the same const-expression error.
3. `formula_editor_sheet_test.dart` timed out in `pumpAndSettle()` after returning from
   the local Key actions panel. The keyboard can keep scheduled frames alive, so the test
   now advances the known 160 ms `AnimatedSwitcher` with a bounded 200 ms pump.

## Why this is safe

- No production behavior was modified.
- The two end-to-end harnesses still use `MaterialApp.builder` so `MathKeyboardWrapper`
  matches the production app integration point.
- The Key actions regression still asserts the local panel disappears and the active math
  session remains visible after returning to keys.
- The bounded pump is intentionally longer than the 160 ms local-panel transition.

## Targeted verification

```powershell
flutter test test/features/math_keyboard/formula_editor_sheet_test.dart
flutter test test/features/paper_composer/question_composer_typing_viewport_test.dart
flutter test test/features/question_bank/question_bank_paper_composer_widget_test.dart
flutter test
flutter analyze
```

PDF font-download / Helvetica fallback messages are unrelated network/font fallback warnings
and are not addressed by this test-only hotfix.
