# Scientific Calculator Architecture Refactor — 2026-08-14

## Scope

This refactor is intentionally limited to EduSheet's scientific calculator and its calculator tests. No PDF, Word export, question-bank, paper-composer, database, or unrelated feature architecture was changed.

## Architectural changes

### Domain calculation layer

The calculation engine no longer lives architecturally inside `data/repositories`. The implementation is now in:

- `domain/services/math_engine.dart`
- `domain/services/calculator_input_editor.dart`
- `domain/services/calculator_expression_formatter.dart`

The former `data/repositories/math_engine.dart` path is retained only as a compatibility export so existing imports do not break abruptly.

### Explicit result model

Calculation success/failure is represented by `CalculationResult`, including:

- numeric value on success
- display text
- error code
- user-facing error explanation

The legacy `MathEngine.evaluate(...) -> String` API is retained for compatibility and delegates to the detailed result API.

### Input editing separated from Riverpod

Token resolution and editing rules are pure domain behavior in `CalculatorInputEditor`:

- one-shot SHIFT/HYP token resolution
- token-aware delete
- decimal-point guarding
- sign toggling
- operator normalization
- post-result continuation through `Ans`

This gives touch, mouse and hardware-keyboard input one shared rule set.

### Typed history

History now stores `CalculationHistoryEntry` records rather than expression-only strings. Each entry stores:

- expression
- result
- angle unit
- creation time

History navigation also preserves the expression draft while moving backward/forward.

### Structured equation formatting

The previous global string-replacement LaTeX conversion was replaced with a structural formatter. It treats inverse trig functions before base trig names, balances root braces and formats powers without corrupting expressions such as `arcsin(...)`, `sqrt(...)`, `cbrt(...)` and `x^-1`.

### Reusable adaptive calculator widget

`ScientificCalculator` is now the reusable calculator body. `CalculatorScreen` is reduced to navigation/scaffold and history/formula presentation.

The widget adapts by constraints rather than platform forks:

- compact/tall: stacked scientific + main keypads
- wide desktop/tablet: side-by-side scientific + main keypads
- short/free-form window: scrollable fallback instead of RenderFlex overflow

The same widget is used for Android and Windows.

### Hardware keyboard support

The calculator handles current Flutter key events through `Focus.onKeyEvent`, including:

- number row and numpad digits
- numpad add/subtract/multiply/divide/decimal
- `+ - * / ^ . ( )`
- Enter/numpad Enter = calculate
- Backspace/Delete = calculator delete
- Escape = clear
- Up/Down = calculation history navigation

### Theme correctness

Calculator button foregrounds no longer force a dark text color. Unspecified key text now inherits the active Material color scheme, fixing unreadable dark-mode numeric keys.

## Calculation correctness fixes

- Removed the old factorial implementation that returned the fixed value of `20!` for every input above 20.
- Literal factorials above the finite double calculator range (`170!`) now return an overflow error instead of a fabricated value.
- nCr/nPr now use multiplicative `BigInt` computation before entering the numeric parser, avoiding the prior `>20` corruption.
- Invalid `r > n` combinatoric input returns a domain error.
- Excessively large interactive combinatoric work is rejected instead of blocking the UI.
- Non-finite parser results are returned as calculation failures.
- `Ans` values written in exponential form are serialized safely for the parser.
- Unmatched closing parentheses are rejected; missing closing parentheses are still auto-completed for calculator-style entry.

## Tests added/expanded

Calculator tests now cover:

- arithmetic and precedence
- constants and implicit multiplication
- DEG/RAD trig and nested trig
- logs, roots, hyperbolic functions and EXP
- factorial/nCr/nPr including values above 20
- overflow/domain errors
- detailed result model
- SHIFT/HYP input resolution
- token deletion and decimal behavior
- post-result continuation
- typed history and draft navigation
- LaTeX inverse trig/root/power formatting
- compact Android-like width
- desktop split layout
- short free-form window fallback
- physical keyboard/numpad calculation path

## QA execution status

The source was reviewed structurally and the new test suite was written, but this execution environment does not contain a Flutter or Dart SDK. Therefore `flutter analyze` and `flutter test` could not be executed here. They must be run on the normal EduSheet Flutter development machine before release certification.

Recommended release commands:

```powershell
flutter pub get
flutter analyze
flutter test test/features/calculator
flutter test
flutter run -d windows
```

Then perform one Android device/emulator smoke test and one Windows resize/free-form smoke test before publishing.
