EduSheet Math UX Phase 5 — Production Hardening
Date: 2026-08-30
Baseline: Phase 4 (+220 tests passed locally by user)

Apply either the full ZIP or copy the modified files preserving their paths.

What changed:
- Rebuild-safe math session ownership for replacement FocusNodes/controllers.
- Single-emission math session owner transfer to prevent transient keyboard collapse/IME flash.
- 320px + 2x text-scale safe Build/Ready Formula card sizing.
- Accessible keyboard resize increase/decrease actions.
- Accessible Build entry action.
- Final regression gates for external focus release and Math -> Text -> Math reopen.

No database, repository, MathExpression serialization, Question Bank model, dependency, or generated Riverpod changes.

Recommended validation:
  dart format lib test
  flutter test test/features/math_keyboard/math_keyboard_controller_build_test.dart
  flutter test test/features/math_keyboard/math_keyboard_field_session_hardening_test.dart
  flutter test test/features/math_keyboard/math_keyboard_extreme_layout_test.dart
  flutter test test/features/math_keyboard/formula_editor_sheet_test.dart
  flutter test
  flutter analyze --no-pub
