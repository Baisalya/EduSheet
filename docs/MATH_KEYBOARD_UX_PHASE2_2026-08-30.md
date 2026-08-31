# Math Keyboard Teacher UX — Phase 2 (2026-08-30)

## Scope completed

This phase builds on the previously tested caret/focus batch. It keeps the same question, Question Bank, paper, option, and `MathExpression` persistence models.

### 1. More/category browsing is now keyboard-local

The old `More` category picker pushed another bottom-sheet route inside the custom keyboard. It is now a normal view inside `MathKeyboardView`.

Benefits:

- no stacked sheet for ordinary category navigation
- no extra Navigator push/pop for selecting Trig, Geometry, Statistics, Greek, etc.
- custom math-session ownership remains intact while browsing categories
- an explicit `Back to keys` action makes the transition obvious
- Recent and Favourites are promoted at the top with live counts

Search intentionally remains a keyboard-local modal route because mobile search needs the system text keyboard. Moving a real TextField into the custom math keyboard without a route boundary would create a system-IME/custom-keyboard focus conflict.

### 2. Recent/Favourites no longer fail silently when empty

Instead of a blank grid:

- Recent explains that used math appears automatically
- Favourites explains how to save symbols
- both provide `Browse math keys`

### 3. Teacher-language search redesign

Search now starts from curated high-frequency math instead of dumping the entire catalogue.

It adds plain-language shortcuts such as:

- Fraction
- Square root
- Power
- Angle
- Integral
- Vector
- Mean
- Greek

Results emphasize the visual symbol plus its readable name/category. Structural entries receive a `Structure` badge. Teachers can add/remove favourites directly from a result without first inserting it.

The existing semantic `MathSymbolCatalog.search` remains the source of truth. No parallel symbol database was introduced.

### 4. Formula editor language is less technical

Display placement now reads:

- `In sentence` instead of `Inline`
- `Own line` instead of `New line`

When the custom math keyboard is already open, the redundant `Math keyboard open` button is removed. The editor instead keeps the primary visual formula surface plus the optional `Advanced` path.

The active-position explanation now uses an explicit teacher workflow:

`Structure → type the first box → Next box → continue`

### 5. Regression coverage

Updated/added widget tests cover:

- custom math session remains active while the local category browser is open
- opening `More` does not push a Navigator route
- teacher-language symbol search
- structure-result presentation
- favouriting a search result without inserting it
- existing Create Paper formula-session wording

## Files changed in Phase 2

- `lib/features/math_keyboard/presentation/widgets/math_keyboard_view.dart`
- `lib/features/math_keyboard/presentation/widgets/math_symbol_search_sheet.dart`
- `lib/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart`
- `test/features/math_keyboard/formula_editor_sheet_test.dart`
- `test/features/math_keyboard/math_symbol_search_sheet_test.dart` (new)
- `test/features/editor/create_paper_save_sheet_test.dart`
- `docs/MATH_KEYBOARD_UX_PHASE2_2026-08-30.md` (new)

## Intentionally unchanged

- database schema and migrations
- Question Bank repository/storage
- paper repository/storage
- `QuestionOption` model
- `MathExpression` schema
- semantic catalogue identities
- generated Riverpod files
- geometry persistence

## Local validation commands

Run from the project root:

```powershell
dart format `
  lib/features/math_keyboard/presentation/widgets/math_keyboard_view.dart `
  lib/features/math_keyboard/presentation/widgets/math_symbol_search_sheet.dart `
  lib/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart `
  test/features/math_keyboard/formula_editor_sheet_test.dart `
  test/features/math_keyboard/math_symbol_search_sheet_test.dart `
  test/features/editor/create_paper_save_sheet_test.dart

flutter analyze --no-pub

flutter test test/features/math_keyboard/formula_editor_sheet_test.dart
flutter test test/features/math_keyboard/math_symbol_search_sheet_test.dart
flutter test test/features/editor/create_paper_save_sheet_test.dart
```

## Manual QA

1. Create Paper → Math → tap `MORE`; confirm categories replace the key grid instead of opening another sheet.
2. Pick `TRIG`; confirm formula focus/caret remains active and trig keys appear immediately.
3. Open `MORE` → Recent/Favourites; verify their counts and useful empty states.
4. Search `fraction`, `angle`, `wavelength`, `standard deviation`, and `vector`.
5. Star a search result, close search, open Favourites, and confirm it appears.
6. Build a fraction: tap fraction → type numerator → `Next box` → type denominator → continue.
7. Confirm the formula editor says `In sentence` / `Own line` and Advanced remains optional.
8. Repeat from Question Bank Add/Edit Question to verify the same shared composer behavior.
