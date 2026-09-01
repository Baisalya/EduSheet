# EduSheet Step 10 — Safe Smart ↔ Word Round-Trip & Export Parity

Baseline: Step 9 QA-locked project (`97ad1bc`).

## Completed scope

- Keeps `Paper` as the single canonical source of truth.
- Adds a versioned DOCX round-trip envelope containing the exact canonical Smart Paper JSON.
- Adds invisible Word `w:sdt` tags around supported editable fields.
- Exact unchanged EduSheet DOCX → exact canonical restore.
- Supported external Word edits → safe merge back into the canonical paper.
- Supported merged fields include question / Word-paragraph text, marks, MCQ option text, nested question text/marks/options, section title/instruction, paper title/school/instruction where tagged.
- Basic external Word run formatting is retained for rich question / Word-paragraph text: bold, italic, underline, strike, superscript, subscript.
- Per-field baselines prevent a simple Word rewrite from flattening richer EduSheet content.
- Structural skeleton fingerprint allows only tagged edits; unsupported new paragraphs/layout/table/image structure changes are rejected instead of guessed.
- Header/footer/style companion fingerprints protect Step-9 layout semantics.
- Inline Math/Geometry embeds are protected: if external Word text editing would make their position ambiguous, import is refused rather than flattening/removing the embed.
- Exact snapshot preservation keeps advanced content, tables, images, custom Word blocks, subquestions, OR choices, page layout, legacy metadata and marks semantics intact.
- Legacy v1 EduSheet round-trip documents remain exactly restorable when unchanged.
- Ordinary non-EduSheet DOCX files are detected and are not lossy-converted.
- Word Mode now exposes `Import Word` on responsive Android/Windows surfaces.
- Added Step-10 unit, integration and release-gate coverage.

## Changed project files

See `EduSheet_Step10_CHANGED_FILES.txt`.

## Static QA performed in the model environment

- `git diff --check`: clean.
- All changed `package:edusheet/...` imports resolve to project files.
- No merge-conflict markers in changed files.
- Step-10 contract markers verified in round-trip service/exporter.
- Full and modified ZIP CRC/integrity checks are performed after packaging.

Flutter/Dart executables are not installed in this environment, so runtime test success is intentionally not claimed here.

## Workstation release gate

```powershell
dart format .
flutter analyze
flutter test test/features/paper_composer/smart_paper_docx_round_trip_service_test.dart
flutter test test/features/pdf/office_export_services_test.dart
flutter test test/release
flutter test
```

Expected target: analyzer clean, Step-10 round-trip tests pass, release gate passes, full suite passes.
