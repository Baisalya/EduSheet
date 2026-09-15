# Teaching Planner Phase 3 + 4 — Adaptive Syllabus Editor

Date: 2026-09-09

## Scope

This phase replaces the active three-pane syllabus management flow with a simpler adaptive editor while preserving the existing syllabus domain/service model.

Protected areas intentionally left unchanged:

- Planner Insights calculations and Insights/Backup screen
- Track Progress screen and progress dashboard widgets
- Teaching Planner entitlement/capability and subscription integration

## New interaction model

### Start

A new syllabus starts with only:

1. Class / syllabus name
2. Optional academic year

After creation, the new syllabus is selected automatically and the user continues from the same editor.

### Wide Windows

The editor uses a master-detail structure:

- Left: searchable syllabus outline
- Right: selected item details and contextual child editor

Hierarchy remains Class → Subject → Unit → Chapter → Topic. Subject-level chapters remain supported for syllabuses that do not use units.

### Android and narrow/free-form Windows

The editor switches to a drill-down structure rather than stacking fixed-height desktop panes:

- Syllabus list
- Class details / subjects
- Subject details / units and direct chapters
- Unit details / chapters
- Chapter details / topics
- Topic details

A horizontal breadcrumb provides direct ancestor navigation. System Back walks up the hierarchy before leaving the screen.

### Search and filters

Wide layouts expand matching outline branches. Compact layouts use a global result list so deeply nested topics can be found without manually opening every level. Selecting a compact search result clears search/filter mode and opens the selected item.

### Reordering

The existing safety rule is preserved: reorder is enabled only when search is empty and the filter is `All`. Reordering remains scoped to the correct sibling collection.

## Presentation modules

- `presentation/models/syllabus_node_ref.dart`
  - Typed hierarchy selection/path reference.
- `presentation/widgets/syllabus_outline.dart`
  - Wide Windows hierarchy outline.
- `presentation/widgets/syllabus_detail_panel.dart`
  - Reusable selected-entity details and contextual child editor.
- `presentation/widgets/syllabus_adaptive_shell.dart`
  - Responsive toolbar, compact syllabus browser, breadcrumbs, compact search results and empty/selection states.
- `presentation/widgets/syllabus_start_sheet.dart`
  - Minimal first-step syllabus creation.
- `presentation/screens/syllabus_manager_screen.dart`
  - Adaptive orchestration, dialogs and existing mutations/import/archive/reorder coordination.

The previous pane widgets are no longer used by the active `SyllabusManagerScreen`; removal can happen in the dedicated cleanup/release phase after regression validation.

## Responsive regression targets

Widget tests cover:

- 320 × 520
- 360 × 800
- 412 × 915
- 600 × 480
- 900 × 700
- 1366 × 768

Tests also cover compact hierarchy drilling, minimal syllabus creation, deep search visibility and high-priority filtering.
