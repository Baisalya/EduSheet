# Math Keyboard Phase 9 — Strong Validation + Safe Failure

## Goal

Phase 9 turns math validation from a single-formula syntax check into an
end-to-end integrity boundary for EduSheet questions and booklet exports.
Invalid or partially corrupt math must never crash authoring, silently attach to
the wrong field, leak raw TeX into output, or disappear because two records
happened to share an ID.

## Validation layers

### 1. Formula safety report

`MathSafetyValidationService` produces typed issues with:

- severity (`info`, `warning`, `error`);
- stable issue code;
- safe-failure action;
- consumer path;
- persistence-blocking status.

Malformed-but-readable TeX is preserved. Screen/PDF/Word consumers use the
Phase 6 readable fallback when their native parser/compiler rejects the source.
An empty source is the only formula state that cannot remain a math object.

### 2. Persistent math identity

`MathExpression.persistentIdentity` is the stored ID plus the complete formula
payload. Dedupe and copy boundaries no longer collapse two different formulas
merely because corrupted/imported data reused an ID.

`MathExpression.payloadIdentity` keeps the complete payload distinct from the
stored ID so Phase 9 can detect and repair an ID conflict deterministically.
Nested metadata maps are canonicalized by sorted keys before identity comparison,
so JSON key ordering cannot create a false formula conflict. Legacy-unplaced math
in both Question Composer and Word rich-text editing is tracked by this same
persistent identity rather than ID alone.

### 3. Rich-text body inspection

`QuestionRichTextCodec.inspectQuestion` distinguishes:

- valid Quill delta;
- legacy plain text;
- malformed rich-text JSON;
- malformed EduSheet math embeds.

Malformed math embeds are replaced in the safe working copy with `[formula]`
rather than reaching the Quill embed builder as corrupt payloads. Legacy plain
text remains supported.

### 4. Question integrity validation

`QuestionMathValidationService` validates and repairs a copy of each question:

- body math embeds;
- Phase 7 Math Everywhere surfaces;
- canonical `Question.mathExpressions`;
- sub-questions;
- internal choices.

It detects:

- malformed rich text;
- malformed math embeds;
- malformed math-surface metadata;
- stale surface documents after a plain-text edit;
- orphan surfaces after option/attachment/structure deletion;
- empty math IDs;
- one ID referring to different formula payloads;
- placed formulas missing from the canonical math index;
- duplicate canonical entries;
- malformed TeX;
- future math format versions.

### 5. Deterministic ID repair

Empty IDs and conflicting IDs receive deterministic `math.safe.<hash>` IDs.
The repair is performed against the exact location and payload. TeX is never
rewritten during ID repair.

### 6. Safe persistence and workflow boundaries

Validation is applied at:

- Question Composer load/edit boundary;
- Question Composer save boundary;
- Paper Composer save action;
- Question Bank insertion into a paper;
- Smart DOCX round-trip restore/merge;
- PDF generation;
- Word/DOCX generation.

The original object is not mutated. Consumers receive a safe copy.

### 7. Copy safety

`QuestionCopyService` now maps math by full persistent identity rather than ID
alone. A damaged source containing two different formulas with the same ID can
therefore be copied without one payload hijacking the other.

## Safe failure policy

| Failure | Stored source | Screen | PDF | Word | Structural action |
| --- | --- | --- | --- | --- | --- |
| Malformed TeX + fallback | preserved | fallback | fallback/native as supported | fallback/native as supported | none |
| Empty formula source | not kept as math | readable marker/text | readable text | readable text | drop empty math object |
| Malformed Quill math payload | unreadable payload not executed | `[formula]` | `[formula]` | `[formula]` | normalize safe delta |
| Stale Math Everywhere surface | legacy text preserved | legacy text | legacy text | legacy text | detach stale metadata |
| Orphan surface | other question content preserved | unaffected | unaffected | unaffected | detach orphan metadata |
| Duplicate ID / different payload | both formulas preserved | native/fallback per formula | native/fallback per formula | native/fallback per formula | reassign conflicting ID |
| Missing canonical mirror | placed formula preserved | unaffected | unaffected | unaffected | rebuild canonical index |
| Future format version | preserved verbatim | native/fallback probe only | native/fallback probe only | native/fallback probe only | no destructive conversion |

## Storage and dependency contract

- No database migration.
- No new package dependency.
- Existing `MathExpression` JSON schema remains compatible.
- Phase 7 math-surface metadata key remains unchanged.
- Phase 8 PDF/OMML typesetting remains the native export path.

## Regression gates

Focused tests:

```powershell
flutter test test/features/math_keyboard/math_safety_validation_service_test.dart
flutter test test/features/paper_composer/question_math_validation_service_test.dart
flutter test test/features/editor/question_copy_service_test.dart
flutter test test/features/paper_composer/question_rich_text_codec_test.dart
flutter test test/features/pdf
flutter test test/features/math_keyboard
```

Full gate:

```powershell
flutter analyze --no-pub
flutter test
```
