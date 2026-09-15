# Math Keyboard Phase 3 — Universal Structured Composer Engine

## Scope

Phase 3 extends the Phase 2 declarative command layer with semantic slot metadata and source-selection wrapping. It does not change the persisted `MathExpression` schema, database schema, or dependencies.

## Architecture

- `MathComposerSpec` describes a structure independently from its TeX spelling.
- `MathComposerSlotSpec` names editable positions such as numerator, denominator, radicand, exponent, subscript, limits, derivative expression/variable, and endpoints.
- `MathEditCommand.composer` links the adapter execution plan to that semantic structure.
- `MathSelectionComposer` is a pure Dart source transformer for editors that expose a real text selection.
- The visual `MathField` remains slot-driven through the public `math_keyboard` controller methods; no private cursor/selection state is accessed.

## First-class Phase 3 builders

Six new catalogue structures are additive:

1. combined subscript + superscript (`_{}^{}`)
2. generic derivative (`\\frac{d{}}{d{}}`)
3. generic limit condition (`\\lim_{}`)
4. inner product (`\\langle{},{}\\rangle`)
5. evaluation bar with lower/upper endpoints (`|_{}^{}`)
6. norm (`||{}||`)

Existing fraction/root/limits/brackets/accents are annotated with composer metadata rather than duplicated.

Semantic slot navigation is normalized at the adapter boundary. In particular, the seeded generic derivative starts in the numerator expression after `d` and one logical **Next slot** moves to the denominator variable after its seeded `d`. Adjacent subscript/superscript functions likewise behave as one two-slot structure instead of exposing package-level intermediate cursor nodes.

## Selection wrapping

Advanced Formula source can wrap an existing selected expression as:

- fraction
- square root
- superscript
- subscript
- combined subscript + superscript
- absolute value
- norm
- generic derivative
- inner product
- evaluation bar
- overline
- vector

A collapsed/invalid selection is rejected; no text range is guessed.

## Nesting

Structured commands remain composable because the visual adapter executes public slot operations. A structure can be inserted while the cursor is already inside another structure, e.g. a square root inside a fraction numerator and another fraction inside that root.

## Capability boundary

`math_keyboard 0.3.3` exposes node/slot navigation but no public text-selection range for `MathFieldEditingController`. Therefore Phase 3 does not mutate upstream private node state to simulate visual selection wrapping. Source selection wrapping is real; visual MathField composition is slot/nesting based.

Dynamic matrices, variable-row cases/aligned derivations, and unverified renderer commands such as a dedicated `\\binom` builder remain later-phase work.

## Regression inventory after Phase 3

- catalogue placements: 299
- unique semantic IDs: 270
- unique TeX identities: 270
- duplicate placements: 29
- structural semantic IDs: 90
- formula-template semantic IDs: 35
- declarative command placements: 73
- declarative command semantic IDs: 64
- structured composer placements: 31
- structured composer semantic IDs: 25
- source-selection-wrap placements: 24
- source-selection-wrap semantic IDs: 18
- ID/TeX identity conflicts: 0

## Local verification

```powershell
dart format lib/features/math_keyboard test/features/math_keyboard test/support/math_keyboard tool/math_keyboard_catalog_audit.dart
flutter analyze --no-pub
flutter test test/features/math_keyboard/math_structured_composer_engine_test.dart
flutter test test/features/math_keyboard/math_declarative_command_architecture_test.dart
flutter test test/features/math_keyboard/math_catalog_audit_test.dart
flutter test test/features/math_keyboard/math_universal_booklet_baseline_test.dart
flutter test test/features/math_keyboard
flutter test
```
