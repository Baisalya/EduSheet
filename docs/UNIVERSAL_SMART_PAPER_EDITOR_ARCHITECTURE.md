# Universal Smart Paper Editor architecture

## Product rule

EduSheet is a manual-first question-paper editor for phones. A teacher should be
able to type the paper in the format they already know, while EduSheet removes
the painful parts: mathematical input, repeated labels, answer choices, marks,
diagrams and export formatting.

The editor must not force a teacher to classify every visible paper pattern as
one mutually-exclusive `QuestionType` before they can write it.

## Compatibility boundary

`Question` in `features/editor/domain/models/paper_model.dart` remains the
persisted storage contract. Step 2 does **not** create a parallel database or a
new saved-paper schema.

The Universal Smart Paper Editor adapts the existing independent fields into a
composable authoring document:

- rich question prompt / ordinary text
- answer options
- attachments / diagrams
- table data
- sub-questions
- internal choices

`QuestionType` remains a legacy classification and semantic/export hint. It no
longer owns or deletes structural content in `QuestionDraft`.

## Authoring model

`UniversalQuestionDocument` is a storage-independent list of content blocks.
`UniversalQuestionAdapter` maps the current `QuestionDraft` into that view. This
is intentionally an adapter first: existing papers and the Question Bank stay
compatible while later phases can move Preview/PDF/Word to the same normalized
rendering model.

## Mobile workflow

The default workflow is:

1. Tap the question and type freely.
2. Tap Math for formula input at the current caret.
3. Tap Add only when a helper is useful.
4. Insert ordinary editable paper text for blanks, `(a)/(b)/(c)` parts,
   `OR`, and instruction lines.
5. Add structured answer options when answer semantics are useful.
6. Use Quick start only as an optional helper; it never locks the layout.

The first Add menu intentionally exposes only actions that are fully supported
by the current editor. Table/image/passages remain future additions rather than
buttons that pretend to work.

## Non-negotiable invariants

- Changing a quick-start classification must never silently delete composed
  content.
- Math and geometry insertion use the captured caret/range.
- Existing advanced fields survive round-trips through `QuestionDraft`.
- Saved `Question` JSON remains backward compatible.
- Preview/export behavior is not silently changed in this step.

## Next architecture step

Step 3 should build the focused mobile authoring experience on top of this
foundation: stronger caret/insertion feedback, contextual bottom actions,
manual section/group/instruction blocks, and fully-editable table/media
components. Preview/PDF/Word normalization remains a later explicit rendering
phase so authoring changes cannot accidentally alter printed papers.
