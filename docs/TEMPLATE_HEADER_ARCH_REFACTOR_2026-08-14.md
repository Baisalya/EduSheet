# EduSheet Template + Header Architecture Refactor — 2026-08-14

## Scope

This refactor rebuilds the paper-template/header workflow around a teacher-first model:

- **Paper Setup** owns paper information.
- **Appearance** owns print styling.
- Selecting a style must not create/delete/change paper data.
- Existing saved `PaperTemplate`, `HeaderLayout`, `PaperLayout`, `PaperSize`, `CustomLayout`, paper header fields, logos and template IDs remain compatible.
- No dependency or database/storage schema was added.

## Baseline problems verified in code

The previous implementation mixed several responsibilities in `paper_template.dart`: persisted model/enums, predefined templates and hundreds of lines of layout geometry. It also had several behavior/correctness issues:

1. New papers used `school_formal`, but the predefined catalog did not contain that ID.
2. Choosing a template mutated the paper by adding header fields/logo slots/static data.
3. PDF generation had multiple header-builder classes even though the service always selected `CustomHeaderBuilder`.
4. `saveAsCustom()` did not preserve `paperSize`.
5. Maximum marks were resolved inconsistently across views/renderers.
6. The Flutter paper preview did not represent the chosen print style.
7. New papers invented Mathematics / Class 10 / 3 Hours values.
8. The visible preset catalog used institution/board-branded names that implied affiliation.

## New architecture

### Data-only template model

`lib/features/pdf/domain/models/paper_template.dart`

`PaperTemplate` is now a small persisted data model. Persisted enum order is unchanged:

- `TemplateType { school, college, coaching, kids, board }`
- `HeaderLayout { centered, logoLeft, logoRight, modernCoaching, minimal, academic, ssvm, dps, custom }`
- `PaperLayout { standard, twoColumn }`
- `PaperSize { a4, a5, a3, letter, legal }`

The old `effectiveLayout` implementation and built-in catalog were removed from the domain model.

### Application policy layer

New files under `lib/features/pdf/application/`:

- `paper_style_catalog.dart`
- `paper_template_resolver.dart`
- `paper_header_layout_factory.dart`
- `paper_header_profile.dart`
- `paper_marks_resolver.dart`

These separate style discovery, legacy compatibility, layout generation, optional metadata suggestions and marks semantics.

### One header renderer

`CustomHeaderBuilder` is now the single PDF header renderer. The unreachable parallel header builders were removed. It consumes `PaperHeaderLayoutFactory` so built-ins/custom styles follow one rendering path.

### One Paper Setup transaction

Saving Paper Setup now calls `EditorState.applyPaperSetup(...)`, applying title, institution, instructions, logos, maximum marks and header fields in **one state mutation**. This makes autosave/undo semantic: one Paper Setup save = one Undo step.

Persistent IDs for newly-created header fields are assigned inside the editor provider, not by the presentation widget.

## Professional teacher-facing preset catalog

Visible presets are intentionally neutral and use-case based:

1. School Formal
2. School Compact
3. Board Exam Classic
4. Board Exam Structured
5. University Semester
6. Institutional Modern
7. Minimal Print
8. Coaching Mock
9. Primary Friendly
10. Primary Worksheet

The main chooser does not expose branded/"official" names.

### Legacy IDs retained

Old persisted IDs remain resolvable for saved papers but are hidden from the normal chooser:

- `school_ssvm_style`
- `school_dps_style`
- `school_xavier_style`
- `coaching_allen`
- `coaching_akash`
- `kids_cartoon`

Existing non-legacy IDs are also preserved, including `school_modern_left`, `board_cbse`, `board_icse`, college, coaching and kids IDs. Internal IDs are compatibility keys; visible names are neutral.

## Paper Setup UX

The new Paper Setup sheet prioritizes:

- School / institution
- Exam / paper title
- Subject
- Class / grade
- Duration
- Maximum marks
- Optional school logo

Advanced/less common metadata is under **More details**:

- Date
- Student name line
- Roll number line
- arbitrary additional header fields
- style-family suggestions such as Semester, Course Code, Paper Code, Set or Batch

General-instruction chips are optional helpers only; nothing is silently inserted.

### Smart marks feedback

`PaperMarksResolver` is the single source for effective maximum marks and mismatch status.

Examples:

- Declared 80, assigned 76 → `4 marks are not assigned yet.`
- Declared 80, assigned 84 → `Question marks exceed maximum marks by 4.`
- No declared maximum → current question total is the effective maximum.

The Paper Setup status reacts while the teacher edits the maximum-marks field.

## Appearance UX

The Appearance sheet is organized by teacher intent:

- Recommended
- School
- Board-style
- College
- Mock test
- Primary
- My styles

Each card renders a miniature preview from the **actual resolved layout definition**, not an unrelated decorative thumbnail.

One tap applies a style and closes the chooser. Paper content is unchanged.

## Custom appearance editor

Normal controls:

- Page size
- Single/two-column questions
- Header arrangement
- Compact / Normal / Large question text
- Border

Advanced controls:

- centered heading
- exact header size
- exact question size

Windows receives controls + live preview side-by-side at wide widths; compact layouts stack them.

Existing custom `HeaderLayout.custom` layouts remain previewable/editable instead of being silently converted to a built-in layout.

## Preview/export consistency

### Header

Flutter preview, PDF and Word resolve header geometry through `PaperHeaderLayoutFactory`.

Built-in layouts expand vertically when the teacher adds enough metadata fields so additional rows do not collide with marks/dividers.

PDF and Word render header fields deterministically in two-column rows.

### Paper preview

`PaperPreviewPage` now reflects:

- selected header geometry
- template border
- template question font size
- A5/A4/A3/Letter/Legal relative preview width
- single/two-column question flow
- effective/assigned marks feedback

This makes Appearance changes visible before final PDF export.

## Correctness fixes

- `school_formal` is now a real built-in default.
- New papers no longer invent subject/class/duration values.
- New papers no longer pre-create empty logo slots.
- `TemplateNotifier.saveAsCustom()` preserves `paperSize`.
- Unknown/missing template IDs fall back centrally to School Formal.
- Style selection no longer adds/removes header fields or logos.
- Effective maximum marks are centralized.
- PDF header metadata rows match layout expansion assumptions.
- Word odd metadata rows receive an empty second cell for stable table geometry.
- Custom appearance preserves saved custom layout data where available.

## Compatibility guarantees

Unchanged persisted contracts:

- `Paper.templateId`
- `Paper.headerFields`
- `Paper.logos`
- `Paper.customHeaderValues`
- `Paper.maximumMarks`
- `PaperTemplate` persisted fields
- enum ordering/index persistence
- `CustomLayout` JSON

No `pubspec.yaml` or `pubspec.lock` changes were made.

## Automated regression coverage added/updated

New/updated tests cover:

- stable real default template
- unique built-in IDs
- neutral visible preset names
- legacy template ID resolution while hidden
- every persisted `HeaderLayout` resolving
- custom-layout compatibility
- built-in header expansion with additional metadata
- unknown template fallback
- marks under/over assignment messages
- custom clone preserving Legal page size, two-column mode and header layout
- neutral new-paper defaults
- Paper Setup as one undoable document mutation
- existing Create Paper Windows inspector labels (`Paper setup`, `Appearance`)

## Source-level QA completed in this environment

The container does **not** include Flutter or Dart SDK executables, so `flutter analyze` / `flutter test` cannot be executed here.

Checks performed locally on the source tree:

- no missing local `package:edusheet/...` imports
- changed-Dart delimiter/structure scan clean
- no stale `effectiveLayout` or `predefinedTemplates` references
- no stale unreachable old header-builder class references
- no visible old branded preset strings
- old predefined template IDs all retained
- persisted enum order compared with baseline and unchanged
- no new TODO/FIXME/`UnimplementedError` placeholders in changed template/paper-setup code
- `pubspec.yaml` unchanged
- `pubspec.lock` unchanged

## Required Flutter gate on developer machine

Run:

```powershell
flutter analyze
flutter test
flutter test integration_test/question_creation_journey_test.dart -d windows
```

Recommended manual QA:

1. New Paper → Paper Setup; verify Subject/Class/Time begin blank.
2. Enter institution/title/subject/class/time/marks and save; Undo should restore the previous setup in one step.
3. Appearance → switch among School Formal, Board Exam Classic, University Semester, Coaching Mock and Primary Friendly; verify paper data never changes.
4. Add Date, Student Name, Roll No and 3+ custom fields; verify preview/PDF header expands without collision.
5. Create a custom Legal + two-column style; save/reopen and verify page size/layout survive.
6. Open an old paper using each legacy template ID; verify it resolves and exports with neutral styling.
7. Test 320–390 px Android widths, Android landscape/free-form, tablet, Windows normal/maximized and display scaling.
