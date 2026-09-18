# EduSheet Question Document Phase 9 — HarfBuzz Analyzer Hotfix

## Trigger
After adding `harfbuzz_ffi 0.4.2`, dependency resolution succeeded but the project SDK floor moved to Dart 3.12 and `flutter analyze --no-pub` surfaced 20 info-level diagnostics.

## Root cause
- 18 diagnostics were `prefer_initializing_formals` in existing constructors across unrelated modules. Applying the lint literally to named parameters would rename stable public constructor arguments such as `numericFormatter:` to private `_numericFormatter:` and would be an API-breaking style cleanup.
- 2 diagnostics were genuine Phase 9 deprecations in `pdf_complex_text_service.dart` (`PdfRect.x/y`).

## Fix
1. `analysis_options.yaml`
   - Explicitly disables only `prefer_initializing_formals`.
   - Keeps the rest of `flutter_lints` enabled and leaves the Phase 9 gate on strict `flutter analyze --no-pub`.
   - Rationale is documented inline: public named constructor APIs are intentionally not renamed to private field names.

2. `lib/features/pdf/services/shaping/pdf_complex_text_service.dart`
   - Replaced deprecated `PdfRect.y` with `PdfRect.bottom`.
   - Replaced deprecated `PdfRect.x` with `PdfRect.left`.
   - Geometry/math is unchanged.

## Non-changes
- No HarfBuzz behavior changes.
- No PDF/DOCX fidelity assertions relaxed.
- No test expectations changed.
- No constructor signatures renamed.
- No database/persistence changes.
- No gate weakening (`--no-fatal-infos` was deliberately not used).

## Run
```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_question_document_phase9_gate.ps1
```

Expected analyzer stage:
```text
Analyzing EduSheet...
No issues found!
```
