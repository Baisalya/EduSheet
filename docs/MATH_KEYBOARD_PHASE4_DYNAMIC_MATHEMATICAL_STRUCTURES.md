# Phase 4 — Dynamic Mathematical Structures

Phase 4 replaces the remaining fixed-row/fixed-dimension editing bottleneck with a runtime structure engine. The catalogue remains a discoverability layer; variable-size mathematical layouts are generated from domain specifications instead of multiplying hard-coded TeX templates.

## Scope implemented

The Build panel now exposes runtime builders for:

- arbitrary rectangular matrices within the editor safety limits;
- square determinants of arbitrary order;
- augmented matrices with a configurable divider column;
- piecewise functions with a variable number of expression/condition rows;
- simultaneous-equation systems with a variable number of equations;
- aligned multi-step derivations with `=`, `<=`, `>=`, or implication relations.

The historical 2x2 matrix, 3x3 matrix, 2x2 determinant, and two-row piecewise catalogue entries are preserved. They now route through the same dynamic slot engine rather than separate visual-editor special cases. The existing populated two-equation template is also recognized by the runtime codec and rehydrated as editable rows while preserving its seed values.

## Architecture

### `MathDynamicStructureSpec`

A domain-only specification describes the structure family and runtime dimensions. It has no Flutter or `math_keyboard` dependency. Validation centralizes row/column/divider constraints, enforces square determinants, and prevents invalid structures from reaching presentation adapters.

### `MathDynamicStructureCodec`

The codec is the canonical structure compiler. It produces:

1. canonical TeX;
2. ordered semantic slot metadata;
3. a literal/slot token plan for visual editing;
4. a dimension-aware plain-text fallback.

The same codec recognizes EduSheet-owned matrix/cases/aligned TeX on reopen. Common equation-system alignment such as `x+y&=1` is normalized back to equation rows instead of being mistaken for a piecewise function. It is intentionally not a general-purpose TeX parser; unknown environments remain on the existing Advanced Source path.

### Visual slot materialization

`MathFieldEditorAdapter` materializes the codec token plan as one host sequence containing literal TeX fragments and real editable argument nodes. A runtime structure identity keeps semantic navigation inside the correct generated structure.

`Next box` therefore means:

- matrix/determinant/augmented matrix: next cell in row-major order;
- piecewise: expression -> condition -> next row expression;
- equation system: next equation;
- aligned derivation: left side -> right side -> next row left side;
- final slot: exit the generated structure.

Nested Phase 3 builders continue to work inside a dynamic slot because each slot is a normal editable TeX node, not a painted placeholder.

### Reopen and recent/raw insertion

Before falling back to raw-leaf insertion, the MathField adapter asks the dynamic codec whether the source is a recognized Phase 4 structure. Formula Editor does the same before the general `TeXParser` route. This lets saved/recent canonical dynamic structures return as navigable boxes instead of losing their row/cell structure.

## Compatibility decisions

- `MathExpression` JSON format is unchanged.
- No database migration was introduced.
- No new package dependency was introduced.
- Static catalogue identity is unchanged at 299 placements / 270 semantic IDs / 270 TeX identities.
- Phase 2's import-identity convention is preserved.
- TextField and Quill targets receive a dimension-aware plain-text description through `MathPlainTextSerializer` rather than raw environment TeX. Existing explicit mappings keep precedence, so legacy fixed-template fallbacks such as the 2x2 determinant remain unchanged.

## Deliberate boundaries

- Generated dimensions are bounded by `MathDynamicStructureLimits` to prevent accidental huge editor trees; the architecture itself is dimension-driven rather than template-driven.
- Reopening a dynamic structure restores each top-level cell/row value as one editable seed leaf. It does not attempt to reverse-parse arbitrary nested TeX inside every cell; renderer/parser compatibility hardening remains Phase 6 work.
- Phase 4 does not claim PDF/DOCX equation typesetting. The Phase 1 Office fallback baseline remains unchanged until the export phase.
- Commands outside the codec-owned environment families (for example `\\binom`, `\\mapsto`, variant Greek commands) remain Advanced Source/catalog-expansion work rather than being guessed here.

## Regression gates

`math_dynamic_structure_engine_test.dart` locks:

- runtime matrix compilation;
- augmented-matrix divider round-trip;
- piecewise slot ordering and round-trip;
- variable-row equation systems;
- variable-row aligned derivations and relation preservation;
- semantic Next-box navigation across matrix cells and piecewise rows;
- dynamic routing of legacy fixed presets;
- dynamic rehydration of the existing populated two-equation template;
- common `&=` equation-system rehydration;
- legacy fixed-template plain-text compatibility plus dimension-aware dynamic fallback;
- matrix column-counter safety down to a valid 1-column matrix (widget regression gate).

The universal booklet corpus now marks the former dynamic-matrix, dynamic-piecewise, and aligned-derivation architectural gaps as Phase 4 runtime-builder capabilities and adds augmented-matrix and larger equation-system coverage.
