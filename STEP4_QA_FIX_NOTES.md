# EduSheet Step 4 — QA Fix

This patch addresses the failures from the Step 4 local Flutter run.

## Fixes

1. **Flutter 3.41+ ReorderableListView API compatibility**
   - Replaced the invalid `controller:` argument on `ReorderableListView.builder` with `scrollController:`.
   - Migrated deprecated `onReorder:` usage to `onReorderItem:`.
   - Preserved the existing editor/provider reorder contract by converting the new adjusted `newIndex` back to the legacy insertion-index semantics at the presentation boundary. This avoids silently changing reorder behavior in the provider.

2. **Question reorder deprecation**
   - `PaperSectionCard` now uses `onReorderItem:` and performs the same compatibility conversion before invoking its existing callback.

3. **Smart formatting widget test interaction**
   - The two-column option-layout chip was present but below the 430×900 test viewport, so `tap()` missed it and the state never changed.
   - The test now scrolls the existing `SingleChildScrollView` until the chip is visible before tapping. This tests the actual phone interaction instead of tapping an off-screen render object.

4. **Deprecated test harness API**
   - Updated the section-card widget test from `onReorder:` to `onReorderItem:`.

## Files changed

- `lib/features/paper_composer/presentation/screens/paper_composer_screen.dart`
- `lib/features/paper_composer/presentation/widgets/paper_section_card.dart`
- `test/features/paper_composer/paper_section_smart_formatting_test.dart`
- `test/features/paper_composer/question_smart_formatting_controls_test.dart`

## Validation to run locally

```powershell
dart format .
flutter analyze
flutter test
```

The PDF font download/Helvetica fallback messages in the provided test log are unrelated to these Step 4 failures and were left unchanged.
