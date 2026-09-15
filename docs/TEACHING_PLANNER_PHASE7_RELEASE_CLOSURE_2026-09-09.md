# Teaching Planner Phase 7 — Syllabus Release Closure

## Scope

Phase 7 closes the syllabus refactor started in Phases 1–6. It removes the obsolete three-pane implementation, separates hierarchy/navigation policy from widgets, separates syllabus mutation coordination from the screen, hardens the attachment UI tests, and adds a single release-gate command.

## Architectural cleanup

- Removed `presentation/widgets/syllabus_manager_panes.dart` (legacy 3-pane implementation; no active imports remained).
- Added `SyllabusNavigationPolicy` for selection validation and compact parent navigation.
- Added `SyllabusManagerController` for create, archive, import, and reorder mutations plus post-mutation selection transitions.
- Reduced `SyllabusManagerScreen` from roughly 1,034 lines to roughly 738 lines while retaining edit sheets, dialogs, snackbars, and platform UI concerns in the screen layer.
- Kept `SyllabusAttachmentController` as the only syllabus attachment action coordinator.

## Regression hardening

The Phase 5/6 attachment widget tests no longer depend on Flutter's version-sensitive `scrollUntilVisible(scrollable: ...)` casting behavior. Tests scroll the actual detail `ListView` and then use `ensureVisible` once the lazy child exists.

Added pure navigation tests for:

- Topic → chapter parent navigation.
- Unit-backed chapter → unit navigation.
- Root chapter → subject navigation.
- Missing/archived selection rejection.

## Protected boundaries

Phase 7 does not modify:

- Planner Insights behavior or UI.
- Track Progress behavior or dashboard.
- Subscription / premium model.
- Entitlement or capability behavior.

## Release gate

Run from the EduSheet project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_teaching_planner_syllabus_release_gate.ps1
```

The gate runs Teaching Planner formatting, `flutter analyze`, navigation tests, adaptive syllabus tests, attachment + portable `.eds` tests, and the full Teaching Planner test directory.
