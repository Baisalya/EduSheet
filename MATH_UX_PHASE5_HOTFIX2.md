# EduSheet Math UX Phase 5 Hotfix 2

## Scope
Test-only correction for the 320x520 / 2x text-scale Build-panel accessibility regression gate.

## Root cause
The production `_StructureChoiceCard` already exposes `Semantics(label: 'Insert Fraction')`, but at 320x520 with 2x text scaling the first structure card begins below the Build panel's initial viewport. The test asserted the semantics label before the card was physically visible.

## Fix
- Resolve the canonical fraction entry through `MathSymbolCatalog.findByTex(r'\\frac{}{}')`.
- Target its real `math-build-<id>` card key.
- Drag the existing `math-structure-browser` until that card is visible.
- Then assert the `Insert Fraction` semantics label and adaptive card height >= 100px.

## Production impact
None. No `lib/` files changed.

## Recommended validation
```powershell
flutter test test/features/math_keyboard/math_keyboard_extreme_layout_test.dart
flutter test
flutter analyze --no-pub
```
