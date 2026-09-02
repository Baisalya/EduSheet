# EduSheet Professional Final Authoring Polish — QA Fix 2

## Windows free-form ribbon overflow hardening

The Word Mode desktop ribbon previously kept Home, Insert and Layout in one row where Insert/Layout were unconstrained. During Windows free-form resizing this could squeeze Home down to a few pixels, causing one-character-per-line text, a right RenderFlex overflow, and then a large bottom overflow.

### Fix
- Home now receives a stable flex share instead of being squeezed by unconstrained command groups.
- Insert + Layout live in a bounded horizontal command viewport and scroll only when the window cannot show every command.
- The active Quill Home toolbar is also horizontally scrollable instead of overflowing its group.
- Idle Home guidance is capped to two lines with ellipsis.
- Added `word-desktop-command-scroll` for deterministic responsive QA.
- Added a regression test at 1392×840 (reported Windows case) and after live resize to 820×620.

### Scope
No paper model, persistence, export schema, database, dependency, autosave, geometry, formula, or DOCX/PDF behavior change.

### Validation on Windows
Run:

```powershell
dart format .
flutter analyze
flutter test test/features/paper_composer/dual_editor_mode_test.dart
.\tool\run_final_authoring_polish_gate.ps1
```

The assistant environment does not provide Flutter/Dart, so runtime pass must be confirmed on the Windows development machine.
