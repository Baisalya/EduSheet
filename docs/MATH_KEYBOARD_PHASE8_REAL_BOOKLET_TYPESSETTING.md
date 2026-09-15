# Phase 8 — Real Booklet PDF/Word Math Typesetting

Phase 8 upgrades the export contract from readable formula fallbacks to a real,
auditable native typesetting path for the TeX subset EduSheet owns.

## Architecture

`MathExportTypesettingCompiler` is the single export-neutral compiler. It turns
supported TeX into a small immutable layout tree: sequences, fractions,
binomial stacks, roots, scripts, accents, delimiters and matrices. It is a
fail-closed compiler: an unknown command or unsupported environment rejects the
whole formula so an export can use the Phase 6 readable fallback instead of
producing a partially interpreted equation.

Two format adapters consume the same tree:

- `PdfMathTypesetter` builds native `package:pdf` widgets. Fractions use real
  numerator/denominator stacking and rules; roots, scripts, accents, scalable
  delimiter groups and matrices are layout widgets rather than raw TeX text.
- `WordOmmlMathTypesetter` emits Office Math Markup Language (`m:oMath`) into
  `word/document.xml`. Fractions, radicals, scripts, delimiters and matrices are
  native Word equation objects and remain equation content when the document is
  opened in Microsoft Word.

No external process, network renderer or new package dependency is required.

## Supported native subset

The compiler covers the textbook families introduced through Phases 2–5:

- fractions and nested fractions
- square and indexed roots
- superscripts and subscripts
- Greek letters and common operators/relations/arrows
- standard named functions (`sin`, `cos`, `log`, `lim`, `gcd`, ...)
- sums, products and integrals with limits through ordinary scripts
- binomial coefficients
- vectors, overlines, hats and tildes
- blackboard-bold number systems
- matrices, determinants, arrays, cases/systems and aligned derivations
- ordinary dynamic augmented-matrix output, including the configured divider

Anything outside this explicit subset remains readable through the Phase 6
fallback contract. Raw TeX is never used as the emergency export representation.

## Math Everywhere propagation

Phase 8 does not only typeset the question-body formula list. It consumes the
Phase 7 structured math-surface registry for:

- options
- stimulus title/text
- word-bank items
- table caption, headers and cells
- attachment captions
- instructions
- correct answer and explanation where the export surface includes them

Quill math embeds are emitted in their original rich-text order. Surface math is
only used while its stored readable fallback still matches the current legacy
string, preserving Phase 7's stale-metadata safety fence. Surface-owned formula
IDs are excluded from the generic unplaced-formula export path so the same
equation cannot be emitted a second time below the question.

## Compatibility reporting

`MathCompatibilityService` now reports PDF/Word as `native` when the shared
export compiler accepts the source. Unsupported but readable sources remain
`fallback`. `MathCompatibilityAuditor` records PDF-native and Word-native counts
separately so future catalogue additions cannot silently claim export support.

## Word round-trip boundary

The exact Smart Paper payload remains embedded in the DOCX custom XML envelope,
so reopening an unchanged exported file can restore the canonical EduSheet
paper. Native OMML is the visible equation representation; the canonical TeX
continues to live in the EduSheet model rather than being reverse-engineered
from OMML.

## Regression gates

Run:

```powershell
dart format lib/features/math_keyboard lib/features/pdf/services test/features/math_keyboard test/features/pdf
flutter analyze --no-pub
flutter test test/features/math_keyboard/math_export_typesetting_test.dart
flutter test test/features/pdf/math_native_typesetter_test.dart
flutter test test/features/pdf/office_export_services_test.dart
flutter test test/features/math_keyboard/math_parser_renderer_compatibility_test.dart
flutter test test/features/math_keyboard
flutter test
```
