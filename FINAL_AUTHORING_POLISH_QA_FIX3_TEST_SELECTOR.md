# Final Authoring Polish QA Fix 3 — Mode Selector Test Hardening

## Why this fix exists
The Windows free-form regression test ran at 1392x840, where the UI legitimately contains two visible `Word` labels:
1. the app-bar Word export button, and
2. the Smart/Word editor mode segment.

The test used `find.text('Word')`, so `tester.tap(...)` was ambiguous and failed before any resize/overflow assertion executed.

## Fix
All Smart/Word mode interactions in `dual_editor_mode_test.dart` are now scoped to the existing `paper-editor-mode-segmented` key through a shared `_modeSegment(...)` finder.

This is a test-only change. No production widget, paper model, autosave, export, geometry, persistence, or responsive layout behavior changed.

## Validation to run on Windows
```powershell
dart format .
flutter analyze
flutter test test/features/paper_composer/dual_editor_mode_test.dart
.\tool\run_final_authoring_polish_gate.ps1
```

The Windows resize test must now reach its actual overflow assertions rather than failing while selecting Word Mode.
