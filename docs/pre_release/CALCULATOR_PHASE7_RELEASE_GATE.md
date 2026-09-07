# Calculator Phase 7 — Full QA and Release Gate

## Purpose

Phase 7 does not add calculator features. It locks the Phase 1–6 behavior behind repeatable automated and manual release gates for Android and Windows.

## Automated gate

From the project root on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_calculator_release_gate.ps1
```

For a store-release candidate, run the stronger gate:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_calculator_release_gate.ps1 -FullRegression -BuildWindows -BuildAndroid
```

The gate checks:

1. Calculator formatting drift.
2. Whole-project static analysis.
3. Cross-phase release-contract tests.
4. The complete calculator test directory.
5. Optional whole-app regression tests.
6. Optional Windows/Android production builds and non-empty artifact hashes.
7. A manual real-device/free-form-window smoke checklist.

## Cross-phase automated contracts

The dedicated release tests cover these boundaries together rather than only in isolated unit tests:

- editable expression → live preview → equals → Ans continuation → history;
- formula metadata → variable validation → resolved numeric expression → calculator insertion → calculation;
- every catalog formula resolves to a finite expression that MathEngine can replay;
- scientific precision, factorial/combinatorics, DEG trig and classified errors;
- formula insertion replaces the current calculator selection instead of appending blindly;
- history deduplication and the 50-entry bound;
- the real CalculatorScreen desktop formula dialog path;
- the compact adaptive formula modal path;
- formula result insertion followed by calculation-history visibility.

## Manual Windows smoke

Test at approximately 500×480, 700×500, 900×500 and 1100×760.

- No yellow/black overflow stripes or clipped mandatory controls.
- Live resize preserves expression, caret and selection.
- Mouse click places the caret in the expression.
- Drag/Shift selection replaces correctly on keypad or keyboard input.
- Backspace deletes left; Delete deletes right.
- Home/End and Shift+Home/End behave correctly.
- Ctrl+A selects the full expression.
- Number row and numpad produce identical calculator commands.
- Shift+8 produces multiplication, not digit 8.
- Enter calculates; Up/Down navigate history.
- Long expressions remain horizontally editable.

## Manual Android smoke

- Tap-to-place caret works near start, middle and end of the expression.
- Selection handles can replace a range using calculator buttons.
- The system keyboard does not become the calculator input path.
- Long expressions keep the caret visible while horizontally scrolling.
- Compact layout remains usable without overflow.
- Science formulas open through the adaptive modal path.

## Math correctness smoke

Verify representative calculations:

- `2+3×4 = 14`
- `sin(90) = 1` in DEG
- `(2+3)! = 120`
- `(2+3)C2 = 10`
- `.5EXP2 = 50`
- `1EXP-13 = 1e-13`
- `1÷(2-2)` reports division by zero
- `sqrt(-1)` reports a domain error
- `10^400` reports overflow

## Science-formula smoke

Check at least one Physics and one Chemistry flow.

- Formula selection opens a variable solver instead of inserting symbols.
- Units/default constants are visible where configured.
- Missing/invalid fields show field-level validation.
- `Calculate` does not mutate the main calculator.
- `Insert result` inserts a parser-safe solved value.
- `Insert calculation` inserts the resolved numeric expression.
- Ideal Gas Law clearly solves Pressure using `P=(nRT)/V`.
- Completed inserted calculations can be evaluated and found in History.

## Release decision

Calculator release status is **green only when**:

- formatting check passes;
- `flutter analyze` passes;
- both dedicated release-contract test files pass;
- `flutter test test/features/calculator` passes;
- for a store candidate, whole-app regression and requested production builds pass;
- manual Windows + Android smoke passes.

A ZIP integrity check alone is not a runtime release gate.
