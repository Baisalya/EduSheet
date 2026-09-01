# EduSheet RC Candidate 1 — Real-device Production Polish

Baseline: Step 10 QA lock (`flutter analyze` clean, release suite passed, full suite `+308`).

## RC1 changes

### 1. Offline-first PDF font resolution

Question-paper PDF export and Word-to-PDF conversion now share `PdfExportThemeService`.

Release-platform behavior:

- Windows prefers installed Nirmala UI + Segoe UI Symbol/Arial variants.
- Android prefers installed Noto Sans + Noto Math/Symbol/Indic fallbacks.
- The existing Google-font resolver remains a compatibility fallback when a suitable local base font is unavailable.
- A final built-in PDF font theme prevents an offline font-fetch failure from becoming an export exception.
- Theme resolution is cached and reused by both export paths.

This removes the previous unconditional network dependency from the normal Windows/Android export path and specifically targets Hindi/Odia/Indic + mathematical paper reliability.

No font files are added to the repository and no dependency changes are required.

### 2. Narrow real-device authoring gate

A dedicated RC release gate checks:

- 360px Android Word Mode keeps Paragraph reachable/tappable before secondary tools.
- Math, Geometry and Import Word remain present after paragraph insertion.
- 520px free-form Windows Word Mode renders without layout exceptions.
- Windows and Android system-font plans contain the expected Indic/math coverage paths.

### 3. RC production command

`tool/run_rc_candidate_1_gate.ps1`

Runs:

1. format check
2. analyzer
3. font resolver + autosave + large-paper + dual-editor focused tests
4. all release gates
5. complete Flutter test suite
6. optional Windows/Android release builds

Examples:

```powershell
.\tool\run_rc_candidate_1_gate.ps1
.\tool\run_rc_candidate_1_gate.ps1 -BuildWindows
.\tool\run_rc_candidate_1_gate.ps1 -BuildWindows -BuildAndroid
```

## Real-device smoke checklist

### Android

- Create a section and type a normal question with the software keyboard open.
- Insert Math, return to the question, and verify cursor/focus returns correctly.
- Insert Geometry, return, and verify the document scroll position is sensible.
- Switch Smart -> Word -> Smart after unsaved typing.
- Export a paper containing English + Hindi/Odia + `− × ÷ √ π` with Wi-Fi/mobile data disabled.
- Preview/share/open the generated PDF.

### Windows

- Repeat Word authoring at 520px width and maximized width.
- Resize while a rich-text field is active.
- Open Page Setup and close it at narrow width.
- Export the same multilingual/math paper while offline.
- Open DOCX in Microsoft Word, edit supported content, import it back into EduSheet.

## Not changed

- no DB/schema migration
- no package upgrades
- no new editor/document model
- no Smart/Word conversion layer change
- no store/version bump in RC1
