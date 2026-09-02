# EduSheet Professional Adaptive Ribbon Polish

Baseline: Professional Final Authoring Polish QA Fix 3 (test-selector hardening).

## What changed

- Moved the primary **Add section** action into the Word Mode ribbon so teachers no longer need to scroll to the end of a long paper.
- Added a dedicated **Structure** command group on Windows/free-form layouts with:
  - Add section
  - Add question
  - Question Bank
- Added a compact adaptive primary command strip for Android/narrow free-form layouts:
  - Section
  - Question
  - Bank
  - Header
  - Page setup
- Kept document-content tools (Paragraph, Table, Picture, Shape, Math, Geometry, Page break, Import Word) in a separate horizontally scrollable insert strip on compact widths.
- Retained the end-of-paper Add section control only as a secondary convenience action on wider desktop layouts; it now has its own footer key and no longer conflicts with the primary ribbon action.
- Question Bank targets the currently active section when one exists. On a blank paper it reuses the existing start-from-bank flow so cancelling does not create an empty section.
- Reused the same command callbacks and canonical paper state across Android, Windows, and resized free-form windows. No parallel mobile/desktop paper model was introduced.

## Responsive intent

- **Windows wide:** Home | Structure | Insert | Layout groups.
- **Windows free-form / medium width:** same groups inside the bounded horizontal command viewport.
- **Android / compact:** primary structure/layout strip + insert strip; both horizontally scroll instead of overflowing.
- Contextual Home formatting remains tied to the selected question/section/instruction.

## Compatibility

No database migration, dependency upgrade, export schema change, or paper-model fork.

## Validation added

`dual_editor_mode_test.dart` now asserts that Add section lives inside the adaptive Word ribbon on phone and desktop layouts and that Question Bank is exposed in the ribbon. The existing 1392x840 -> 820x620 resize regression remains in place.
