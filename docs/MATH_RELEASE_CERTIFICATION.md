# EduSheet Universal Math — Phase 12 Release Certification

## Certification state

**Implementation state:** Phase 12 release-gate architecture is present.

**Runtime certification state:** `PENDING_LOCAL_GATE` until the complete
`tool/run_math_release_gate.ps1` command finishes successfully in an EduSheet
Flutter environment. Static source checks or ZIP integrity alone are not a
production certification.

## Release decision contract

Phase 12 classifies findings as:

- **Critical** — silent formula corruption/loss, unsafe syntax reaching a
  consumer, unusable screen route, or persistence identity drift. Blocks
  release.
- **High** — no safe PDF/Word route, no readable fallback, or no usable
  authoring route. Blocks release.
- **Medium** — bounded production limitation requiring attention but with
  preserved source and a safe consumer route. Tracked, not silently ignored.
- **Accepted fallback** — source remains exact and readable, but a consumer
  intentionally uses Advanced Source or readable fallback rather than native
  visual/typeset support. Does not block release.

A certifiable build must have **Critical = 0** and **High = 0**.

## Universal capability corpus

The release gate consumes the existing universal booklet regression corpus
rather than inventing a separate Phase 12 sample set. It contains 49
representative expressions spanning every current `MathSubject` family:

- general mathematics;
- arithmetic;
- algebra;
- trigonometry;
- calculus;
- geometry;
- probability;
- statistics;
- combinatorics;
- number theory;
- complex numbers;
- linear algebra;
- sets;
- logic;
- physics;
- chemistry.

The corpus includes ordinary catalogue entry, fixed templates, runtime dynamic
structures and deliberately documented Advanced Source cases.

## Machine-readable release audit

`MathReleaseCertificationAuditor` certifies each representative expression
against:

1. canonical `MathExpression` JSON persistence;
2. syntax preflight;
3. readable accessibility/safe-failure text;
4. visual authoring route;
5. screen renderer route;
6. PDF route;
7. Word route;
8. Phase 10 resource-budget state.

Native support and accepted fallback are deliberately separate outcomes. A
fallback is only accepted when the source survives unchanged and the consumer
still has a readable, crash-safe route.

## Golden booklet workflow certification

`math_release_export_certification_test.dart` constructs a real paper from the
entire universal corpus and certifies:

- one question per corpus case;
- one canonical formula identity per question;
- Phase 9 validation and repair are deterministic;
- Paper JSON save/reopen preserves formula order and persistent identities;
- Question copy produces independent IDs without changing TeX/plain text;
- PDF generation produces a non-empty booklet;
- Word export produces a real DOCX with native OMML present where supported;
- Smart Paper custom XML is present;
- exact EduSheet DOCX restore succeeds;
- restored formula count, order and TeX exactly match the release corpus.

This is intentionally an end-to-end workflow gate rather than another isolated
parser unit test.

## Cross-surface certification

The final gate retains all prior compatibility guarantees:

- visual editor / Advanced Source;
- screen renderer;
- accessibility text;
- PDF native typesetting + readable fallback;
- Word OMML native typesetting + readable fallback.

A formula may use different rendering strategies on different surfaces, but no
surface may crash, silently drop the formula, or mutate canonical source.

## Persistence and safe-failure certification

Phase 12 re-runs the Phase 9 gates covering:

- malformed TeX;
- malformed Quill embeds;
- stale/orphan Math Everywhere metadata;
- empty formula IDs;
- same-ID/different-payload conflicts;
- future math versions;
- oversized/deep formulas;
- canonical expression-index drift.

Safe failure must preserve recoverable source and select readable fallback
rather than destructive normalization.

## Performance certification

Phase 10 gates remain mandatory:

- 500-question validation corpus;
- repeated formula cache reuse;
- bounded compatibility/export caches;
- parser source/depth/step budgets;
- environment row/column/cell budgets;
- deep nested-question limits;
- repeated PDF + Word native typesetting stress.

No machine-specific stopwatch threshold is used as a release criterion.
Bounded work and deterministic output are the invariant.

## Accessibility and keyboard certification

Phase 11 gates remain mandatory:

- keyboard-only formula commands;
- Tab/Shift+Tab structured navigation;
- screen-reader labels and live status semantics;
- selected category semantics;
- accessible math search;
- reduced-motion behavior;
- responsive nested search layout;
- no focus theft from the active formula field.

## Import/library-identity certification

The Windows `EduSheet` vs `edusheet` library-identity regression remains a
release blocker. The release gate requires:

- files inside `lib/features/math_keyboard/**` use relative self-imports;
- files outside the feature cross into it through
  `package:edusheet/features/math_keyboard/...`;
- third-party `package:math_keyboard/...` remains excluded from the project
  feature guard.

## Complete release command

From the EduSheet project root in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tool/run_math_release_gate.ps1
```

The script fails immediately when any certification stage fails and prints:

```text
MATH RELEASE CERTIFICATION: PASS
```

only after the complete project `flutter test` suite is green.

## Production readiness rule

The math subsystem may be labelled **Production Certified** only when all of
these are true for the same source tree:

- `flutter analyze --no-pub` has zero issues;
- Phase 12 certification audit has zero Critical/High blockers;
- golden universal booklet workflow passes;
- accessibility/productivity gates pass;
- stress/performance gates pass;
- import-identity gate passes;
- PDF/Word + Smart DOCX round-trip gates pass;
- complete math-keyboard suite passes;
- complete paper-composer suite passes;
- complete PDF suite passes;
- complete project `flutter test` passes.

Until then the correct status is **certification pending**, not certified.
