# EduSheet Step 3 — Mobile Smart Authoring UX

Baseline: `EduSheet_Step2_QA_Fix2_Full.zip`

## Goal

Make question authoring on a phone behave like a small purpose-built paper
editor: the teacher taps where content belongs, sees where the next action will
land, and can keep Add / Math / Geometry / Format available without scrolling
back to a toolbar.

## Architectural changes

### Stable insertion anchor

Added `QuestionInsertionAnchor` as a UI-independent snapshot of the rich-text
selection. It records the normalized insertion range plus teacher-readable line
and position information.

Transient UI no longer decides insertion position after focus has moved. The
composer captures the question cursor before opening Add, Formula, Geometry or
OCR and applies the requested result at that captured position. Focus-loss
selection churn is ignored while the teacher is inside a sheet/route.

### Cursor / insertion feedback

The question editor now shows a live status pill such as:

- `Typing here · line 2, pos 7`
- `Cursor saved · line 2, pos 7`
- `5 selected · line 2`

Tapping the pill restores the saved question selection.

The Add sheet also shows the exact destination before the teacher chooses a
helper, including whether selected text will be replaced.

### Sticky mobile authoring toolbar

On compact layouts the main authoring tools are now pinned above the save bar:

- Add
- Math
- Geometry
- Format
- Undo
- Redo

The toolbar carries a `Question tools use: ...` cursor status and a Return
action. The old inline tool row remains on wider desktop layouts. When the
custom math keyboard is visible, the sticky authoring row collapses so short
viewports are not consumed by two stacked tool surfaces.

### Contextual formatting and history

`Format` opens the existing rich-text formatting surface without losing the
question selection. Undo/Redo use the Quill document history and return focus
to the question.

### Mid-document helper correctness

Blank, Sub-question, OR and Instruction helpers now respect the text *before
the saved insertion point* when deciding line breaks. This fixes Word-like
mid-question insertion instead of assuming every helper is appended at the end.

## Tests added / extended

- `question_insertion_anchor_test.dart`
- `question_mobile_authoring_session_test.dart`
- extended `question_authoring_text_tools_test.dart`

The new widget regression writes `Alpha\nBeta`, places the caret inside `Beta`,
opens the Add sheet, and verifies a blank is inserted at that exact saved
position rather than at the end of the question.

## Local verification required

This execution environment does not contain Flutter/Dart. Run on the project
machine:

```powershell
dart format .
flutter analyze
flutter test
```

Step 2 had already reached `flutter analyze: No issues found`; Step 3 should not
be considered QA-locked until the commands above pass on the user's Flutter
installation.
