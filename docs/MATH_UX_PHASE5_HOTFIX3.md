# Math UX Phase 5 Hotfix 3 — Extreme accessibility layout

## Why this hotfix exists

The Phase 5 extreme-layout gate exposed real production overflows at a 320×520 viewport with 2× text scaling:

- the Build panel heading/action row overflowed horizontally;
- two-column structure cards left only about 67 px for scaled title/hint text and overflowed vertically.

The regression test was kept as a hard gate. This hotfix changes the production layout rather than suppressing the test.

## Production changes

- Build panel header stacks `Back to keys` below the guidance on narrow or large-text layouts.
- Structure and ready-formula grids switch to one column when text scale is >= 1.6 and available width is < 520 px.
- Ready Formula heading/action also stacks at extreme text scale/narrow width.
- Extreme-scale structure-card extent increases slightly to 118 px for additional line-height safety.
- Existing 2/3/4-column density remains for ordinary phone/tablet/Windows layouts.

## Deliberately unchanged

- MathExpression model and Quill embed format
- Question Bank storage/repositories
- Paper persistence
- symbol catalogue IDs and TeX
- keyboard session/focus architecture
- dependencies and generated Riverpod files

## Validation gate

Run:

```powershell
flutter test test/features/math_keyboard/math_keyboard_extreme_layout_test.dart
flutter test
flutter analyze --no-pub
```

The extreme-layout test must pass without RenderFlex overflow exceptions.
