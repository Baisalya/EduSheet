# Phase 5 — Symbol Universe Expansion

Phase 5 expands EduSheet's first-class math-keyboard notation without changing
`MathExpression` persistence, the database schema, or package dependencies.

## Architectural rule

The expansion is isolated in
`symbol_universe_expansion_catalog.dart`. Entries use the existing UI
categories, so navigation and saved category state do not need migration.
Every Phase 5 entry has a stable SHA-1-derived semantic id, a plain-language
label/alias surface, and a deterministic plain-text fallback path.

Renderer/parser compatibility is intentionally **not** declared here. Phase 6
owns the compatibility matrix for `math_keyboard`, `flutter_math_fork`, TeX
parsing, and export surfaces.

## Added first-class coverage

- Greek: missing common lowercase letters, distinct uppercase letters, and
  conventional variant glyphs such as `\\varepsilon`, `\\vartheta`, and
  `\\varphi`.
- Arrows/mappings: `\\mapsto`, long arrows/mapsto, hooks, harpoons,
  `\\Leftarrow`, reversible harpoons, and `\\leadsto`.
- Operators/relations: dot/star/circled operators, tensor/direct-sum notation,
  strong order relations, divisibility, turnstiles, model entailment, truth and
  falsehood symbols, and big logical operators.
- Set theory: proper/non-subset relations, set difference, square lattice
  relations, disjoint/square union/intersection, `\\bigcup`, `\\bigcap`, and
  editable indexed big-union/big-intersection builders.
- Combinatorics: two-slot `\\binom{}{}` builder with source-selection wrap.
- Number theory: editable `\\pmod{}` plus `gcd()`/`lcm()` search and insertion,
  divisibility and non-divisibility relations.
- Complex numbers: real/imaginary part, argument, and editable conjugate /
  overline structure.
- Advanced common notation: aleph, reduced Planck constant, script ell, centered,
  vertical, and diagonal ellipses.

## New semantic subject families

`MathSubject` now includes:

- `combinatorics`
- `numberTheory`
- `complexNumbers`

These are search/ranking metadata only; they do not create new keyboard tabs.

## Structured additions

The following Phase 5 entries use declarative editor commands rather than raw
TeX branching:

- binomial coefficient
- modulo argument
- big union with lower/upper limits
- big intersection with lower/upper limits
- gcd call
- lcm call
- complex argument call
- complex conjugate / overline

Binomial, modulo, and conjugate also expose source-selection wrapping. Big union
and big intersection reuse the existing semantic lower/upper-limit composer.

## Deliberate boundaries after Phase 5

Phase 5 does not create one key for every named special function or every rare
TeX command. The regression corpus keeps advanced-source cases for labeled
extensible arrows, rare closed-surface integral variants, arbitrary named
special functions, and dense domain-specific tensor-index presets. Those cases
remain explicit rather than being silently claimed as first-class support.
