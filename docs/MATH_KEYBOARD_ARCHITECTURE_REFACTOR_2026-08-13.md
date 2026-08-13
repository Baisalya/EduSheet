# Math Keyboard Architectural Refactor — 2026-08-13

## Scope

This pass refactors the existing EduSheet math keyboard without changing the persisted `MathExpression` format and without adding a package dependency. It focuses on a safer domain model, typed editor boundaries, semantic discovery, and a smaller phone-first navigation model.

## Structural changes

### Domain catalogue

- Split the former monolithic symbol/model file into a domain model plus 16 category catalogues.
- Added stable semantic IDs. The same TeX meaning shares the same ID even when intentionally surfaced in more than one category.
- Added semantic entry type, subject metadata, education-level metadata, search aliases, spoken labels, priority, and input behavior.
- Added `MathSymbolCatalog` as the single catalogue/query boundary.
- Added semantic search so normal teacher language such as `fraction`, `numerator`, `wavelength`, `standard deviation`, `perpendicular`, and `equilibrium` can find notation without knowing LaTeX.

### Input behavior

- Power/subscript activation is now domain metadata (`MathInputBehavior`) instead of presentation/controller code matching magic TeX strings.
- Builder entries can declare an optional base source, for example `e` before power mode or `\\int` before integral index entry.
- Added `MathSmartPalette`, a curated contextual ribbon for calculus, physics, chemistry, statistics, geometry, trigonometry, and the default/common context.

### Editor boundary

- Added `MathEditorAdapter` and concrete adapters for:
  - normal `TextEditingController`
  - Quill
  - `MathFieldEditingController`
- Removed editor-type branching from the main keyboard controller.
- Isolated the existing `math_keyboard` package implementation import to the MathField adapter because the currently installed package exposes `TeXArg` there.
- Extracted plain-text/Unicode conversion into `MathPlainTextSerializer`.
- Fixed reversed selection handling for text and Quill adapters.
- Fixed Quill post-insertion cursor clamping to use the new document end rather than the pre-insertion document end.

### Controller

- Reduced `math_keyboard_controller.dart` from 987 lines to about 336 lines.
- Replaced the active editor `dynamic` value with `Object?` and an adapter factory boundary.
- Kept existing recent-symbol persistence format for compatibility.
- Kept keyboard state, focus, mode, category, sizing, and navigation responsibilities in the controller.

### Favorites migration

- Favorites now persist stable semantic IDs under `math_keyboard_favorite_symbols_v2`.
- Existing `math_keyboard_favorite_symbols_v1` TeX favorites are read and migrated automatically so existing user choices are not silently discarded.

### Mobile UX

- Replaced the 19 always-visible category tabs with a small primary navigation set: Common, Algebra, Calculus, Science, More.
- Added a grouped More sheet for Mathematics, Science, Symbols, Tools, Recent, and Favourites.
- Added contextual smart ribbons with high-frequency textbook structures for the selected subject.
- Changed phone symbol grids from six columns to five for safer touch targets; formula-heavy sections retain wider cards.
- Kept a 48dp minimum interaction target in `MathKey`.
- Search is now plain-language/semantic rather than label/TeX-only.
- Search and the bottom action bar were extracted from the large keyboard view into dedicated widgets.

## Compatibility evidence

Static comparison against the untouched uploaded project was performed after the refactor:

- Original catalogue placements: **293**
- Refactored catalogue placements: **293**
- Comparison fields: label, TeX source, category, builder flag, and variations
- Result: **exact multiset match**
- Unique semantic TeX meanings: **264**
- Same-TeX/multiple-ID violations: **0**
- ID/multiple-TeX collision violations: **0**
- Original plain-text conversion pairs: **138**
- Refactored serializer conversion pairs: **138**
- Mapping comparison: **exact match**

A source-level delimiter/import check was also run across the keyboard Dart sources and keyboard tests; no unmatched delimiters or missing local imports were found.

## Tests added/extended

- Catalogue stability and semantic ID tests.
- Semantic teacher-language search tests.
- Domain input-behavior tests.
- Contextual smart-palette tests.
- Plain-text serializer tests for fraction cursor placement, functions, powers, subscripts, and Greek conversion.
- Text editor adapter tests for insertion and forward/reversed selections.

## Runtime verification limitation

The provided execution environment does not contain the Flutter or Dart CLI, so `flutter analyze` and `flutter test` could not be executed here. This report does **not** claim a successful Flutter compile or runtime test run. The tests and static checks are included so they can be run immediately in the project's normal Flutter environment.

## Deliberately not guessed

`MathFieldEditingController` in the currently authorized `math_keyboard` package does not expose a public clear-all operation used by this project. The MathField adapter therefore preserves the previous clear-all no-op rather than mutating undocumented private state or inventing an API.

## Remaining architectural follow-up

The next safe phase is to move the remaining structured MathField insertion branches into explicit command/template objects and add richer placeholder navigation/wrap-selection behavior. Geometry/Quill tool panels can also be split further from `math_keyboard_view.dart`. Those changes should be runtime-tested with Flutter before changing persisted formula representation.
