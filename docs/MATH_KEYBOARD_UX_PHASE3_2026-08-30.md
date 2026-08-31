# Math Keyboard UX Phase 3 — Teacher Authoring Flow

Date: 2026-08-30

## Goal

Reduce interaction friction when teachers add mathematics in Create Paper and Question Bank without changing EduSheet's persistence model, `MathExpression`, repositories, or Question Bank schema.

## Architecture change

`MathKeyboardView` now owns a single keyboard-local panel state machine:

- `keys`
- `categories`
- `structures`
- `symbolActions`
- `shapes`

This replaces one-off local booleans and removes secondary modal routes for category browsing, symbol actions, and shape picking. Search intentionally remains a keyboard-local bottom sheet because its `TextField` needs the system text keyboard.

## Teacher-facing changes

### Build

A persistent **Build** entry is placed at the front of the Quick ribbon. It opens an in-keyboard authoring panel with canonical catalogue-backed structures:

- Fraction
- Square root
- Power
- Subscript
- Absolute value
- Integral
- Summation

Each structure has plain-language guidance for where typing begins and when **Next box** should be used.

### Ready formulas

The Build panel also surfaces existing `MathCategory.templates` entries as a **Ready formulas** lane. No formula strings were invented in the UI; the lane reads the existing `MathSymbolCatalog` and provides **See all** to the full formula category.

### Key actions

Long-press no longer creates another modal. It opens an in-keyboard **Key actions** panel for:

- inserting the selected key,
- adding/removing favourites,
- selecting existing variations.

The same action is available by right-click on Windows. Quick-ribbon keys and full-grid keys now behave consistently.

### Shapes

The old Shapes popup inside the formatting keyboard has also been converted to a keyboard-local panel. Search is now the only remaining separate math-keyboard sheet.

## Safety / compatibility boundaries

Unchanged:

- `MathExpression` model and serialized representation
- Question/Paper repositories
- Question Bank repositories
- Quill inline math embed schema
- generated Riverpod files
- existing symbol catalogue identities
- existing formula template data

The Build UI resolves existing symbols through `MathSymbolCatalog.findByTex`; missing catalogue entries are skipped rather than fabricated.

## QA added

### Widget / session regression

`test/features/math_keyboard/formula_editor_sheet_test.dart`

- Build panel stays inside the keyboard Navigator.
- Fraction insertion returns to normal keys and keeps the math session active.
- Key actions stay local rather than pushing another route.
- Favourites can be changed from the local action panel.
- Existing Phase 2 category/focus regression remains covered.

### Catalogue contract

`test/features/math_keyboard/math_teacher_build_catalog_test.dart`

- Every promoted Build structure resolves to a real canonical catalogue entry.
- Every Build structure remains marked structural.
- Ready-formula data comes from formula-template catalogue entries.

`test/features/math_keyboard/math_keyboard_controller_build_test.dart`

- Build insertion cancels temporary power/subscript modes.
- Build inserts immediately rather than leaving a hidden one-key mode active.

### Create Paper authoring

`test/features/paper_composer/question_composer_typing_viewport_test.dart`

- Create Paper opens the shared formula editor.
- Teacher can choose Build -> Pythagoras -> Add formula.
- Saved question rich text contains the math embed and the expected existing template source.

### Question Bank authoring

`test/features/question_bank/question_bank_paper_composer_widget_test.dart`

- Question Bank still renders the shared `QuestionComposerPage`.
- Its Math action reaches the same Build panel and structure/template choices.


## Post-test correction after first local `flutter test` run

The first local Phase 3 run reported four widget-test failures. They were test-harness/viewport timing issues rather than missing Phase 3 product behavior:

- `READY FORMULAS` was below the lazily built `ListView` viewport, so a direct `find.text` assertion was invalid for that test. Ready-template behavior remains exercised by the Create Paper Pythagoras flow.
- `Key actions` is replaced through a 160 ms `AnimatedSwitcher`; the regression test now waits for the switcher to settle before asserting the outgoing panel is gone.
- Create Paper and Question Bank tests had wrapped `MathKeyboardWrapper` around `home`, unlike production where it wraps the full navigator through `MaterialApp.builder`. The tests now mirror the production app structure.
- Ready-formula discovery now scrolls the keyboard-local `math-structure-browser` until `Pythagoras` is actually visible before tapping/asserting it.

The PDF font-download messages in the same log are warnings/fallback notices and were not the cause of the four Phase 3 failures.

## Recommended local validation

```powershell
dart format lib/features/math_keyboard/presentation/providers/math_keyboard_controller.dart `
  lib/features/math_keyboard/presentation/widgets/math_key.dart `
  lib/features/math_keyboard/presentation/widgets/math_keyboard_view.dart `
  lib/features/math_keyboard/presentation/widgets/math_keyboard_modal_presenter.dart `
  test/features/math_keyboard/formula_editor_sheet_test.dart `
  test/features/math_keyboard/math_teacher_build_catalog_test.dart `
  test/features/math_keyboard/math_keyboard_controller_build_test.dart `
  test/features/paper_composer/question_composer_typing_viewport_test.dart `
  test/features/question_bank/question_bank_paper_composer_widget_test.dart

flutter analyze --no-pub
flutter test test/features/math_keyboard/formula_editor_sheet_test.dart
flutter test test/features/math_keyboard/math_teacher_build_catalog_test.dart
flutter test test/features/math_keyboard/math_keyboard_controller_build_test.dart
flutter test test/features/math_keyboard/math_symbol_search_sheet_test.dart
flutter test test/features/paper_composer/question_composer_typing_viewport_test.dart
flutter test test/features/question_bank/question_bank_paper_composer_widget_test.dart
```

## Execution-environment note

The ChatGPT execution container used for this phase does not include the Flutter/Dart SDK, so no claim is made that `flutter analyze` or `flutter test` ran here. Source structure, archive integrity, catalogue references, and changed-file scope are checked before packaging.
