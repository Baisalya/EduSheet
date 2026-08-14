# EduSheet Scientific Calculator — Live Preview Refactor

Date: 2026-08-14

## Scope

This increment adds a debounced, side-effect-free live calculation preview to the existing Android/Windows scientific calculator. It also moves the calculator engine from the maintenance-mode `ShuntingYardParser` to `GrammarParser`, which is already included in the project's existing `math_expressions 2.7.0` dependency.

## Live preview behavior

- Evaluates while the user types, after a 100 ms debounce.
- Renders a faded `≈ result` line in the calculator display.
- Works with touch input, Windows keyboard input, and numpad input because all input continues to flow through `CalculatorController`.
- Re-evaluates immediately after DEG/RAD changes.
- Allows useful auto-closed scientific previews such as `sin(30` in DEG mode.
- Suppresses preview for clearly incomplete input such as `25×`, `sin(`, `2EXP-`, or partial nCr/nPr tokens.
- Suppresses preview for invalid/domain-error expressions rather than flashing `Error` while the user is typing.

## Safety / state isolation

Live preview does **not** mutate:

- `result` (the committed result),
- `lastAnswer` / `Ans`,
- calculation history,
- `justEvaluated`.

Only an explicit `calculate()` / `=` commits the result, updates `Ans`, and appends history.

Pending preview timers are cancelled when appropriate and on controller disposal. A stale-preview guard verifies that expression, angle mode, and `Ans` still match the request that scheduled evaluation.

## Parser hardening

The project already performs explicit implicit-multiplication normalization before parsing. `MathEngine` now uses `GrammarParser`, available in the existing `math_expressions 2.7.0` dependency, rather than the legacy maintenance-mode shunting-yard parser. No dependency or package version was changed.

This is intended to remove the remaining parser edge affecting the hyperbolic regression (`sinh(0)`) while preserving existing arithmetic, powers, roots, logs, trig, factorial, combinatorics, constants, and implicit multiplication behavior.

## Tests added/extended

- Engine preview success.
- Incomplete input produces no preview.
- Invalid/domain input produces no preview.
- Auto-closed DEG scientific preview (`sin(30` → `0.5`).
- Controller preview does not commit `Ans` or history.
- `=` clears preview and commits exactly once.
- Widget displays faded live preview before `=`.
- Windows keyboard route exercises preview then commit.
- Existing parser/math regression suite remains in place, including hyperbolic tests.

## Modified files in this increment

- `lib/features/calculator/domain/services/math_engine.dart`
- `lib/features/calculator/presentation/providers/calculator_provider.dart`
- `lib/features/calculator/presentation/widgets/calculator_display.dart`
- `lib/features/calculator/presentation/widgets/scientific_calculator.dart`
- `test/features/calculator/math_engine_test.dart`
- `test/features/calculator/calculator_controller_test.dart`
- `test/features/calculator/calculator_widget_test.dart`
- `docs/SCIENTIFIC_CALCULATOR_LIVE_PREVIEW_REFACTOR_2026-08-14.md`

## Required Windows verification

The packaging environment does not include Flutter/Dart, so runtime verification must be performed in the user's Windows project:

```powershell
flutter analyze
flutter test test/features/calculator
flutter test
flutter run -d windows
```

Acceptance criteria:

1. `flutter analyze` reports no issues.
2. All calculator tests pass, including `sinh(0)`.
3. Typing `25×18+100` shows faded `≈ 550` before `=`.
4. Before `=`, `Ans` and history remain unchanged.
5. Pressing `=` commits `550`, updates `Ans`, adds one history entry, and hides the preview.
6. `sin(30` in DEG mode previews `≈ 0.5`.
7. `25×` and `sin(` show no preview and no transient error.
8. Compact Android, desktop Windows, and small/free-form layouts have no overflow.
