# Step 10 — Safe Smart ↔ Word Round-Trip & Export Parity

## Goal

Keep `Paper` as EduSheet's single source of truth while allowing an EduSheet-exported DOCX to be reopened safely after supported Word edits.

## What Step 10 adds

- DOCX custom XML envelope (`customXml/edusheet-smart-paper.xml`) containing the exact canonical `Paper.toJson()` snapshot.
- Versioned round-trip metadata (v2) with body, header/footer and style fingerprints.
- Invisible Word content-control tags (`w:sdt`) around supported editable fields:
  - paper instruction, school name and paper title when rendered by the template;
  - section title and section instruction;
  - question / Word-paragraph text;
  - question marks;
  - answer-option text;
  - nested sub-question and internal-choice text/marks/options.
- A structural skeleton fingerprint that ignores only EduSheet-tagged editable content. This allows text edits inside supported fields while detecting unsupported structural edits.
- Per-editable-field baseline fingerprints so a Word file that was merely rewritten does not flatten EduSheet's richer canonical content.
- Safe merge of supported external Word edits back into the canonical `Paper`.
- Basic Word run formatting import for rich question / Word-paragraph text: bold, italic, underline, strike, superscript and subscript.
- Exact preservation of all untouched Smart Paper structures through the embedded canonical snapshot, including:
  - Math/Geometry metadata;
  - passage/case-study advanced content;
  - tables;
  - images/attachments;
  - sub-questions and OR choices;
  - custom Word blocks;
  - marks/numbering semantics;
  - page size/orientation/margins;
  - headers/footers/page numbers;
  - legacy/custom metadata.
- Non-destructive refusal when Word changes unsupported structure, page styles/header/footer parts, table/image structure, or question text containing an inline Math/Geometry embed whose position cannot be reconstructed safely.
- Compatibility with unchanged Step-10 DOCX and unchanged legacy v1 EduSheet round-trip files.
- Word Mode `Import Word` entry point on Android and Windows responsive surfaces.

## Safety contract

Step 10 never treats a DOCX as a second canonical document model.

1. **Unchanged EduSheet DOCX** → exact canonical restore.
2. **Only supported tagged Word fields changed** → safe merge into canonical Smart Paper.
3. **Unsupported/structural external edit** → current paper is not replaced.
4. **Ordinary non-EduSheet DOCX** → no lossy conversion is attempted.

This is intentionally conservative. Losing a Word-only edit is preferable to silently corrupting a structured question paper, so unsupported edits are surfaced rather than guessed.

## QA coverage added

- exact canonical Paper JSON DOCX restore;
- supported question text + basic rich-format merge;
- marks and MCQ option merge;
- custom Word block preservation;
- page-layout and metadata preservation;
- structural external edit rejection;
- style/header/footer companion-part protection;
- Math/Geometry embed non-flattening protection;
- ordinary external DOCX rejection;
- actual `WordExportService` package integration;
- Step-10 release-gate exact round-trip, safe merge and destructive-edit refusal;
- responsive Word Mode import control presence.

## Runtime verification

The model environment used to prepare this phase does not contain Flutter/Dart, so run on the project workstation:

```powershell
dart format .
flutter analyze
flutter test test/features/paper_composer/smart_paper_docx_round_trip_service_test.dart
flutter test test/features/pdf/office_export_services_test.dart
flutter test test/release
flutter test
```
