# Phase 7 — Math Everywhere in a Question

## Goal

Carry real `MathExpression` objects beyond the rich question body without
changing EduSheet's persisted database schema or pretending legacy string fields
can natively store widgets.

## Existing boundary

The question body already stores `MathExpression` as Quill embeds and also keeps
the canonical `Question.mathExpressions` list. The following surfaces are
legacy strings:

- answer options
- stimulus title and text
- word-bank items
- table caption, headers and cells
- attachment captions
- question instructions
- correct answer
- explanation

Nested subquestions and internal choices are full `Question` objects, so each
nested question owns its own Phase-7 math-surface metadata instead of sharing a
flat parent registry.

## Storage contract

Phase 7 uses the existing `Question.metadata` map under the namespaced key:

`smartPaperMathSurfacesV1`

Each surface stores an ordered sequence of text parts and `MathExpression`
parts. The ordinary legacy string remains a readable compatibility fallback.
No database column, migration, package, or `Question` JSON field is added.

## Stale-content safety

A structured surface is active only when its generated readable fallback equals
the current legacy string. If an older/plain editor changes that string, the
structured document is ignored immediately and is removed when the question is
saved through `QuestionDraft`.

This prevents a formula from silently becoming attached to unrelated edited
text and keeps old editors forward-compatible.

## Authoring

The question composer exposes **Math in fields**. It discovers the surfaces
that currently exist in the draft and lets a teacher build each field from
ordered text and formula parts using the existing Formula Editor.

Saving a structured field updates all three compatibility layers:

1. its rich namespaced metadata document,
2. its readable legacy string fallback, and
3. the deduplicated canonical `Question.mathExpressions` inventory.

Surface-owned expressions are excluded from the legacy-unplaced formula tray, so they are not rendered a second time below the question body.

## Rendering and export

`PaperPreviewPage` uses `QuestionMathSurfaceView` for student-visible Phase-7
surfaces. Each embedded expression passes through `SafeMathExpression`, so the
Phase-6 renderer compatibility policy remains authoritative.

PDF and Word continue to consume the ordinary readable string fallback until
the dedicated typeset export phase. This means Phase 7 does not claim OMML or
PDF equation typesetting support prematurely.

## Question Bank

Question Bank already persists the complete modern `Question` JSON payload.
Phase-7 metadata therefore round-trips without a Question Bank schema change.

## Regression gates

- structured surface JSON round-trip
- readable legacy fallback preservation
- stale metadata fencing after plain-string edits
- option/table/details surface discovery
- nested-question ownership
- Question Bank preservation
- screen preview chooses structured math only when fallback matches

## Word Mode

Word Mode keeps its ordinary string editors as the compatibility editing
surface, but every read/preview path for a supported question field now uses
`QuestionMathSurfaceView`. Active structured math is therefore typeset in:

- instructions
- stimulus title/text
- options (as a live structured preview below the editable fallback)
- word-bank items
- table caption/headers/cells
- attachment captions
- nested-question read-only surfaces

Plain editing remains authoritative: changing the readable fallback fences out
stale structured metadata through `QuestionMathSurfaceService.reconcileQuestion`.

## Copy / duplicate identity safety

Question copies regenerate option, attachment and math-expression IDs. Phase 7
remaps the namespaced math-surface registry through those ID maps, and drops
surfaces whose referenced option/attachment no longer exists. This keeps
Question Bank duplication and paper-copy workflows from producing orphan math
metadata.

## Additional regression gates

- Word Mode structured-surface rendering without replacing editable fallback
- structured-only preview stays hidden when no active metadata exists
- option/attachment/math-expression ID remapping during deep copy
- stale/orphan surface removal during copy/reconciliation
