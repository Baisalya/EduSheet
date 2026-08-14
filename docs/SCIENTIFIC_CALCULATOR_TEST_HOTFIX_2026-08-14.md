# Scientific Calculator Test Hotfix — 2026-08-14

## Trigger

Windows QA reported a clean `flutter analyze` but two calculator test failures:

- `2π` returned `Error` instead of `6.2831853072`.
- `sin(0)` returned `Error` instead of `0`.

## Root causes

### 1. Unicode pi adjacency

The implicit-multiplication rule depended on a regex word boundary after `π`. That boundary is unsuitable for this use because the parser-facing token rules are ASCII identifier based. The engine now normalizes `π` to `pi` before implicit multiplication and later substitutes the numeric constant.

### 2. Near-zero runtime type mismatch

The parser result was left dynamically typed. When a very small result was normalized, the code assigned integer `0`. The success model requires a `double`, so that dynamic value could fail at runtime. The engine now validates the parser result is numeric, converts it with `toDouble()`, and normalizes near-zero results to `0.0`.

## Regression protection

`math_engine_test.dart` now explicitly verifies the detailed result for `sin(0)`:

- success is true
- numeric value is `0.0`
- display text is `0`

## Re-run

```powershell
flutter analyze
flutter test test/features/calculator
flutter test
```
