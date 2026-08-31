# Math Keyboard UX Phase 4 — Teacher Authoring Polish

Date: 2026-08-30

## Scope

Phase 4 deliberately avoids model, repository, persistence, and generated-code changes. Phase 3 is already behaviorally locked by the passing full test suite. This phase improves the last teacher-facing rough edges.

## Changes

- The math action bar now decides labels from horizontal space rather than keyboard height. A wide Windows keyboard that has been vertically resized can still show explanatory labels.
- Primary keyboard categories also keep their full teacher-facing names on wide-but-short Windows layouts instead of collapsing to unexplained abbreviations/icons.
- `Next box` is visible from medium widths (430 px+) because it is the most important structured-formula navigation action.
- `Text` and `Space` labels appear progressively on wider layouts without crowding narrow phones.
- Action-bar controls now expose explicit button semantics, including useful labels for icon-only narrow layouts.
- Formula placement now has contextual guidance for `In sentence` versus `Own line`.
- Formula typing status is a live accessibility region so assistive technology can announce when the custom math session becomes active or inactive.
- Added regression coverage for 480 px and 320 px action bars, 2× text scaling, placement guidance, and existing formula behavior.

## Non-goals

- No database/schema migration.
- No Question Bank model change.
- No change to `MathExpression` serialization.
- No new dependency.
- No attempt to infer internal MathField slots from undocumented package APIs.

## Local validation

```powershell
dart format lib/features/math_keyboard/presentation/widgets/math_keyboard_action_bar.dart lib/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart test/features/math_keyboard/math_keyboard_action_bar_test.dart test/features/math_keyboard/math_keyboard_responsive_test.dart test/features/math_keyboard/formula_editor_sheet_test.dart
flutter test test/features/math_keyboard/math_keyboard_action_bar_test.dart
flutter test test/features/math_keyboard/math_keyboard_responsive_test.dart
flutter test test/features/math_keyboard/formula_editor_sheet_test.dart
flutter test
flutter analyze --no-pub
```
