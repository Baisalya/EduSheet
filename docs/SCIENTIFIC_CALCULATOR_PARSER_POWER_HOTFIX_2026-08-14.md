# Scientific Calculator Parser/Power Hotfix — 2026-08-14

## Trigger

Windows QA remained clean under `flutter analyze`, but `flutter test test/features/calculator` still failed at the `sinh(0)` assertion.

## Root cause

EduSheet already normalizes implicit multiplication in `MathEngine._insertImplicitMultiplication()` before handing the expression to `math_expressions`.

The engine was also constructing `ShuntingYardParser` with `ParserOptions(implicitMultiplication: true)`. In math_expressions 2.7.0, the legacy parser's implicit-multiplication pass inserts `*` after a closing parenthesis unless the following token is in a small exclusion list. `POW (^)` is not excluded. Therefore a valid expression such as `(2.718281828459045)^0` can be transformed internally as though multiplication exists before `^`, causing parse failure.

The hyperbolic rewrite uses Euler's constant and powers, so `sinh(0)` exposed this parser interaction.

## Fix

- Disabled the legacy parser's implicit-multiplication heuristic by constructing `ShuntingYardParser()` with default options.
- Kept EduSheet's explicit `_insertImplicitMultiplication()` normalization as the single source of truth.
- No dependency version changes.
- No PDF/Word/question-paper changes.

## Added regression coverage

- `(2+3)(4+1)` still validates explicit implicit multiplication.
- `(2)^3` validates parenthesized-base powers.
- `π^2` validates constant powers.
- `e^1` validates Euler-constant powers.
- `Ans^2` with a negative previous answer validates negative parenthesized powers.
- Existing `sinh(0)`, `cosh(0)`, `tanh(0)`, positive/negative `sinh` coverage remains.

## User verification

Run:

```powershell
flutter analyze
flutter test test/features/calculator
flutter test
```

Final pass status must be taken from the user's Windows Flutter SDK run.
