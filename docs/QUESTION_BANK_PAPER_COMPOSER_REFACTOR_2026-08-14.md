# EduSheet Question Bank ↔ Paper Composer Architectural Refactor

Date: 2026-08-14

## Goal

Make Question Bank a reusable teacher-owned source of questions that can be safely inserted into Create Paper, while preserving EduSheet's modern rich question model (Quill text, inline Math, Geometry, marks, answer metadata, tables, attachments, nested questions, and teacher classification).

## Storage and compatibility decisions

- No new database or package was introduced.
- Existing `question_bank.json` remains the Question Bank persistence store.
- Existing `Question` JSON remains the canonical question payload.
- Legacy Question Bank JSON that stored `difficulty` as an integer is still supported.
- New Question Bank wrapper-only metadata is namespaced (`bankSubject`, `bankChapter`, `bankDifficulty`, `bankTags`, `bankCreatedAt`) so it no longer overwrites modern `Question` fields.
- `QuestionType` and `QuestionDifficulty` persisted enum order is unchanged.

## Architecture

### Canonical copy boundary

`QuestionCopyService` is now the single deep-copy implementation used when a reusable/master question becomes an independent paper question or when an existing paper question/section is duplicated.

It rewrites persistent identities for:
- question IDs
- option IDs
- inline Math expression/embed IDs
- Geometry diagram, point, shape, label, and mark IDs
- attachment IDs
- nested sub-question/internal-choice IDs

It preserves semantic data such as marks, negative marks, difficulty, grade, subject, chapter, answer/explanation, tags, accessibility text, table data, source reference, and metadata.

### Question Bank application layer

`QuestionBankApplicationService` owns reusable-question semantics above the repository:
- create a reusable master copy from a paper question
- normalize a bank edit without losing wrapper metadata
- copy one or many masters into a paper
- duplicate-content assistance
- marks totals

The repository remains responsible only for durable JSON storage.

### Unified authoring

The old simplified Question Bank editor was replaced by the same modern `QuestionComposerPage` used by Create Paper. A bank question can therefore use the same:
- rich text
- inline Math composer and keyboard
- Smart Geometry Studio
- OCR text scan
- question type/options
- marks and negative marks
- answers/explanations
- class/subject/chapter/topic
- learning objective/cognitive level/tags/instructions/source metadata

Fields outside the focused draft remain preserved through the existing `Question` seed contract.

## Teacher workflow

### Reuse from Question Bank

1. Open Create Paper.
2. In an empty paper choose **Question Bank**, or in any section choose **Question Bank / From Question Bank**.
3. Search/filter by subject, chapter, difficulty, type, or Favorites.
4. Select multiple questions.
5. EduSheet displays selected question count and marks.
6. If the declared paper maximum would be exceeded, EduSheet warns without blocking an intentional choice.
7. Add the batch.
8. Every imported question is an independent editable copy.

For an empty paper, cancelling the picker does not create an empty Section 1. When questions are selected, Section 1 + the complete batch are created as one undoable document mutation.

### Save a paper question for future reuse

1. Open the question menu.
2. Choose **Save to Question Bank**.
3. If the question/paper already provides a subject, saving is one-tap; missing chapter may safely fall back to General.
4. If no subject can be inferred, EduSheet asks for reusable classification.
5. A similar-question check helps avoid accidental duplicates but never blocks intentional copies.

### Create directly inside the bank

Question Bank's Add action opens the same modern question composer. If the bank is empty while opened from Create Paper, the picker offers **Create bank question** directly rather than forcing the teacher to leave the workflow.

## Picker UX

- Desktop: bounded dialog optimized for large screens.
- Android / compact / free-form: 92% height bottom sheet.
- Current paper subject is preselected when it exists in the bank.
- Current class/grade is a ranking preference, not a hidden hard filter.
- Filters: subject, chapter, difficulty, question type, Favorites.
- Cards use the actual rich question preview, including inline Math and Geometry.
- Multi-select persists across filters.
- Bottom action shows selected count and total marks.

## Correctness fixes included

- Fixed legacy Question Bank serialization that overwrote modern `Question.difficulty` with a wrapper integer.
- Fixed nullable filter clearing in `QuestionBankState.copyWith`.
- Removed double-cloning during Paper Composer import; EditorState owns the canonical copy boundary.
- Batch import into an existing section is one EditorState mutation.
- Empty-paper Section 1 + bank import is also one EditorState mutation/Undo step.
- Old Question Bank picker import path remains as a compatibility export shim.
- Fake/incomplete random-paper/import/export toolbar actions are no longer exposed from the primary Question Bank screen; their old source files were not destructively deleted.

## Tests added/expanded

- Deep-copy IDs for question/options/Math/Geometry/nested questions/attachments.
- Geometry point-reference remapping.
- Two imports of one master remain independent.
- Question Bank master creation and duplicate signature behavior.
- Legacy integer-difficulty JSON compatibility.
- New namespaced Question Bank JSON compatibility.
- Real repository round-trip of advanced modern Question fields.
- Legacy flat JSON import through the repository.
- Nullable Question Bank filters can be cleared.
- Question type filter + Favorites ordering.
- Empty PaperSection exposes both fresh-question and Question Bank actions.
- Existing-section bank batch import is one undoable mutation.
- Empty-paper Section 1 + bank batch import is one undoable mutation.

## Environment QA performed here

The execution environment does not contain Flutter/Dart CLIs, so no claim is made that `flutter analyze` or `flutter test` passed here.

Source-level checks performed:
- all changed/new Dart files passed delimiter-structure scanning
- zero missing local `package:edusheet/...` imports/exports
- no placeholder implementation markers in changed/new Dart files
- `pubspec.yaml` unchanged
- `pubspec.lock` unchanged
- `QuestionType` enum order unchanged
- `QuestionDifficulty` enum order unchanged
- no stale `.effectiveLayout` template references remain in the current full tree

## Recommended validation on Windows

```powershell
flutter analyze
flutter test test/features/editor/question_copy_service_test.dart
flutter test test/features/editor/editor_state_workflow_test.dart
flutter test test/features/question_bank
flutter test
flutter test integration_test/question_creation_journey_test.dart -d windows
```

Manual release scenario:

Create Paper → Question Bank → select a question containing inline Math and Geometry → add it twice → edit Math/Geometry in only the first imported copy → verify second copy and bank master remain unchanged → save another paper question to the bank → save/reopen paper → export Word.
