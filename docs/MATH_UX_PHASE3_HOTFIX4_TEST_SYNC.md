# Math UX Phase 3 Hotfix 4 — widget-test animation synchronization

## Why this hotfix exists
The remaining Create Paper and Question Bank widget tests observed the math keyboard controller in its visible/owned state, but immediately tapped the Build key while the keyboard overlay's 300 ms `AnimatedSlide` was still at its initial hidden offset.

In Flutter widget tests, a long `pump(Duration)` can execute a post-frame callback at the end of that pump. The formula editor opens the custom keyboard from such a post-frame callback. Therefore the controller may already report `isVisible == true` while the slide-in animation has not yet received a subsequent frame.

## Fix
Both end-to-end authoring tests now:
1. verify the formula math session is owned and logically visible;
2. pump an additional 350 ms (greater than the real 300 ms overlay entrance duration);
3. assert the Build key's center is inside the 900 px test viewport;
4. only then tap Build and continue the original strong workflow assertions.

## Scope
Test-only synchronization change. No production `lib/` file, data model, repository, migration, persistence format, or generated Riverpod file changed in Hotfix 4.
