# Math Keyboard Phase 2 — Declarative Command Architecture

Phase 2 removes the visual math editor's large raw-TeX dispatch tree and makes
structured insertion an explicit catalogue/domain concern. It does not change
the persisted `MathExpression` schema, add a dependency, or change the Phase 1
booklet/export capability claims.

## Problem removed

Before this phase, `MathFieldEditorAdapter.insert()` contained a long ordered
chain of raw source checks such as fractions, roots, derivatives, bounded
operators, trigonometric functions, paired delimiters, accents, vectors, and
powers. That made a catalogue entry's visible TeX source double as an implicit
editing protocol. A valid-looking source could therefore behave differently
simply because it matched, or failed to match, one presentation-layer branch.

Phase 2 separates those concerns:

- `MathSymbol.tex` remains the semantic/persisted TeX identity.
- `MathSymbol.editorCommand` now optionally describes visual insertion
  choreography.
- `MathEditCommand` is a package-neutral sequence of leaf insertion, function
  insertion, and slot movement operations.
- `MathFieldEditorAdapter` is now a generic command executor rather than the
  owner of symbol-specific knowledge.
- Text and Quill adapters intentionally retain their current plain-text
  serialization path, so this phase does not change non-visual-editor output.

## Domain command model

`lib/features/math_keyboard/domain/models/math_edit_command.dart` introduces:

- `MathEditArgument` — brace/bracket function argument shape;
- `MathEditOperation` — sealed operation boundary;
- `MathInsertLeaf` — insert one leaf/token;
- `MathInsertFunction` — insert a structured function and argument slots;
- `MathMoveSlot` — deterministic previous/next slot movement;
- `MathEditCommand` — immutable ordered recipe;
- `MathEditCommands` — shared reusable recipes;
- `MathLegacyEditCommandRegistry` — explicit compatibility aliases for old raw
  insertion callers.

The domain command model deliberately imports neither Flutter nor the
`math_keyboard` implementation package. Mapping to the package's `TeXArg` type
happens only inside `MathFieldEditorAdapter`.

## Catalogue migration baseline

Phase 2 explicitly attaches declarative commands to:

- **67 catalogue placements**;
- **58 semantic IDs**.

The migrated families include:

- fractions and fixed common fractions;
- square/cube/nth roots;
- power/subscript slots and common powers;
- absolute value and paired delimiters;
- log/base-log/exponential structures;
- trig, inverse-trig and hyperbolic function calls;
- bounded integral/sum/product;
- first/second derivative templates and limit-to-infinity;
- vector, bar, overline, ray, line and widehat structures;
- degree/prime/charge superscript structures;
- legacy degree-Celsius visual behavior.

Duplicate semantic IDs that appear in more than one category are required to
carry equivalent command recipes, preventing category-dependent editing
behavior.

## Compatibility boundary

The keyboard controller now has two intentionally different insertion paths:

1. **Typed catalogue path** — `insertSymbol` / `insertStructure` preserves the
   full `MathSymbol` and calls `MathEditorAdapter.insertSymbol`.
2. **Raw compatibility path** — hardware characters, whitespace, geometry
   placeholders and historical raw callers can still call `insertText`.

`MathLegacyEditCommandRegistry` currently contains **63 explicit historical raw
aliases**. It preserves old raw/recent behavior without recreating an imperative
`if/else` tree in the adapter. This registry is transitional compatibility
infrastructure; new catalogue entries should declare `editorCommand` directly.

The old adapter-only special cases for `\\triangle_{A B C}` and
`\\text{Graph}` were not invented into the current catalogue. They are retained
only as legacy raw aliases because no current catalogue entry owns them.

## Superscript compatibility note

The previous adapter inserted some legacy TeX superscript content one character
at a time. Phase 2 records that behavior explicitly for degree, prime,
double-prime and degree-Celsius recipes instead of silently changing it.
Normalization belongs to the later parser/renderer compatibility phase, where
it can be changed with dedicated visual regression evidence.

## Regression contracts

`test/features/math_keyboard/math_declarative_command_architecture_test.dart`
locks these properties:

- duplicated semantic placements cannot disagree about command metadata;
- command execution is driven by metadata, not by the symbol's stored TeX;
- function-call insertion is also source-independent;
- 67 placements / 58 semantic IDs currently carry commands;
- all declared commands are non-empty;
- the 63-entry legacy alias registry remains explicit;
- the visual adapter cannot regress back to the old TeX dispatch-tree patterns.

`math_keyboard_controller_build_test.dart` also contains an end-to-end synthetic
symbol test proving that command metadata survives the controller boundary into
the visual editor.

The Phase 1 catalogue inventory remains unchanged: 293 placements, 264 semantic
IDs and 264 TeX identities.

## Phase 2 verification gate

Run in the normal Flutter environment:

```text
dart format lib/features/math_keyboard test/features/math_keyboard tool/math_keyboard_catalog_audit.dart
flutter analyze --no-pub
flutter test test/features/math_keyboard/math_catalog_audit_test.dart
flutter test test/features/math_keyboard/math_declarative_command_architecture_test.dart
flutter test test/features/math_keyboard/math_keyboard_controller_build_test.dart
flutter test test/features/math_keyboard
flutter test
```

The execution environment used to prepare this phase does not contain the Dart
or Flutter CLI, so the package includes the tests but does not claim that those
commands were executed here.

## Next architectural boundary

Phase 3 can now build a universal structured composer on top of commands/slots
without adding another TeX-specific branch to the visual adapter. That phase can
focus on nested selection wrapping, reusable placeholders, combined
superscript/subscript structures, generalized limits and deeper slot traversal.
