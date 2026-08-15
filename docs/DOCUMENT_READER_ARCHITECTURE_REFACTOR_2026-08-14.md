# EduSheet Document Reader Architecture Refactor — 2026-08-14

## Scope

This refactor rebuilds the EduSheet document-reader/open-with path for Android and Windows without adding or upgrading dependencies. It deliberately does not modify the PDF/Word/Excel/PPT export services or calculator feature.

## Architecture

External and internal opens now converge on one request/session pipeline:

`DocumentOpenRequest -> DocumentOpenCoordinator -> DocumentRepository -> DocumentSession -> FilePreviewScreen -> format-specific viewer`

The request records its source (Reader, File Picker, Android VIEW/SEND, or Windows command line), local working path, original URI where available, MIME type, display name, and platform activation identity.

### Activation behavior

- Android cold start: `getInitialDocument` resolves the incoming VIEW/SEND intent and routes directly to the document viewer.
- Android warm start: `onNewIntent` sends the resolved document over the existing Flutter MethodChannel.
- Android `content://` sources: copied into an app cache with metadata preservation, filename sanitization, duplicate-safe names, a 1 GiB import safety ceiling, partial-copy cleanup, and 72-hour stale-cache cleanup.
- Windows cold start: command-line file paths are parsed by Dart and routed through the same coordinator.
- Windows warm start: a named mutex prevents a second heavy Flutter UI from being created. The second process forwards the UTF-8 file path to the existing window with `WM_COPYDATA`; the existing runner sends it to Dart over the same document activation MethodChannel. Activations arriving before the first Flutter frame are queued until Dart is ready.
- Windows per-user Open-With integration: `REGISTER_WINDOWS_FILE_ASSOCIATIONS.ps1` registers supported extensions under HKCU only. It does not change the default application and does not require admin rights. `UNREGISTER_WINDOWS_FILE_ASSOCIATIONS.ps1` removes those entries.

The project does not currently contain an MSIX/AppxManifest packaging configuration, so a Microsoft Store package-level file-type declaration was not invented. Store packaging should add the equivalent associations in the real package manifest when that packaging source is available.

## Format capability policy

### PDF — full in-app viewer

Uses the existing Syncfusion PDF viewer dependency.

- native PDF rendering
- page navigation and page jump
- text search with previous/next result navigation
- zoom controls and double-tap zoom
- Windows keyboard controls
- compact phone toolbar and desktop toolbar
- load failure/retry state

### DOCX — responsive in-app viewer

Uses the already-authorized `docx_file_viewer` package.

- paged DOCX rendering
- built-in zoom
- responsive page width for phone, tablet/free-form, and Windows
- dark/light surrounding canvas

Legacy `.doc`, `.rtf`, and `.odt` are recognized but intentionally routed to an external viewer because the existing authorized renderer cannot promise faithful in-app rendering for them.

### XLSX / CSV — virtualized data viewer

Parsing is removed from the UI screen and runs through a dedicated service using `compute`.

XLSX support includes:

- OOXML workbook relationship parsing
- workbook sheet order/name discovery
- shared strings and inline strings
- booleans and cached/raw values
- sparse row numbers
- multiple sheets
- parser limits to protect memory: 50,000 rows per sheet, 512 columns, and 1,000,000 parsed cells per workbook

CSV support includes quoted commas, escaped quotes, and multiline quoted fields.

The UI no longer builds a giant `DataTable`. It uses a lazy vertical list and custom painting that paints only the visible column range for each visible row. Horizontal/vertical scrolling and sheet selection are retained across phone and desktop layouts.

This is a performant data preview, not a full Excel layout engine: complex cell styling, formulas requiring recalculation, charts, macros, and Excel-specific object rendering are outside the current authorized dependency stack.

Legacy `.xls`, `.ods` are recognized and handed to an external app.

### PPTX — structured presentation viewer

PPTX parsing is removed from the UI and performed through a dedicated OOXML parser service using `compute`.

Supported presentation structure includes:

- presentation slide dimensions/aspect ratio
- actual slide ordering through presentation relationship IDs (`r:id`)
- positioned text shapes
- basic font size/bold/alignment/text color
- simple solid shape fills and slide background color
- embedded images through slide relationships
- readable text fallback for unsupported graphic frames
- thumbnails on wide layouts
- swipe, keyboard, and button navigation
- full presentation mode
- supported slide transitions mapped to smooth Flutter fade/push/wipe/split/cover/uncover/zoom transitions
- native PowerPoint timing/object-animation presence detection

EduSheet does **not** claim to execute arbitrary PowerPoint object animation timelines. When a deck contains native animation timing, the viewer explicitly warns that the slide layout and supported slide transitions are preserved but arbitrary Office object animation sequences are not fully executed by the current authorized stack.

Legacy `.ppt` and `.odp` are recognized and handed to an external viewer.

### TXT

- asynchronous line loading
- malformed UTF-8 tolerance
- lazy line rendering
- large-file line safety limit
- user text-size controls

## Reader performance changes

- Removed synchronous recursive filesystem scanning from document discovery.
- Bounded discovery to selected app/user roots and depth.
- Skips common build/cache/hidden directories.
- Caps discovery to 1,200 documents per refresh.
- Office archive/XML parsing is moved out of widget build methods and off the UI isolate.
- Large spreadsheet widgets are virtualized instead of eagerly constructing all cells.
- Viewer controllers and focus nodes have explicit lifecycle disposal.

## Android Open With

The existing Android VIEW/SEND filters are preserved for:

PDF, DOC/DOCX, RTF/ODT, XLS/XLSX/CSV/ODS, PPT/PPTX/ODP, and TXT MIME types.

Package-visibility VIEW queries were completed for the same external fallback families so Open externally remains dependable on modern Android.

Expected flow after installing the APK/AAB:

1. Tap a supported document in Files/Downloads/another app.
2. Android can list EduSheet as a matching viewer.
3. Selecting EduSheet launches/reuses the singleTop activity.
4. The incoming URI is validated/copied when necessary.
5. EduSheet navigates directly to the correct format viewer.

## Windows Open With

For an unpackaged/dev Windows build:

```powershell
flutter build windows
.\REGISTER_WINDOWS_FILE_ASSOCIATIONS.ps1
```

Or point at a specific installed executable:

```powershell
.\REGISTER_WINDOWS_FILE_ASSOCIATIONS.ps1 -ExePath "C:\Path\To\edusheet.exe"
```

To remove the per-user associations:

```powershell
.\UNREGISTER_WINDOWS_FILE_ASSOCIATIONS.ps1
```

The script registers EduSheet under Open With and does not forcibly replace the user's current default application.

## Automated tests added

- capability-policy tests
- Android activation metadata test
- Windows warm activation metadata test
- internal-open repeatability vs platform duplicate suppression
- cached incoming file with original-extension recovery
- Windows command-line path-with-spaces test
- CSV quoted/multiline parsing
- XLSX multiple OOXML structures, sparse rows and values
- PPTX relationship-order regression test
- PPTX slide geometry/style/transition/native-animation detection
- 320x720 compact viewer widget checks
- 1280x800 Windows viewer widget checks
- legacy-format capability-honesty widget test

## Source-level QA performed in this environment

- AndroidManifest XML parsing: PASS
- Dart delimiter/lexical balance across the document-reader scope and `main.dart`: PASS
- Java/C++/PowerShell structural delimiter checks: PASS
- `pubspec.yaml`: unchanged from baseline
- `pubspec.lock`: unchanged from baseline
- no new dependency was added
- no placeholder implementations or `UnimplementedError` were introduced in the modified reader scope

## Runtime QA still required on the user's Flutter environment

This execution environment does not contain Flutter/Dart/Android/Windows SDK toolchains, so it cannot truthfully certify compilation or runtime tests. Run:

```powershell
flutter pub get
flutter analyze
flutter test test/features/document_reader
flutter test
flutter run -d windows
```

Then manually verify:

1. PDF search/page/zoom on Windows and Android.
2. DOCX long file scrolling/zoom.
3. XLSX with several sheets and a large worksheet.
4. CSV with quotes/newlines.
5. PPTX with reordered slides, images, transitions, portrait and 16:9 decks.
6. Android Files -> Open with EduSheet, both cold and warm app state.
7. Windows Explorer -> Open with EduSheet after running the registration script, both cold and warm app state.
8. Resize the Windows window and Android free-form window down to compact widths and check for overflow.
9. Existing question-paper PDF/DOCX/XLSX/PPTX export regression.
10. Existing calculator regression.
