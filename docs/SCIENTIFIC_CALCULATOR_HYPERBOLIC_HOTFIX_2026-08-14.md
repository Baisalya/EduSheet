# EduSheet Scientific Calculator Hyperbolic Hotfix — 2026-08-14

## Trigger

Windows Flutter QA reported one remaining calculator test failure after the first engine hotfix:

- `MathEngine evaluation supports scientific and logarithmic functions`
- failing assertion: `expect(engine.evaluate('sinh(0)'), '0')`
- actual result: `Error`

`flutter analyze` remained clean.

## Root cause

The calculator rewrote `sinh(x)` and `cosh(x)` into exponential identities containing a unary-minus exponent:

- `sinh(x) = (e^x - e^(-x)) / 2`
- `cosh(x) = (e^x + e^(-x)) / 2`

EduSheet intentionally retains `math_expressions` 2.7.0 and its legacy `ShuntingYardParser` for compatibility. That parser has special precedence/token handling around unary minus and powers. The generated `e^(-(x))` form therefore exercised a fragile parser path.

## Fix

The same exact mathematical identities are now serialized without a unary-minus exponent:

- `-x` is represented as `(0 - x)` inside the generated exponent.
- `sinh(x)` becomes `(e^x - e^(0-x)) / 2`.
- `cosh(x)` becomes `(e^x + e^(0-x)) / 2`.

This changes only the parser-facing intermediate representation; it does not change the mathematical operation or public calculator syntax.

## Regression coverage added

The scientific-function test now covers:

- `sinh(0) == 0`
- `cosh(0) == 1`
- `tanh(0) == 0`
- positive `sinh(1)` completes successfully
- negative `sinh(-1)` completes successfully

## Scope

Changed files:

- `lib/features/calculator/domain/services/math_engine.dart`
- `test/features/calculator/math_engine_test.dart`
- this QA report

No PDF, Word, question-paper, database, dependency, or unrelated UI code was changed.

## Required Windows verification

Run:

```powershell
flutter analyze
flutter test test/features/calculator
flutter test
```

The source patch was prepared in an environment without a Flutter SDK, so final pass/fail certification remains dependent on these Windows commands.
