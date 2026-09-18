# EduSheet Word Converter Phase 5 — Windows Preserve Appearance Parity

## Scope
Phase 5 closes the known Windows capability gap for PDF → Word · Preserve Appearance without changing the Phase 1–4 conversion architecture.

## Implementation
- Added a native Windows `edusheet/pdf_renderer` MethodChannel implementation.
- Uses built-in `Windows.Data.Pdf.PdfDocument` and `PdfPage.RenderToStreamAsync`.
- Renders explicit PNG output with high-contrast recoloring disabled.
- Uses bounded scale and render dimensions.
- Writes pages into a unique system-temp directory and removes partial native output on renderer failure.
- Existing Dart cleanup deletes successful rendered page files/directories after DOCX packaging.
- `supportsPdfAppearancePreservation` now enables Android + Windows.
- Converter UI no longer disables Preserve Appearance on Windows.
- Appearance-preserved DOCX now creates per-page section boundaries so mixed page sizes/orientations are not flattened to the final PDF page geometry.

## Intentionally unchanged
- PDF → Word · Editable Document geometry/OCR engine.
- Word → PDF structured fidelity engine.
- Phase 4 save/cancel/history/atomic-write contracts.
- Android native renderer behavior.
- No third-party PDF rendering dependency or external executable added.

## Gate
Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_word_converter_phase5_gate.ps1
```

The Phase 5 gate preserves the Phase 1–4 regressions, verifies the Windows renderer source contract, compiles the Android renderer, and performs a real Windows debug build so the C++/WinRT bridge is compiler-validated on the target platform.

## Validation note
The ChatGPT container used to prepare this phase does not contain the Flutter/Dart SDK or a Windows toolchain, so no local claim of `flutter analyze`, Flutter tests, or C++/WinRT compilation is made. The target-machine Phase 5 gate is the release authority.
