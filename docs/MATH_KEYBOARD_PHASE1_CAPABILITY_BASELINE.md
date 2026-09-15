# Math Keyboard Phase 1 — Capability Baseline

This document records the Phase 1 regression baseline before the universal
math-composer architecture is changed. It is intentionally descriptive: no
production insertion, rendering, persistence, PDF, or Word behavior is changed
by this phase.

## Catalogue inventory

- 293 catalogue placements.
- 264 unique semantic IDs.
- 264 unique TeX identities.
- 29 duplicate placements caused by the same semantic entry appearing in more
  than one category.
- No semantic-ID-to-TeX conflicts are expected.
- No TeX-to-semantic-ID conflicts are expected.

Category placement counts:

| Category | Placements |
| --- | ---: |
| Basic | 33 |
| Functions | 25 |
| Trigonometry | 18 |
| Calculus | 17 |
| Operators | 19 |
| Greek | 24 |
| Sets | 15 |
| Brackets | 6 |
| Geometry | 29 |
| Physics | 37 |
| Statistics | 16 |
| Arrows | 7 |
| Matrices | 4 |
| Templates | 16 |
| Chemistry | 20 |
| Miscellaneous | 7 |

The executable catalogue audit is `tool/math_keyboard_catalog_audit.dart` and
the regression snapshot is `test/features/math_keyboard/math_catalog_audit_test.dart`.

## Universal booklet regression corpus

`test/support/math_keyboard/universal_math_booklet_corpus.dart` now covers all
current broad subject metadata families: general mathematics, arithmetic,
algebra, trigonometry, calculus, geometry, probability, statistics, linear
algebra, sets, logic, physics, and chemistry.

The corpus distinguishes four entry paths rather than pretending all notation
has the same level of support:

1. `catalogBacked` — the expression can be assembled from normal catalogue
   keys.
2. `fixedTemplate` — a complete current template exists, but its shape/row
   count is fixed.
3. `advancedSource` — the balanced TeX source is retained as an Advanced Source
   regression case, without claiming a first-class keyboard key or renderer
   guarantee.
4. `architecturalGap` — the current catalogue has no dynamic first-class
   builder for that notation family.

The baseline includes representative fractions, nth roots, scientific notation,
quadratic algebra, simultaneous equations, trigonometry, bounded integrals,
derivatives, limits, products, number sets, quantifiers, geometry, probability,
statistics, fixed matrices/determinants, physics, chemistry, and Greek symbols.

## Explicit first-class gaps recorded in Phase 1

The baseline deliberately records these rather than hiding them behind a generic
Advanced TeX escape hatch:

- arbitrary `m x n` matrix construction;
- dynamic piecewise/cases row construction;
- aligned multi-step derivation construction;
- direct `\\binom` keyboard entry;
- `\\mapsto` in the arrow catalogue;
- `\\bigcup` as a first-class set operator;
- variant Greek glyphs such as `\\varepsilon`, `\\vartheta`, and `\\varphi`.

These are entry/composition gaps. Phase 1 does **not** claim that a balanced TeX
string is renderable on every surface merely because the current shallow
validator accepts it.

## Persistence and validation baseline

Every corpus case is round-tripped through `MathExpression.toJson()` and
`MathExpression.fromJson()` so later refactors cannot silently change stored
formula source or fallback text.

The current validator baseline is also locked. It verifies non-empty source,
balanced braces/brackets/parentheses, and a coarse `\\begin`/`\\end` presence
check. Strong command/environment/renderer compatibility validation is deferred
to the later validation phase.

## Export baseline — known limitation

`test/features/pdf/math_export_fallback_baseline_test.dart` records the current
Office export behavior: a rich-text math embed is flattened to
`MathExpression.plainText` (or LaTeX if the fallback is empty). This is semantic
retention, **not** real Word equation typesetting.

The same Phase 1 baseline also records that matrix fallback text can be a
placeholder such as `[2x2 matrix]`. A later export phase must replace this with
real equation/matrix rendering while preserving accessibility fallback text.

## Phase 1 gate

Before moving to the command/composer refactor, the intended gate is:

```text
flutter analyze --no-pub
flutter test test/features/math_keyboard/math_catalog_audit_test.dart
flutter test test/features/math_keyboard/math_universal_booklet_baseline_test.dart
flutter test test/features/pdf/math_export_fallback_baseline_test.dart
flutter test test/features/math_keyboard
flutter test
```

No new package or database schema is introduced by Phase 1.

## Phase 3 additive inventory note

Phase 1's original 293-placement snapshot remains the historical pre-refactor baseline. Phase 3 intentionally adds six first-class structured-composer entries, so the active regression inventory is now 299 placements / 270 semantic IDs / 270 TeX identities. See `MATH_KEYBOARD_PHASE3_STRUCTURED_COMPOSER_ENGINE.md` for the exact delta and composer-specific counts.
