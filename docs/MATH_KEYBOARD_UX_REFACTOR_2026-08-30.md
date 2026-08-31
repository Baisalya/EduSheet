# Math Keyboard Teacher UX Refactor — 2026-08-30

## Scope completed

This batch improves the existing EduSheet math-entry architecture without changing question, paper, Question Bank, or `MathExpression` persistence schemas.

### 1. Caret/focus session stabilization

`MathKeyboardController` now explicitly restores the active math editor after insertion, left/right navigation, delete, clear, power/subscript mode changes, and structured `Next box` navigation. The custom math keyboard remains the owner and the system IME is kept hidden while the math session is active.

### 2. Teacher-facing action bar

The old developer-oriented `ABC`/icon-only workflow is replaced on wide layouts with explicit controls:

- Text
- left/right typing-position movement
- Space
- Backspace
- Next box

`Next box` explains its purpose through a tooltip: moving through fraction, power, root, and other structured formula slots. Narrow phone layouts keep compact icons.

### 3. Formula typing position guidance

The formula editor now gives a visible active/inactive state:

- active border while the custom math keyboard owns the formula
- “Math typing active” status message
- helper text explaining that `Next box` moves through structured math slots

No private cursor APIs from `math_keyboard` are fabricated or accessed.

### 4. Easier symbol discovery

The Quick ribbon now surfaces high-frequency teacher inputs directly:

- fraction
- root
- power
- subscript
- brackets
- equals
- multiplication
- division
- plus/minus
- not equal
- less-than-or-equal
- greater-than-or-equal
- pi

All entries resolve through the existing `MathSymbolCatalog` source of truth.

### 5. Better responsive behavior

The default 320 px keyboard height is no longer treated as a compressed layout. Wide desktop/tablet views receive descriptive labels, while genuinely narrow/short layouts remain compact.

### 6. Shared Create Paper + Question Bank placement guidance

The shared `QuestionComposerPage` now tells teachers that Math and Geometry are inserted exactly at the current question cursor and that they should place the caret first. Because Question Bank authoring already reuses `QuestionComposerPage`, the guidance and math workflow stay consistent across both entry points.

## Files changed

- `lib/features/math_keyboard/domain/services/math_smart_palette.dart`
- `lib/features/math_keyboard/presentation/providers/math_keyboard_controller.dart`
- `lib/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart`
- `lib/features/math_keyboard/presentation/widgets/math_keyboard_action_bar.dart`
- `lib/features/math_keyboard/presentation/widgets/math_keyboard_view.dart`
- `lib/features/paper_composer/presentation/widgets/question_composer_page.dart`
- `test/features/editor/create_paper_save_sheet_test.dart`
- `test/features/math_keyboard/formula_editor_sheet_test.dart`
- `test/features/math_keyboard/math_smart_palette_test.dart` (new)

## Intentionally unchanged

- Question Bank repositories
- paper repositories
- database schema/migrations
- `QuestionOption` persistence
- `MathExpression` schema
- TeX/source compatibility behavior

## Local validation commands

Run from the project root with your Flutter SDK installed:

```powershell
dart format lib/features/math_keyboard/domain/services/math_smart_palette.dart `
  lib/features/math_keyboard/presentation/providers/math_keyboard_controller.dart `
  lib/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart `
  lib/features/math_keyboard/presentation/widgets/math_keyboard_action_bar.dart `
  lib/features/math_keyboard/presentation/widgets/math_keyboard_view.dart `
  lib/features/paper_composer/presentation/widgets/question_composer_page.dart `
  test/features/editor/create_paper_save_sheet_test.dart `
  test/features/math_keyboard/formula_editor_sheet_test.dart `
  test/features/math_keyboard/math_smart_palette_test.dart

flutter analyze --no-pub

flutter test test/features/math_keyboard/formula_editor_sheet_test.dart
flutter test test/features/math_keyboard/math_editor_adapter_test.dart
flutter test test/features/math_keyboard/math_smart_palette_test.dart
flutter test test/features/editor/create_paper_save_sheet_test.dart
```

## Manual QA checklist

1. Create Paper → put cursor in the middle of question text → Math → create fraction → Add formula → verify insertion returns exactly after the formula.
2. Question Bank → Add/Edit Question → repeat the same flow.
3. In a fraction, enter numerator → `Next box` → denominator → `Next box` → continue outside the fraction.
4. Repeat for root, power, and subscript.
5. Tap several math keys quickly and verify the formula typing position remains active/visible.
6. On Windows wide layout, confirm `Text` and `Next box` labels are visible.
7. On narrow Android layout, confirm the action bar stays compact with tooltips/semantics and no horizontal overflow.
8. Open More/Search, return to the keyboard, and verify formula focus is restored.
9. Open Advanced source editor and confirm moving to that real text field correctly releases the structured math session.
