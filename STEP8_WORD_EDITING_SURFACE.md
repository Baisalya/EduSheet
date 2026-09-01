# EduSheet Step 8 — Word Editing Surface

## Goal

Step 8 turns the Step-7 Word Mode foundation into a real rich authoring surface while keeping Smart Mode and Word Mode on the same canonical `Paper` model.

There is still no second DOCX model and no conversion step when switching modes.

## Implemented

### Inline rich editing

- Existing assessment questions can be edited directly inside Word Mode with Quill.
- Rich formatting writes back to the same `Question.text` delta that Smart Mode already understands.
- Plain-text accessibility and embedded math metadata are updated together.
- Existing unplaced/legacy math is preserved.

### Word-style formatting surface

Phone/compact mode uses a contextual horizontal authoring surface.

Desktop/Windows mode exposes a broader Word-like ribbon including:

- font family and size
- bold / italic / underline / strike
- text and highlight color
- clear formatting
- headings
- numbered and bulleted lists
- quotes and indentation
- paragraph alignment
- superscript / subscript
- links
- undo / redo

### Math and Geometry at the active caret

- The ribbon targets the currently active rich editor.
- Math opens the existing EduSheet Formula Editor and inserts the expression at the saved Quill selection.
- Geometry opens the existing Geometry Builder and inserts the diagram at the saved selection.
- No duplicate math/geometry engine was introduced.

### Free Word content

Word Mode can insert content that is not an assessment question:

- free rich paragraph
- table
- image / diagram attachment

These blocks are persisted using the existing `Question.metadata` compatibility channel with an `edusheet.wordContentBlockKind` marker. This avoids a database/schema migration.

### Assessment-safe behavior

Free Word content intentionally does **not**:

- consume question numbering
- add marks
- satisfy `Answer any N` counts
- count as an OMR question
- appear as a Question Bank assessment item
- trigger missing-question-marks validation
- inflate release/performance question counts

Smart Mode still preserves and shows these blocks as `Word content` so teachers can switch back without data loss.

### Same-paper round trip

The intended round trip is:

`Smart Mode -> Word Mode -> Smart Mode -> Word Mode`

without making a duplicate paper. Word free content, structured questions, options, marks, tables, attachments, math and geometry remain attached to the same canonical document.

### Preview / PDF / Word export

Free Word blocks are rendered without assessment numbering or `[0]` marks in:

- paper preview
- PDF export
- Word export

Existing structured assessment questions continue numbering around the free content.

## Production files added

- `lib/features/paper_composer/application/word_content_block_service.dart`
- `lib/features/paper_composer/presentation/widgets/word_rich_text_editor.dart`

## Existing production areas updated

- canonical Paper/Question model behavior
- editor provider and composer actions
- paper structure / validation / performance accounting
- Word Mode editor surface
- Smart Mode section/question cards and outline
- preview numbering/rendering
- PDF and Word export numbering/rendering
- OMR question count

## QA added

Coverage added for:

- Word block JSON round trip
- numbering / Answer Any / marks exclusion
- validator and performance exclusion
- table/image free-block preservation
- Smart <-> Word free-paragraph round trip
- Word export without `[0]` assessment chrome

## Deliberate Step-8 boundary

Step 8 is the **editing surface**, not a full Microsoft Word clone.

The following remain intentionally for later steps:

- exact page margins / orientation / page-size controls
- headers and footers as free page-layout regions
- manual page-break/text-box positioning
- arbitrary floating-object positioning
- full DOCX formatting import/export parity

Those belong to Step 9 (page/layout tools) and Step 10 (lossless Smart/Word/DOCX round trip) rather than being faked in this phase.

## Validation commands

Run on the real Flutter workstation after applying the modified files:

```powershell
dart format .
flutter analyze
flutter test
```

This packaging environment does not contain Flutter/Dart, so it does not claim runtime test execution here.
