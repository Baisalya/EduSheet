# Phase 4B QA Fix 1

## Scope
Narrow release-blocker fix for the Phase 4B shape preview renderer. No schema, dependency, geometry, editor architecture, PDF, DOCX, or persistence redesign.

## Windows QA failure
`word_shape_preview_phase4b_test.dart` produced a recursive `LayoutBuilder`/`Stack` layout chain on 360 px / 320 px widths. Flutter eventually reported `RenderBox was not laid out` / `hasSize`, the body text disappeared, and the Phase 4B gate stopped at the shape preview step.

## Root cause
In `WordShapeFlowPreview.build`, the overlay branch reassigned `text` to a `LayoutBuilder` and then referenced `text` from inside that new builder. Because Dart closures capture the variable rather than its previous value, the builder recursively inserted itself whenever Behind Text or In Front of Text shapes were present.

## Fix
Capture the already-composed content before replacing `text`:

```dart
final contentBelowOverlay = text;
text = LayoutBuilder(... children: [..., contentBelowOverlay, ...]);
```

This keeps the intended layer order:
1. Behind-text shapes
2. Existing question/square-wrap content
3. In-front-of-text shapes

and removes the self-referential widget tree.

## Expected regression coverage
The existing Phase 4B preview tests now directly guard the broken path:
- square wrap + behind/in-front overlay + callout text
- all shape kinds at narrow phone width

## Validation status
Static/package validation performed in the assistant environment only. Flutter/Dart runtime is not available here, so Windows runtime QA must be rerun by the user before Phase 4B is locked.
