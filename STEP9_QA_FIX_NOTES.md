# EduSheet Step 9 QA Fix

## Trigger
The full Flutter suite failed only at `adaptive_modal_usage_test.dart` because the new Word page-layout sheet called Flutter `showModalBottomSheet` directly.

## Root cause
EduSheet already has an app-wide `showAdaptiveModalBottomSheet` wrapper that gives Android and narrow/free-form Windows windows finite, full-width modal constraints. Step 9 introduced `word_page_layout_sheet.dart` using the raw Material presenter, violating that release contract.

## Fix
- Added the shared adaptive modal presenter import.
- Replaced the raw `showModalBottomSheet<WordPageLayoutDraft>` call with `showAdaptiveModalBottomSheet<WordPageLayoutDraft>`.
- Kept the existing wide-screen `showDialog` path unchanged.
- Kept `isScrollControlled`, `useSafeArea`, `showDragHandle`, 92% height, and the same page-layout editor unchanged.

## Scope
One production Dart file only. No model, persistence, DB/schema, export, page-layout semantics, dependency, Smart Mode, or Word Mode behavior change beyond the modal presenter contract.

## Static QA completed here
- source scan finds zero raw `showModalBottomSheet` callers under `lib/` outside the shared adaptive wrapper
- `git diff --check` clean
- patch generated against the Step 9 full ZIP baseline
- modified/full ZIP integrity verified

## Workstation validation
Run:

```powershell
dart format .
flutter analyze
flutter test test/shared/presentation/adaptive_modal_usage_test.dart
flutter test test/release
flutter test
```

Expected: analyzer clean and full suite all-pass. Font-download/Helvetica fallback output is unrelated to this modal-usage gate.
