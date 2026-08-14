# Scientific Calculator Live Preview — Widget Test Hotfix

Date: 2026-08-14

## What failed

The live-preview widget test expected `calculator-live-preview` to be immediately absent after pressing Enter. The provider state was already correct: `previewResult == null`, the committed result was `5`, `Ans` was updated to `5`, and one history entry existed.

## Root cause

`CalculatorDisplay` intentionally uses `AnimatedSwitcher` with a 140 ms fade transition. When `previewResult` changes from a value to `null`, the old preview child remains mounted temporarily as AnimatedSwitcher's outgoing child. A widget finder can therefore still locate the old `Text` even though calculator state has already cleared the preview.

This was a test synchronization issue, not a calculator/state/math-engine defect.

## Fix

The widget test now:

1. presses Enter;
2. pumps once so the provider/UI commit is processed;
3. asserts the calculator state immediately (`previewResult == null`, result/Ans/history committed);
4. calls `pumpAndSettle()` to allow the intentional fade-out to complete;
5. only then asserts that `calculator-live-preview` is absent from the widget tree.

No production calculator code, dependency, PDF/Word code, or question-paper logic was changed for this hotfix.

## Verification commands

```powershell
flutter analyze
flutter test test/features/calculator
flutter test
```

The Noto/Helvetica messages emitted by PDF tests are font/network fallback warnings and are separate from this calculator widget-test assertion.
