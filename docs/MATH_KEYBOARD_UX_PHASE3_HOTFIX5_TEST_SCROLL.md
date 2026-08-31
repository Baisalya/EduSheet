# Math UX Phase 3 Hotfix 5 — E2E Build Browser Scrolling

Date: 2026-08-30

## Failure addressed

The two remaining widget tests failed with:

`type 'ListView' is not a subtype of type 'Scrollable' in type cast`

The Phase 3 E2E tests passed `find.byKey(ValueKey('math-structure-browser'))` to `WidgetTester.scrollUntilVisible(..., scrollable:)`. The keyed production widget is intentionally a `ListView`, while that named argument requires a finder that resolves to Flutter's internal `Scrollable` widget.

## Fix

Both E2E tests now use `WidgetTester.dragUntilVisible` with the keyed `ListView` as the drag surface. This API matches the actual test intent: drag the visible Build browser until the lazy `Pythagoras` ready-formula item is built and visible.

Affected tests:

- `test/features/paper_composer/question_composer_typing_viewport_test.dart`
- `test/features/question_bank/question_bank_paper_composer_widget_test.dart`

## Scope

Test-only hotfix. No production `lib/` code, model, repository, persistence, schema, or generated code changed from Hotfix 4.

## Local validation

Run:

```powershell
flutter test
flutter analyze --no-pub
```

The PDF Noto/Helvetica download messages seen in offline tests are fallback warnings and are unrelated to this math-authoring test failure.
