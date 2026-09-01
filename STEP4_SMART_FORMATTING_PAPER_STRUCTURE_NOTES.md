# EduSheet Step 4 — Smart Formatting & Paper Structure

Baseline: Step 3 QA-fix project.

## Scope implemented

- Section-level structure editor (`Section format`) with:
  - optional prefix (Group A / Part I style)
  - Answer all / Answer any N
  - per-section numbering override
  - default marks for newly created questions
  - show/hide section title
  - section divider
  - start section on a new page
  - plain / ruled / graph answer-space reservation
- Drag/reorder support for sections and questions.
- Section default marks flow into new-question creation without changing existing questions.
- MCQ option paper layouts: Vertical, 2 columns, Inline.
  - stored in existing `Question.metadata` for backward compatibility
  - no database/schema migration
- Shared `PaperStructureService` used to resolve numbering and answer-any text.
- Preview updated for:
  - section numbering overrides
  - answer-any instruction
  - option layouts
  - answer spaces
  - section divider
- PDF and Word export updated to use the same paper-structure settings where supported.
- Existing `keepTogether` is deliberately not exposed because exporters do not yet guarantee that behavior consistently.

## QA added

- `paper_structure_service_test.dart`
- `question_option_layout_test.dart`
- `paper_section_smart_formatting_test.dart`
- `question_smart_formatting_controls_test.dart`
- export regression coverage extended in `office_export_services_test.dart`

## Structural checks performed in this environment

- 17 Dart files changed/added.
- All `package:edusheet/...` imports in changed files resolve locally.
- Delimiter/bracket scan on changed Dart files is clean.
- No merge-conflict markers or placeholder-code markers found.
- `git diff --check` is clean.
- ZIP integrity verified after packaging.

## Runtime validation still required on a Flutter machine

This environment does not provide Flutter/Dart executables, so no claim is made that `flutter analyze` or `flutter test` passed here.

Run:

```powershell
dart format .
flutter analyze
flutter test
```

Then manually verify on phone-sized layout:

1. Create Section A, open **Section format**.
2. Set `Answer any 3`, lower-alpha numbering, default marks `2`.
3. Add a new question and confirm marks start at `2`.
4. Add MCQ options and switch Vertical / 2 columns / Inline.
5. Reorder questions and sections using drag handles.
6. Set ruled or graph answer space and inspect Preview.
7. Export PDF and Word and compare numbering, section instruction, option layout, page break, and answer-space behavior.
