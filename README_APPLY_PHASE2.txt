EduSheet Math UX Phase 2 — Modified Files

Base expected: EduSheet_Math_UX_Refactor_Full_2026-08-30.zip (the previous batch).

Apply by copying the included lib/, test/, and docs/ paths over the project root.
MATH_UX_PHASE2.patch is included as a reviewable unified diff.

Then run:
  dart format lib/features/math_keyboard/presentation/widgets/math_keyboard_view.dart lib/features/math_keyboard/presentation/widgets/math_symbol_search_sheet.dart lib/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart test/features/math_keyboard/formula_editor_sheet_test.dart test/features/math_keyboard/math_symbol_search_sheet_test.dart test/features/editor/create_paper_save_sheet_test.dart
  flutter analyze --no-pub
  flutter test test/features/math_keyboard/formula_editor_sheet_test.dart
  flutter test test/features/math_keyboard/math_symbol_search_sheet_test.dart
  flutter test test/features/editor/create_paper_save_sheet_test.dart
