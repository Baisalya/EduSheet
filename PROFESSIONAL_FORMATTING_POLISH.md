# Professional Paper Formatting Polish

Baseline: RC Candidate 1 QA Fix / Step 10 locked architecture.

This pass adds teacher-facing printed-paper formatting controls without changing
the editor architecture, database, dependencies, or assessment semantics.

## Implemented

- General instructions can be aligned Left / Center / Right.
- Section heading can be aligned Left / Center / Right.
- Section instruction can be aligned Left / Center / Right.
- Auto-generated answer rule can be aligned Left / Center / Right.
- Section rule above the heading and rule below the heading are independent.
- Optional `Instruction:` label for section instructions. Off prints exactly what
  the teacher typed.
- Question-specific instructions are now actually rendered in Word Mode,
  Preview, PDF and DOCX.
- Question-specific instructions have an independent Left / Center / Right
  alignment in Advanced question details.
- Preview, Word Mode, PDF and DOCX read the same canonical formatting fields.
- Legacy `showDivider` is retained as a compatibility alias for the lower rule;
  old saved papers continue to deserialize without migration.
- Existing papers receive safe defaults: general instruction left; section
  heading/instruction/answer rule center; top rule off; lower rule follows the
  legacy divider value.

## Intentionally not included in this pass

- database/schema migration
- dependency changes
- new editor mode
- arbitrary fonts/colors
- question numbering/marks behavior changes

## QA

Run on the Windows release workstation:

```powershell
dart format .
flutter analyze
flutter test test/features/editor/professional_paper_formatting_test.dart
flutter test test/features/pdf/office_export_services_test.dart
flutter test test/release
flutter test
```

Then visually smoke-test one paper with left/center/right section headings,
both rule toggles, aligned general/section/question instructions, and PDF/DOCX
exports.
