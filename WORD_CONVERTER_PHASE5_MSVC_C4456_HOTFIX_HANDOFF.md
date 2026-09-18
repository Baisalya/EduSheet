# EduSheet Word Converter Phase 5 — MSVC C4456 Hotfix

## Baseline
Phase 5 Windows Preserve Appearance parity source.

## Gate failure
`windows/runner/pdf_renderer_bridge.cpp` failed Windows native compilation because MSVC warning C4456 was promoted to an error by `/WX`:

- an `int32_t` branch declared local pointer `value`
- the following `int64_t` branch redeclared another local pointer also named `value`

## Fix
In `ReadScale()` only:

- renamed first pointer to `int32_value`
- renamed second pointer to `int64_value`

No runtime behavior, PDF rendering, scaling, channel contract, progress, cancellation, temp cleanup, Android implementation, or DOCX writing behavior changed.

## Validation
Re-run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_word_converter_phase5_gate.ps1
```

The decisive stage is `Windows native PDF renderer compile`.
