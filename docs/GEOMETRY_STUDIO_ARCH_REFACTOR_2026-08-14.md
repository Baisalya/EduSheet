# EduSheet Geometry Studio — Architectural Refactor & QA Report

Date: 2026-08-14
Baseline: `EduSheet_inline_math_test_assertion_fix_full.zip`

## Goal

Replace the multi-step geometry workflow with one teacher-first Geometry Studio where the teacher chooses mathematical intent (figure, side, angle, mark, measurement) and the application handles persisted point/shape/mark details.

## Compatibility boundaries preserved

The following persisted models are byte-for-byte unchanged from the baseline:

- `GeometryDiagram`
- `GeometryPoint`
- `GeometryShape`
- `GeometryLabel`
- `GeometryMark`

`pubspec.yaml` is also unchanged. No package or database/schema dependency was added.

All 21 existing `GeometryShapeType` values remain supported:
line, arrow, triangle, rightTriangle, square, rectangle, circle, semicircle, parallelogram, trapezium, rhombus, pentagon, hexagon, coordinateAxes, numberLine, cube, cuboid, cylinder, cone, sphere, polygon.

## Architecture

### Persisted document layer

`GeometryController` now focuses on persisted document mutation and undo/redo history. Template construction and teacher intent are no longer embedded in the controller.

### Transient editor session

`GeometryEditorSession` owns non-persisted editor state:

- selected point / label / shape / side / mark
- hit testing coordination
- one-drag/one-undo transaction lifecycle
- recipe insertion
- UI-facing selection state

This state never enters `GeometryDiagram` JSON.

### Semantic teacher commands

`GeometryEditorCommands` translates teacher actions into the existing persisted model:

- label selected side
- label selected angle and add its arc
- mark selected side equal
- mark selected side parallel
- mark selected vertex as 90°
- construct perpendicular height from a selected triangle vertex
- add radius to selected circle
- add coordinate point to existing axes
- duplicate selected shape and its applicable marks
- dependency-safe delete

The UI no longer chooses arbitrary first points when a teacher asks for a mathematical mark.

### Hit testing

`GeometryHitTester` recognizes:

- labels
- point labels
- points
- persisted marks
- sides/segments
- complete shapes

Marks have priority over the side below them at their visible anchor, allowing equal-side/parallel/construction marks to be selected and deleted independently.

### Teacher recipe catalog

`GeometryRecipeCatalog` and `GeometryRecipeFactory` provide quick constructions while storing only existing primitives.

Examples:

- right triangle with right-angle mark
- isosceles triangle with equal-side marks
- equilateral triangle with three equal-side marks
- angle with arc
- parallel lines with matching marks
- circle + radius
- circle + diameter
- circle + chord
- circle + tangent
- coordinate axes
- number line
- every persisted base shape

No arbitrary `5 cm`, `60°`, `r = 4 cm`, etc. is inserted into newly created figures.

## UI rewrite

The old top-level modes:

- Shapes
- Draw
- Labels
- Marks
- Export

are removed from the active Geometry Studio.

The new Studio has:

- one canvas
- one `+ Add` surface with search/categories
- quick teacher-ready constructions
- contextual actions based on the selected object
- direct drag for points/labels
- direct tap selection
- double-tap/long-press side to select whole shape
- one Insert action

### Mobile / Android / free-form

- canvas-first layout
- compact quick recipe strip when vertical room allows
- very short windows collapse creation to one `Choose figure` action
- contextual bottom bar rather than permanent inspector panels
- outside-tap dismissal disabled to prevent accidental work loss

### Windows

Expanded layout uses:

- Quick Start panel
- central canvas
- contextual Inspector

Keyboard actions:

- Ctrl+Z — Undo
- Ctrl+Y — Redo
- Delete — delete selection safely
- Esc — clear selection / close
- Ctrl+D — duplicate selected shape

## Create Paper integration

Create Paper now opens Geometry Studio directly. The old separate quick-shape picker is removed.

Existing Quill geometry embed payload/serialization is preserved. Existing embedded diagrams still open through `GeometryBuilderScreen.show(initialDiagram: ...)` and use the new Studio.

## Safety / real-world behavior

- Closing a dirty diagram asks before discarding.
- Clicking outside the Studio cannot silently discard work.
- Clearing the diagram asks for confirmation and remains undoable.
- Empty diagrams cannot be inserted.
- A point referenced by a shape cannot be deleted independently.
- Deleting a shape removes only points no longer used by another shape and removes marks that depend on removed points.
- Dragging is one history transaction rather than one undo entry per pointer update.
- New measurement labels are created only after explicit teacher input.

## Automated tests added

### `geometry_recipe_factory_test.dart`

- all 21 persisted shape types have teacher recipe coverage
- all base shapes serialize/deserialize
- templates do not invent measurements
- isosceles/equilateral constructions encode equality with marks
- equilateral side lengths are geometrically consistent
- circle/angle/parallel constructions use existing persisted primitives
- recipe IDs are unique

### `geometry_editor_session_test.dart`

- side commands target the actual selected side
- selected vertex drives right-angle marks
- altitude foot projects to the opposite side line
- shape-owned point cannot be deleted independently
- coordinate values map to the existing coordinate axes
- smart diagrams round-trip through existing JSON
- a side construction mark can be selected instead of the underlying side
- right-angle mark uses its visible vertex anchor for hit testing

### `geometry_studio_widget_test.dart`

- new Studio exposes Add/Insert
- old Shapes/Draw/Labels/Marks/Export mode UI is absent

## Source-level QA completed in this environment

- Missing local Dart imports/references: **0**
- Delimiter/structure scan issues in geometry + affected composer code: **0**
- Stale references to removed Geometry UI classes/files: **0**
- TODO/FIXME/placeholder implementations in new geometry code: **0**
- Persisted shape coverage: **21 / 21**
- Static recipe IDs: unique
- Existing persisted geometry model files: unchanged
- `pubspec.yaml`: unchanged

## Environment limitation

This container does not include Flutter/Dart CLI, so `flutter analyze` and `flutter test` cannot honestly be reported as executed here. Run the release commands on the normal EduSheet Flutter workstation:

```powershell
flutter analyze
flutter test
flutter test integration_test/question_creation_journey_test.dart -d windows
```

Recommended manual acceptance path:

1. Create Paper → Geometry.
2. Choose Right triangle.
3. Tap a side → Measure / Equal / Parallel.
4. Tap a vertex → Angle / 90° / Height.
5. Add Circle + radius and edit points directly.
6. Add Coordinate axes → select axes → Point → enter `(2, 3)`.
7. Insert, save paper, reopen, and edit the embedded diagram again.
8. Repeat on narrow Android/free-form and Windows layouts.
