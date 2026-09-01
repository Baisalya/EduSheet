# EduSheet Professional Formatting Polish

Baseline: RC Candidate 1 QA Fix, with the Step 1-10 architecture already locked by the user's Windows QA.

## Scope

Focused paper-presentation controls only. No DB migration, pubspec/dependency change, new editor architecture, or assessment semantics change.

## New canonical formatting controls

### Paper-level
- General instruction alignment: Left / Center / Right.

### Section-level
- Heading alignment: Left / Center / Right.
- Section instruction alignment: Left / Center / Right.
- Auto-generated answer-rule alignment: Left / Center / Right.
- Independent top rule and bottom rule toggles.
- Optional `Instruction:` label.

### Question-level
- Question-specific instruction is now rendered instead of being metadata-only.
- Question-specific instruction has its own Left / Center / Right alignment.

## Output parity

The same canonical values are used by:
- Smart/section formatting UI
- Word Mode
- Paper Preview
- PDF export
- DOCX export

Question-specific instructions are included for nested questions too.

## Backward compatibility

- Existing `PaperSection.showDivider` remains as a compatibility alias for the lower rule.
- Legacy JSON without the new fields defaults safely.
- No migration is required.
- Old saved papers retain their question/marks/numbering/content behavior.

## Added QA

`test/features/editor/professional_paper_formatting_test.dart`

Covers:
- legacy defaults
- new field JSON round-trip
- legacy divider compatibility
- question-specific instruction alignment persistence

## Run on Windows

```powershell
dart format .
flutter analyze
flutter test test/features/editor/professional_paper_formatting_test.dart
flutter test test/features/pdf/office_export_services_test.dart
flutter test test/release
flutter test
```

After automated QA, visually test a paper using all three alignments, top/bottom section rules, section instruction label on/off, and question-specific instructions in Preview/PDF/DOCX.

Flutter/Dart runtime is not installed in the assistant container, so no runtime-pass claim is made here.
