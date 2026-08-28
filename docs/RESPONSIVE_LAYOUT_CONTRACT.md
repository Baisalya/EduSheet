# EduSheet responsive layout contract

This contract exists to keep Windows free-form resizing and Android compact layouts stable without hiding Flutter layout errors.

## App viewport

`AdaptiveAppViewport` is the last-line guard for physically impractical window sizes. Normal layouts keep the real viewport. Ultra-small desktop/mobile viewports receive a minimum logical canvas and become pannable instead of forcing the entire route tree below a usable width or height.

## Modal bottom sheets

All app bottom sheets must be opened with `showAdaptiveModalBottomSheet` from:

`lib/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart`

Do not call Flutter's raw `showModalBottomSheet` from feature code. The adaptive presenter gives every sheet a finite, full-width canvas at narrow sizes and caps large desktop sheets at a readable width. `adaptive_modal_usage_test.dart` enforces this rule.

## Rows and controls inside constrained surfaces

- Use `Expanded`/`Flexible` for text or dropdown content inside a bounded `Row`.
- Give dropdowns `isExpanded: true` when they share width with icons/actions.
- Use `TextOverflow.ellipsis` for single-line control labels that may be user/content driven.
- Prefer `Wrap` or a breakpoint-driven vertical action layout when multiple buttons must fit a narrow surface.
- Empty states inside `Expanded`/`Flexible` regions must be scrollable when their intrinsic height can exceed the remaining height.

## Regression sizes

Responsive widget tests should cover at least:

- 320 x 520: compact narrow layout
- 366 x 720: narrow Windows free-form layout
- 600 x 480: short/wide free-form layout
- normal tablet/desktop sizes where relevant

Do not suppress RenderFlex or framework assertions. Fix the constraint hierarchy that causes them.
