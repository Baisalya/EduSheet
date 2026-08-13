# EduSheet Paper Composer, Question Authoring, Math and Geometry Refactor

Date: 2026-08-13

## Goal

Replace the legacy Create Paper and content-template authoring experience with a focused, responsive teacher workflow for Windows and mobile. The rewrite keeps the existing persisted `Paper`, `PaperSection`, `Question`, `MathExpression`, `GeometryDiagram`, autosave, repository, PDF and Word contracts rather than introducing a parallel schema.

The primary teacher loop is now:

1. Open/create a paper.
2. Write a question immediately.
3. Insert mathematics or geometry from separate first-class actions.
4. Set marks/question type only when needed.
5. Save and continue to the next question.

## Architecture

A new `features/paper_composer` feature owns the authoring presentation and application layer. The public `CreatePaperScreen` remains as a compatibility route but delegates to `PaperComposerScreen`.

Key boundaries:

- `PaperComposerActions` coordinates paper-level mutations through the existing editor state.
- `QuestionDraft` is an editing projection of the existing persisted `Question`; it is not a replacement storage model.
- `QuestionDetailsDraft` isolates optional teacher metadata from the primary writing flow.
- `QuestionRichTextCodec` owns Quill JSON decoding/encoding and accessible fallback text.
- responsive presentation is split across paper shell, outline, section cards, question cards, inspector, style/details sheets and the focused Question Composer.

The legacy 4,857-line Create Paper implementation is no longer active. `CreatePaperScreen` is now a small compatibility wrapper and the new responsibilities are distributed across dedicated components.

## Responsive authoring

### Compact/mobile

- Single focused document surface.
- Outline and paper settings use sheets instead of persistent sidebars.
- Large question creation actions and touch targets.
- One-tap blank-paper action creates the first section internally and opens Question 1.
- Question Composer keeps Math, Formula and Geometry immediately reachable.
- Save actions are padded above the global math keyboard overlay so they remain reachable while formula input is open.

### Expanded/Windows

- Persistent paper outline.
- Central document/question workspace.
- Contextual inspector.
- Undo/redo and save/preview/export actions remain visible without forcing desktop controls onto compact layouts.
- Outline navigation uses stable section/question anchors and scrolls to the actual selected question.

## Question Composer

The old `QuestionEditorSheet` has been removed and replaced by a focused `QuestionComposerPage`.

Primary authoring features:

- Quill rich-text question body using the existing stored delta format.
- quick question-type selection.
- marks editing.
- optional/internal-choice toggle where supported by the existing model.
- MCQ/multiple-select/True-False option editing.
- Math keyboard insertion.
- Formula block insertion/editing through the existing `MathExpression` and visual renderer.
- Geometry insertion through the existing `GeometryDiagram` custom Quill embed format.
- Save and Save & next.
- optional Answer & more details sheet.

### Advanced details kept out of the main flow

The following existing persisted fields remain editable without cluttering the primary writing surface:

- correct/model answer.
- explanation.
- negative marks.
- estimated answer minutes.
- difficulty.
- class/grade.
- subject, chapter and topic.
- learning objective.
- cognitive level.
- tags.
- language.
- question-specific instructions.
- source/reference.

Edits to core fields preserve advanced fields, attachments, table data, nested questions/internal choices, image URLs, math expressions, metadata and other untouched persisted data.

## Question type policy

All existing enum values remain storage-compatible, but the new creation picker deliberately advertises only types that the focused composer can author honestly without fabricating unsupported nested structures.

Creation-ready types include:

- MCQ.
- descriptive.
- fill in the blanks.
- multiple select.
- True/False.
- one word.
- short answer.
- long answer.
- numerical.
- mathematical expression.
- assertion/reason.
- image/diagram.
- custom.

Existing papers containing matching, passage, sub-question, table, internal-choice or case-study structures remain loadable/preservable. Those types are not falsely presented as fully structured new-question editors until their dedicated structure authoring UI exists.

## Mathematics

The previously refactored smart math keyboard is reused; no second keyboard implementation was introduced.

- Math is a direct action in Question Composer.
- Formula blocks use the existing `MathExpression` model.
- Formulas render visually rather than forcing teachers to work in raw TeX during normal authoring.
- The same global keyboard controller/adapters remain responsible for compatible text/Quill/math-field insertion.
- recent-symbol preference failures are non-fatal, so optional local preference storage cannot prevent Create Paper from opening.

## Geometry Studio

Math and Geometry are separate authoring tools.

The existing `GeometryDiagram`, controller, painter and serialization format were retained. A categorized teacher-facing catalog and quick picker were added rather than inventing a second geometry schema.

All 21 currently persisted/rendered `GeometryShapeType` values are exposed exactly once:

1. line
2. arrow
3. triangle
4. right triangle
5. square
6. rectangle
7. circle
8. semicircle
9. parallelogram
10. trapezium
11. rhombus
12. pentagon
13. hexagon
14. coordinate axes
15. number line
16. cube
17. cuboid
18. cylinder
19. cone
20. sphere
21. polygon

They are organized into teacher-friendly families: Lines, Triangles, 4-sided, Polygons, Circles, Graphs and 3D.

The Geometry Studio continues to use the project’s existing creation templates, point manipulation, labels, marks, undo/redo and serialization. Geometry insertion uses the same existing Quill custom-embed payload, preserving renderer/export compatibility.

## Template rewrite

The old content-template authoring subsystem (`QuestionTemplate`, `SectionTemplate`, `PaperBlueprint`, content template picker/repository/clone service) has been removed from active source.

The old large PDF template designer/selector presentation has also been removed.

The persisted/export `PaperTemplate` contract and template repository are retained because saved papers and renderers depend on `templateId` and template settings.

The authoring replacement is deliberately simpler:

- `PaperStyleSheet` chooses an existing print style without touching question content.
- `PaperStyleEditorSheet` creates/edits a style through existing supported `PaperTemplate` fields such as page size, layout, header layout, border and font sizes.
- advanced page-layout persistence/export remains on the existing domain/repository path rather than being rewritten as a new incompatible format.

## Paper setup

The new Paper Details sheet uses existing editor/header-field operations for:

- title.
- school.
- subject.
- class.
- time/duration.
- maximum marks.
- general instructions.

A missing optional header field is not created merely to store an empty value.

## Removed legacy presentation/subsystem files

The refactor removes the old question editor, content-template authoring subsystem, legacy template designer/selector/preview and their obsolete tests. The modified-files package includes a `DELETED_FILES.txt` manifest so these removals are explicit when applying the patch manually.

## QA implemented

New/reworked automated test sources cover:

- `QuestionDraft` data preservation.
- question-type transitions, including True/False semantics.
- rich-text codec behavior.
- new-question type picker policy.
- compact and expanded Paper Composer surfaces.
- first-question creation flow.
- focused Question Composer actions.
- geometry catalog coverage.
- geometry template creation + serialize/deserialize across every `GeometryShapeType`.
- repository save/restore coverage for persisted question types in the integration journey.

Source-level release checks performed in this environment:

- 0 missing local `package:edusheet/...` imports across `lib`, `test` and `integration_test`.
- 0 remaining Dart references to the removed `features/templates` subsystem, `QuestionEditorSheet`, `TemplateSelector`, `TemplateDesignerScreen` or old template header preview.
- 0 TODO/FIXME/`UnimplementedError`/placeholder markers in the new paper-composer and geometry catalog/picker implementation.
- delimiter scan across all changed Dart files reports 0 unmatched/mismatched brackets/braces/parentheses.
- geometry catalog covers all 21 shape enum values exactly once, with no missing, duplicate or extra shape types.
- no dependency was added; `pubspec.yaml` is unchanged by this refactor.

## Environment limitation

The execution container does not contain a Flutter/Dart SDK, so `flutter analyze`, `flutter test` and device rendering tests could not be executed here. Source-level checks and test implementation are complete, but the following commands remain the required SDK-level verification on a Flutter development machine:

```bash
flutter pub get
flutter analyze
flutter test
flutter test integration_test/question_creation_journey_test.dart
```

Do not treat this report as a claim that Flutter analyzer/device tests passed; they require the local SDK run above.
