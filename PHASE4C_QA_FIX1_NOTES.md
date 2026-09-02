# EduSheet Professional Formatting Phase 4C — QA Fix 1

Status: implementation fix prepared; Windows Flutter QA still required before Phase 4C lock.

## Trigger
The first Phase 4C gate stopped at static analysis with 9 findings:
- 5 unnecessary `dart:ui` imports,
- 3 `curly_braces_in_flow_control_structures` infos in `geometry_svg_service.dart`,
- 1 unused `geometry_point.dart` import in `word_export_service.dart`.

No runtime/focused test had failed yet because the gate correctly aborted at analysis.

## Fix
- Removed only the analyzer-confirmed redundant `dart:ui` imports.
- Removed the unused `GeometryPoint` import from Word export.
- Wrapped the two angle sweep `while` bodies and the flagged radius/diameter mark `if` body in braces.
- No behavior, schema, geometry model, export format, dependency, DB, or UI architecture change.

## Re-run
```powershell
dart format .
flutter analyze
.\tool\run_phase4c_gate.ps1
```

Expected: formatting clean after the first format, analyzer clean, then the gate proceeds beyond step 2 into Phase 4C focused/runtime tests.
