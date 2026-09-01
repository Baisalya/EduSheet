# EduSheet — Professional Formatting Polish Phase 2

Baseline: Professional Formatting Polish Phase 1 (Windows QA: analyzer clean, focused +3, office export +16, release +14, full suite +318).

## Added
- Section heading presets: Plain / Underline / Ruled / Boxed.
- Section heading typography: bold toggle, uppercase presentation, Small / Normal / Large.
- Section marks display: Hidden / inline `(20 Marks)` / right edge `20 Marks`.
- Section spacing: Compact / Normal / Spacious.
- Teacher-facing `Keep heading with first question` control (existing canonical `keepTogether` field).
- Question marks placement per section: Inline or Right edge.
- Preview, Word Mode, PDF and DOCX consume the same canonical settings.
- DOCX right-edge marks use Word right-tab stops; uppercase uses `w:caps` so canonical title text is not destructively uppercased.
- DOCX keep-with-first-question emits `w:keepNext` through the section heading chain.
- PDF keep-with-first-question groups heading + first question only when the first question is safe/small enough; complex first questions fall back to normal pagination rather than risking an oversized unbreakable widget.
- Added focused persistence/export tests and a release gate.

## Backward compatibility defaults
Old papers that do not contain Phase 2 fields resolve to:
- bold heading = ON
- uppercase = OFF
- boxed = OFF
- heading size = Normal
- section spacing = Normal
- section marks = Hidden
- question marks = Right edge
- keepTogether retains its existing default

No DB/schema migration. No dependency change. No document-model fork.

## Windows QA
Run:

```powershell
dart format .
flutter analyze
flutter test test/features/editor/professional_paper_formatting_test.dart
flutter test test/features/pdf/office_export_services_test.dart
flutter test test/release
flutter test
```

Assistant environment does not contain Flutter/Dart, so no runtime pass is claimed until Windows QA confirms it.
