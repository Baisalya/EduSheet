# Inline Math Question Authoring — 2026-08-13

## Teacher workflow

1. Put the caret anywhere in the Question rich-text field.
2. Tap **Math**.
3. Build the expression visually with the structured math keyboard.
4. Tap **Add formula**.
5. The formula is inserted at the original caret position as one Quill embed character and renders as textbook mathematics.
6. Continue typing immediately after it.
7. Tap an existing inline formula to reopen the same visual formula editor.

Example intent:

`The equation is [visual formula]. Find the roots.`

The formula is no longer displayed as a separate formula card for newly authored questions.

## Compatibility

- Existing Question.text remains Quill Delta JSON.
- MathExpression remains the canonical formula model.
- Question.mathExpressions remains a compatibility/export index and is synchronized from inline embeds when saving.
- Older questions whose formulas were stored separately are not guessed into arbitrary sentence positions. They appear in a small migration tray and can be inserted at the teacher's cursor.
- Geometry remains separate and continues to use the existing geometry block embed.
- No package or database/schema dependency was added.

## Export behavior

Flutter UI previews render the structured formula visually inline.

The existing PDF/Word/PowerPoint export pipelines do not have a TeX layout engine for inline formulas, so without adding a new dependency they preserve each formula's accessibility/plain-text fallback at the exact sentence position. Inline formulas are excluded from the old below-question formula loop to prevent duplicates.

## QA added

- Inline formula Delta round-trip.
- Formula accessible text stays in sentence order.
- Embedded formulas are not treated as legacy/unplaced formulas.
- Office text fallback preserves formula position.
- Missing local import scan: 0.
- Changed-file delimiter scan: 0.

Run locally:

```powershell
flutter analyze
flutter test
flutter test integration_test/question_creation_journey_test.dart -d windows
```
