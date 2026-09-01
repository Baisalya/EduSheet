# EduSheet Step 5 — Advanced Content Blocks

Baseline: latest Step 4 QA-fixed project.

## What Step 5 adds

- Passage / poem / case-study / source blocks attached to a question while the prompt remains independently editable.
- Word banks rendered as compact printable blocks.
- Structured table/data authoring with optional header, caption and accessibility summary.
- Image/chart/map attachments with caption and accessibility description.
- Structured child questions `(a)`, `(b)`, `(c)` using the existing question editor recursively.
- Full internal `OR` alternatives with a visible marks-balance warning and minimum-two validation.
- Per-question answer-space override: blank, ruled, box or graph.
- Recursive Preview, PDF and Word rendering for nested question structures.
- Question image embedding in PDF and Word export, including nested questions.
- Existing `Question` / `Paper` storage remains the persistence contract; advanced source/word-bank/answer-space data is namespaced under `Question.metadata['smartPaperContentV1']` so unrelated metadata remains untouched.
- No new database schema and no new package dependency.

## Math keyboard integration

All new teacher-editable advanced text surfaces use EduSheet's existing `MathKeyboardField` session rather than a second keyboard implementation:

- passage/source heading and body
- word bank
- table headers and cells
- table caption and accessibility summary
- image caption and accessibility description

Nested sub-questions and OR alternatives already open the normal `QuestionComposerPage`, so they inherit the full existing Math / Geometry / cursor workflow.

## QA added

- advanced metadata round-trip / legacy metadata preservation
- UniversalQuestionDocument block mapping
- answer-space precedence and internal-choice marks helpers
- preview rendering for source, word bank, table, sub-parts and OR
- Word export structural assertions for advanced blocks
- PDF export smoke coverage for advanced blocks
- math-keyboard wiring coverage for the new advanced text editors
- existing manual-first Add menu test extended with all Step-5 actions

## Static checks run in this environment

- `git diff --check` — clean
- all changed `package:edusheet/...` imports resolve to real project files
- delimiter/bracket scan across changed Dart files — clean
- no merge-conflict markers or placeholder-code markers found
- ZIP integrity will be verified after packaging

Flutter/Dart executables are not installed in this execution environment, so `dart format`, `flutter analyze`, and `flutter test` could not be executed here. Run them on the development machine before locking the phase.

## Run after applying

```powershell
dart format .
flutter analyze
flutter test
```

Recommended manual QA on Android/phone:

1. Create a normal question and add Passage/Case study; switch the passage field to Math Keyboard and insert a symbol/formula fragment.
2. Add a word bank containing normal text and math symbols.
3. Create a table and enter math in a header and a cell.
4. Attach an image, add caption/description, then edit it again.
5. Add `(a)`, `(b)`, `(c)` structured parts and verify each opens the normal question composer.
6. Add two OR alternatives with equal marks, then deliberately make marks unequal and confirm the warning.
7. Add a question-level graph/ruled/box answer area and verify Preview, PDF and Word.
8. Re-open the saved paper/question-bank item and confirm all blocks remain editable.
