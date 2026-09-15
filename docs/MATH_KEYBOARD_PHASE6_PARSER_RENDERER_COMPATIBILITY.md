# Math Keyboard Phase 6 — Parser / Renderer Compatibility Layer

## Why this phase exists

A symbol being present in the keyboard catalogue does not prove that every
consumer can parse, edit, render, or export it. Phase 6 introduces one explicit
compatibility boundary so those capabilities are measured independently.

## Compatibility surfaces

`MathCompatibilityService` reports four surfaces for a TeX source:

1. **Visual editor** — probes `math_keyboard` parsing and EduSheet's dynamic /
   declarative reconstruction paths.
2. **Screen renderer** — preflights the public `flutter_math_fork` TeX parser.
3. **PDF export** — currently a readable-text fallback surface.
4. **Word export** — currently a readable-text fallback surface.

Supported states are `native`, `fallback`, `sourceOnly`, and `unsupported`.

## Visual editor strategies

The service chooses one explicit reconstruction strategy instead of scattering
TeX special cases through widgets:

- dynamic structure codec
- direct `math_keyboard` parser
- safe bare-variable normalization + parser
- catalogue symbol insertion recipe
- legacy declarative command registry
- Advanced Source only

Advanced Source remains a lossless escape hatch when the visual parser cannot
reconstruct a valid renderer-compatible expression.

## Screen rendering safety

`SafeMathExpression`, key previews, and the book preview now preflight
`flutter_math_fork` parser compatibility. If parsing fails, EduSheet renders the
readable fallback instead of blindly entering the renderer path. Widget-level
`onErrorFallback` remains as a final protection for later build/layout failures.

## Validation

`MathExpressionValidator` delegates delimiter/environment syntax checks to the
compatibility service. Environment pairing now checks actual `begin/end` names,
not only whether both words happen to occur in the source.

## Export contract

Phase 6 does **not** pretend that PDF or Word can typeset TeX. Those surfaces are
reported as readable fallback. Export code now obtains fallback text through the
same compatibility service, so an old/imported expression with blank
`plainText` no longer falls back to exposing raw TeX commands.

Real equation typesetting / OMML remains Phase 8 work.

## Regression gates

- `math_parser_renderer_compatibility_test.dart`
- `math_export_compatibility_test.dart`
- existing math expression validation tests
- existing Phase 1–5 math keyboard suites

The catalogue inventory remains the Phase 5 baseline: 386 placements / 356
semantic IDs. Phase 6 changes capability interpretation, not catalogue identity.

## Regression hotfix — catalogue insertion fragments

Catalogue `tex` is normally a complete semantic source, but three historical
bracket builders intentionally keep a one-character insertion seed: `(`, `[`,
and `{`. The compatibility audit now records these under
`intentionalFragmentIds` and validates their declarative editor command instead
of reporting them as malformed persisted TeX. Strict source validation remains
unchanged for formulas authored or stored by users.

The hotfix also restores the established accessibility announcement
`Formula needs attention` for malformed formulas, removes Phase 6 analyzer
dead/null-aware warnings in key previews, and removes an unused formula-editor
import.

