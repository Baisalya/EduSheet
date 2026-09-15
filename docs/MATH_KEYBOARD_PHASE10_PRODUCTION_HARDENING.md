# Math Keyboard Phase 10 — Production Hardening, Performance & Stress Testing

Phase 10 turns the Phase 1–9 math architecture into a bounded production
pipeline. It does not expand notation or change persistence. Its job is to
ensure large real papers remain deterministic while hostile or accidental
pathological input fails safely.

## Production budgets

`MathProductionLimits` centralizes ceilings for native math processing:

- 32,768 TeX characters per native formula probe.
- 64 source nesting levels.
- 16,384 export-parser primary steps.
- 65 export-parser recursion frames (root + 64 nested source levels).
- 128 environment rows, 64 columns and 2,048 total cells for imported TeX.
- 24 nested question levels before validation/export selects a safe boundary.
- Booklet planning budgets explicitly cover up to 2,000 questions and 20,000
  formulas; the automated stress corpus exercises 500 questions.

Interactive dynamic structures retain the stricter Phase 4 12×12 / 144-slot
limits.

Budget limits are not syntax errors. Source is preserved for persistence and
Advanced Source editing; screen/PDF/Word use the readable safe fallback.

## Bounded caches

Two LRU caches now expose hit/miss/eviction metrics:

- `MathCompatibilityCache` — parser/renderer/compatibility reports.
- `MathExportTypesettingCache` — Phase 8 export-neutral math IR, including
  negative compilation results.

Phase 9 validation uses the shared compatibility cache. PDF and Word native
math typesetters share the export compilation cache, avoiding repeated TeX → IR
work when formulas are reused across preview/export surfaces.

Both caches are bounded to 512 entries by default and can be cleared with
statistics reset for deterministic tests.

## Safe recursion boundaries

Question math validation stops recursively normalizing beyond 24 nested
question levels and records `validationDepthLimit`. The deeper saved subtree is
preserved; no user data is deleted.

PDF and Word exports independently enforce the same nesting ceiling. If a
pathological question tree exceeds it, the export emits a readable nested-depth
marker instead of recursively exhausting the stack.

## Stress and regression gates

Phase 10 adds:

- `math_production_hardening_test.dart`
  - source length and nesting budgets;
  - native compiler fail-closed behavior;
  - 12×12 matrix acceptance;
  - pathological environment rejection;
  - bounded compatibility/export cache metrics.
- `question_math_stress_test.dart`
  - 500-question / 500-formula booklet validation;
  - deterministic second-pass JSON;
  - repeated-formula cache reuse;
  - pathological nested-question safe boundary.
- `math_export_stress_test.dart`
  - 1,000 repeated PDF + Word native typesetting iterations;
  - shared export cache reuse;
  - oversized source refusal from native export.

Stress tests intentionally do not contain hard wall-clock thresholds. CI,
Windows and Android hardware vary widely; correctness is gated by bounded work,
determinism and cache limits instead of a machine-specific stopwatch number.

## Compatibility guarantees

Phase 10 introduces no database migration, no persistence schema change and no
new dependency. Phase 6 safe fallback, Phase 8 native PDF/Word typesetting and
Phase 9 source-preserving validation remain the authoritative failure policy.
