# EduSheet Question Editor Material Surface Hotfix

## Symptom
Windows debug runs repeatedly reported the Flutter framework assertion:

`ListTile background color or ink splashes may be invisible.`

The diagnostic identified an intermediate `DecoratedBox` with a surface color, outline border and `BorderRadius.circular(18)` around `ListTile` descendants.

## Root cause
`QuestionComposerPage._buildQuestionEditor()` used a colored `Container` / `BoxDecoration` as the question-editor surface. Flutter Quill and related controls can create `ListTile` descendants that paint tile background/ink on their nearest `Material` ancestor. The colored `DecoratedBox` sat between those tiles and the nearest Material, which violates Flutter's Material ink contract and triggers the debug assertion.

## Fix
The question-editor surface is now a shaped `Material` instead of a colored `Container` decoration:

- exact surface color is preserved;
- the 18 px rounded border is preserved;
- validation error border is preserved;
- `surfaceTintColor` is disabled for deterministic appearance;
- `Clip.antiAlias` keeps ink/children inside the rounded surface;
- Quill/ListTile descendants now paint against the correct local Material.

No paper data model, geometry content, export logic, Word Converter Phase 1-5 code, syllabus logic, or database code was changed.

## Regression coverage
Added `test/features/paper_composer/question_editor_material_surface_test.dart` covering both light and dark themes and opening the formatting toolbar. Existing question composer viewport/manual-first tests are also included in the gate.

## Local gate
```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_question_editor_material_surface_hotfix_gate.ps1
```

This environment did not run the Flutter SDK gate. Local analyzer/test output remains the release authority.
