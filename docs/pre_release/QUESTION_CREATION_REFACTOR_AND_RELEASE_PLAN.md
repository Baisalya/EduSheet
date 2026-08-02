# EduSheet Question Creation Refactor and Release Plan

Last updated: 2026-07-19

## Executive summary

EduSheet already has useful offline paper editing, Quill rich text, a broad custom mathematical keyboard, geometry embeds, question-bank reuse, custom PDF headers, Word-style section editing, OMR and multi-format export. The pre-release audit nevertheless found two release-critical risks: persistence errors are swallowed and subsequent saves can overwrite unreadable data, while autosave starts an uncoordinated write for every state mutation. The question model also supports only three types and stores rich content in a legacy string without typed formula metadata.

This plan keeps the existing app and introduces backward-compatible versioned models, atomic persistence, debounced serial autosave, reusable content templates, composer validation, export configuration/booklet ordering, and behavior-focused tests. No existing user file will be reset or deliberately discarded.

Current verdict: **NOT RELEASE READY**. Flutter and Dart are not installed in this execution environment, so analyzer, Flutter tests, Android builds, real-device UX, and rendered-PDF inspection remain external release gates even after locally reviewable implementation is complete.

## Baseline and repository provenance

- Uploaded archive: `EduSheet-master(3).zip`.
- Original Git branch/status/history: unavailable because the archive contained no `.git` directory.
- Working branch created for traceability: `codex/question-creation-refactor`.
- Imported baseline commit: `1614f0c`.
- Source files in imported baseline: 267.
- Existing automated test files: 7.
- Flutter/Dart baseline: blocked; neither executable exists in the environment.
- Dependency installation: blocked by missing Flutter SDK.
- Static analysis and formatting: blocked by missing Flutter/Dart SDK.
- Unit/widget/integration tests: blocked by missing Flutter SDK.
- Android and other platform builds: blocked by missing Flutter SDK; Android wrapper JAR is also absent from the uploaded archive.

## Current architecture

| Concern | Current implementation | Finding |
| --- | --- | --- |
| UI | Material 3 screens and large `CreatePaperScreen` | Mobile responsive in several places, but composer screen is monolithic. |
| State | Riverpod generated `EditorState` | Clear mutation API; autosave is unbounded and has no error state. |
| Persistence | JSON files in app documents directory | Offline, but non-atomic and errors are converted to empty lists. |
| Rich text | Flutter Quill Delta serialized into `Question.text` | Backward compatible but format is implicit and math is not canonical. |
| Mathematics | Custom symbol catalogue and `math_keyboard` integration | Broad symbol coverage; favourites/search/persisted recents and typed formula fallback need completion. |
| Templates | PDF visual templates plus question bank | No independent question/section/paper blueprint library with safe copy semantics. |
| PDF | `pdf`/`printing` services and custom layout builders | Strong base; export modes, validation and booklet imposition need explicit models/tests. |
| Tests | 7 unit/widget files | Good focused legacy coverage, insufficient for model migration and release gates. |

## Current user flow

1. Home → Create Paper resets editor state.
2. Teacher configures template/header/branding and adds sections.
3. Questions are created in a bottom sheet or imported from the question bank; section Word mode is also available.
4. Every state change immediately calls file persistence without awaiting or serializing the prior write.
5. Preview uses Quill/geometry widgets; PDF and Office exporters consume the same `Paper` object.
6. Saved papers are reloaded from a single JSON array.

## Existing strengths

- [x] Offline-first local storage.
- [x] Stable IDs for papers, sections, questions and options.
- [x] Section/question drag ordering and duplication.
- [x] Rich Quill content, OCR and geometry embedding.
- [x] Broad school-level mathematics symbol catalogue.
- [x] Custom header designer, multiple logos and configurable numbering.
- [x] PDF, Word, presentation and spreadsheet export foundations.
- [x] Question bank and Save & Next workflow.

## Problems and risks

### Data-loss and migration risks

- [ ] Replace destructive/non-atomic JSON writes with temp-file + flush + backup + rename.
- [ ] Stop converting corrupt/read failures to an empty collection.
- [ ] Serialize autosaves and debounce high-frequency edits.
- [ ] Add a schema envelope while continuing to read the legacy top-level list.
- [ ] Preserve unknown custom metadata and old enum indices.
- [ ] Record modification/version/draft status in the domain model.

### UX problems

- [ ] Expose all question types through a compact searchable picker.
- [ ] Add visible save/saving/error status, undo and redo.
- [ ] Support add above/below and moving questions between sections.
- [ ] Confirm destructive section/question/paper operations.
- [ ] Provide composer warnings without blocking ordinary editing.
- [ ] Keep controls keyboard-safe with at least 48dp touch targets.

### Mathematical input limitations

- [ ] Store formula source, display mode and accessible fallback canonically.
- [ ] Validate malformed formula source without discarding it.
- [ ] Complete symbol search/favourites/recent persistence.
- [ ] Add explicit chemistry, mixed-fraction, piecewise and scientific-notation templates.
- [ ] Use safe plain-text fallback in editor/export paths.

### Template limitations

- [ ] Add independent immutable question templates.
- [ ] Add section templates and full paper blueprints.
- [ ] Resolve smart variables deterministically and report unresolved variables.
- [ ] Ensure insertion creates new IDs and never mutates the template.
- [ ] Provide offline starter blueprints.

### PDF/print limitations

- [ ] Model standard, booklet, answer-key, solution, student, worksheet, compact and large-print modes.
- [ ] Add deterministic booklet page ordering and blank-page rules.
- [ ] Validate page size/orientation/margins/gutter before export.
- [ ] Document that printer-specific duplex behavior cannot be guaranteed by the app.

### Accessibility, localization and performance

- [ ] Add semantic labels for question type, save state and math controls.
- [ ] Ensure formula models include a readable alternative.
- [ ] Avoid colour-only validation and preserve text scaling.
- [ ] Cache formula validation and keep large-list operations linear.
- [ ] Add 100/300/500-question service-level performance checks.
- [ ] Centralize newly added user strings for English/Hindi fallback.

## Proposed architecture

```text
Mobile editor / composer
        ↓
EditorState + AutosaveCoordinator + PaperValidator
        ↓
Versioned Paper / Question / MathExpression / Template models
        ↓
Atomic repositories (legacy reader → schema migration → safe writer)
        ↓
Preview + ExportConfig + BookletImpositionService + PDF services
```

Boundaries:

- UI owns focus, gestures and confirmations only.
- Domain models own serialization-safe data and copy semantics.
- Services own validation, variable resolution, migration and page ordering.
- Repositories own file-system behavior and never hide data corruption.
- Exporters receive an immutable snapshot and explicit export configuration.

## Database/file migration strategy

EduSheet uses JSON files rather than a relational database. Migration will therefore be versioned at the JSON-document and model levels.

- [ ] Read existing top-level JSON arrays unchanged.
- [ ] Parse legacy three-value `QuestionType` indices without reordering them.
- [ ] Derive plain-text accessibility content from legacy rich text when absent.
- [ ] Wrap the next successful write in `{schemaVersion, updatedAt, items}`.
- [ ] Retain a `.bak` copy of the last valid file before replacement.
- [ ] Recover from backup only after validating the primary file.
- [ ] Never reset files as a migration technique.

## Phased implementation

### Phase 0 — Baseline audit and safety

Status: COMPLETE (code complete; Flutter execution remains globally blocked by missing SDK)

- [x] Inventory entry points, models, state, persistence, math, template, preview and export code.
- [x] Read supplied and repository documentation.
- [x] Record missing Git metadata and local SDK blockers.
- [x] Add regression/migration fixtures for legacy paper JSON.
- [x] Commit the baseline plan and tests.

Acceptance: baseline is reproducible, risks are documented, and old JSON behavior is captured before model changes.

### Phase 1 — Question domain and safe migration

Status: COMPLETE (code complete; tests authored but not executable in this environment)

- [x] Add all required question types without changing legacy enum indices.
- [x] Add typed math expression, attachments, tables, subquestions, internal choices and extensible metadata.
- [x] Add question metadata/version/draft timestamps.
- [x] Add backward-compatible serializers and migration tests.

Acceptance: legacy JSON remains readable; new data round-trips without loss; IDs remain immutable.

### Phase 2 — Mobile-first editor and state safety

Status: COMPLETE (code complete; tests authored but not executable in this environment)

- [x] Add full type selection and type-aware answer controls.
- [x] Add serialized debounced autosave and visible status.
- [x] Add undo/redo, insert positioning and move-between-section APIs.
- [x] Add confirmation hooks and continuous Save & Next behavior.

Acceptance: rapid edits cannot create concurrent writes; teacher content survives navigation and state restoration.

### Phase 3 — Complete template system

Status: COMPLETE (code complete; tests authored but not executable in this environment)

- [x] Implement question, section and paper blueprint models/repository.
- [x] Implement safe duplication, filters, starter templates and variable resolution.
- [x] Integrate save/insert actions into the editor/composer.

Acceptance: inserted records have new IDs and later edits cannot mutate their source template.

### Phase 4 — Mathematical keyboard and formula editor

Status: COMPLETE (code complete; tests authored but not executable in this environment)

- [x] Complete catalogue gaps, search, favourites and recent symbols.
- [x] Add canonical source + fallback validation and resilient preview.
- [x] Verify cursor-aware insertion/navigation code paths and accessibility labels.

Acceptance: required symbol families are reachable without raw LaTeX; malformed source remains editable and non-crashing.

### Phase 5 — Composer and validation

Status: COMPLETE (code complete; tests authored but not executable in this environment)

- [x] Add section duplication/move/numbering/page-break settings.
- [x] Add real-time validation for marks, empty sections, attempt rules and variables.
- [x] Add answer-space/cover/header/footer configuration models.

Acceptance: warnings identify inconsistencies while preserving editing freedom.

### Phase 6 — Preview, PDF and booklet export

Status: COMPLETE (code complete; tests authored but not executable in this environment)

- [x] Add explicit export modes/config validation.
- [x] Add answer/solution visibility policy and set labels.
- [x] Add booklet imposition, gutter/mirror settings and duplex guidance.

Acceptance: export configuration and booklet ordering are deterministic and unit tested.

### Phase 7 — Offline reliability and data protection

Status: COMPLETE (code complete; tests authored but not executable in this environment)

- [x] Apply atomic storage to papers, question bank and templates.
- [x] Preserve backup/recovery and surface typed errors.
- [x] Add export progress/cancellation contracts and actionable failure categories.

Acceptance: no repository path silently replaces unreadable data with an empty list.

### Phase 8 — Performance and UX optimisation

Status: COMPLETE (service code and benchmark tests authored; device profiling blocked)

- [x] Add large-paper benchmark-style tests.
- [x] Keep validation/indexing linear and avoid repeat parsing.
- [x] Document device/profile checks that remain external.

Acceptance: service operations meet documented budgets in local tests; real-device profiling remains an explicit gate.

### Phase 9 — Accessibility and localization

Status: PARTIAL (primary new flow improved; whole-app audit and device verification remain blockers)

- [x] Add semantic math labels, readable fallbacks and save/error announcements.
- [x] Audit touch size, text scale, contrast, keyboard and layout behavior in code/tests.
- [x] Move newly introduced strings into a small localization catalogue.

Acceptance: primary creation flow is operable with screen reader/external keyboard in widget tests; real device is externally verified.

### Phase 10 — Complete testing

Status: PARTIAL (78 tests authored; execution and visual goldens blocked)

- [x] Add unit tests for models, migrations, templates, validation, autosave and booklet order.
- [x] Add widget tests for editor controls and accessibility.
- [x] Add integration-test journeys where the harness permits.
- [ ] Add deterministic PDF structure/snapshot fixtures.

Acceptance: all runnable automated tests pass; unavailable toolchain checks remain blockers, never reported as passed.

### Phase 11 — Regression and release audit

Status: COMPLETE (audit performed; mandatory release gates blocked/failed)

- [ ] Format, analyze, test and build with available tools.
- [x] Scan permissions, secrets, debug code, TODO/FIXME and unsafe catches.
- [x] Generate final report with exact evidence and blockers.

Acceptance: no P0/P1 known code blocker remains and every unverified external gate is clearly listed.

## Rollback strategy

- Every phase receives a focused Git commit.
- Model additions are backward compatible and legacy enum positions are preserved.
- Atomic writers retain the prior valid `.bak` file.
- Feature UI is additive; the legacy paper loader and original PDF templates remain supported.
- If a phase regresses behavior, revert only its commit; never delete user data or reset persistence.

## Release-readiness checklist

- [ ] All phase acceptance criteria complete.
- [ ] Dart formatting passes.
- [ ] Flutter static analysis passes.
- [ ] All unit/widget/integration tests pass.
- [ ] Legacy migration fixtures pass.
- [ ] Representative PDFs visually inspected for formula/layout clipping.
- [ ] Android debug build passes.
- [ ] Android signed release build passes with authorized credentials.
- [ ] Real phone/tablet portrait and landscape flow passes.
- [ ] 500-question performance and low-storage tests pass on target hardware.
- [ ] No known P0/P1 blocker or critical data-loss risk remains.
- [ ] Store, privacy, legal and production-monitoring evidence is available where applicable.

## Phase update log

This section will be updated after every phase with files changed, architecture decisions, tests, commands, results, risks and justified deferrals.

### Phase 0 evidence

- Files changed: this plan.
- Decisions: preserve current architecture; use additive versioned models and atomic JSON rather than introduce a database dependency immediately before release.
- Commands: archive listing/extraction, documentation/source inventory, environment checks, Git initialization and imported-baseline commit.
- Results: repository content audited; Flutter/Dart/build baseline blocked by absent SDK; Git provenance absent in upload.
- Remaining risks: data-loss paths, incomplete types/templates, and all toolchain/device release gates.

### Phase 1 evidence

- Files changed: `paper_model.dart`, canonical `math_expression.dart`, question-bank model, editor clone behavior, and two model/migration test files.
- Decisions: legacy `mcq`, `descriptive`, and `fillInTheBlanks` remain indices 0, 1, and 2; new serializers write both the stable index and readable enum name; formula source and accessibility fallback are stored separately.
- Tests added: all question-type round trips, full metadata/attachments/table/parts/choices, formula round trip, unknown-enum fallback, Quill plain-text migration, and legacy paper JSON.
- Commands/results: `git diff --check` passed; source inspection found no remaining direct `QuestionType.values[index]` access. Flutter execution remains blocked by absent SDK.
- Remaining risks: UI does not yet expose all new model capabilities; repository writes are not yet atomic.

### Phase 2 evidence

- Files changed: editor state/provider, mobile question sheet, paper composer screen, autosave coordinator, and export option rendering.
- Decisions: a 650 ms debounce coalesces typing; all writes are chained serially; the title announces waiting/saving/saved/failed state; undo/redo keeps 50 in-memory paper snapshots; Save & Next preserves insert position.
- UX delivered: searchable picker for every question type, radio versus multi-answer checkbox behavior, add above/below, move between sections, duplicate section API, delete confirmation, and compact AppBar actions.
- Tests added: debounce-to-latest, single-writer serialization, save failure state, move + undo, and independent section duplication.
- Commands/results: `git diff --check` passed and exporter question-type handling was made non-exhaustive-safe through the model extension. Flutter execution remains blocked by absent SDK.
- Remaining risks: save recovery still depends on non-atomic repositories until Phase 7; real keyboard/inset behavior requires phone/tablet verification.

### Phase 3 evidence

- Files changed: versioned content-template models/repository/provider, ten offline paper blueprints, four section starters, clone/variable services, picker/management UI, question editor and paper composer.
- Decisions: template records are immutable sources; every inserted paper/section/question/option/formula/attachment receives a new ID; built-ins are code-backed and cannot be accidentally deleted; Quill variable replacement decodes and re-encodes operations so quotes cannot corrupt JSON.
- UX delivered: save a question with class/subject/chapter/topic metadata, search and filter templates, rename/duplicate/delete custom question templates, insert into a section, add a section starter, choose a complete paper blueprint, edit smart variables before creation, and confirm before replacing a populated draft.
- Tests added: ten required built-in styles, deep ID independence, Quill-safe variable replacement, unresolved-variable reporting, and full library round trip.
- Commands/results: `git diff --check` passed. Flutter execution remains blocked by absent SDK.
- Remaining risks: custom section/paper blueprint authoring uses the domain/repository API but does not yet have a dedicated designer screen; atomic template writes arrive in Phase 7.

### Phase 4 evidence

- Files changed: symbol catalogue/model, keyboard state/providers/view/key semantics, formula validator, safe renderer, visual formula editor sheet, question editor, preview and PDF/Office export fallbacks.
- Decisions: ordinary teachers build new formula blocks with `MathField` and category keys; stored blocks keep canonical LaTeX plus a mandatory readable description; existing blocks expose an advanced raw-source repair mode but malformed source is never discarded; favourites and recent symbols persist locally.
- Coverage delivered: mixed/scientific/recurring structures, piecewise and simultaneous equations, supersets/universal set, expectation/distribution notation, chemistry reactions/charges/isotopes/states, favourites, long-press actions, search, haptics, inline/display modes and accessible key labels.
- Tests added: valid/malformed/empty expression handling, fallback preservation, required catalogue structures and human-readable symbol labels.
- Commands/results: `git diff --check` passed and every `MathCategory` switch was updated for favourites and chemistry. Flutter execution and rendered formula inspection remain blocked by absent SDK.
- Remaining risks: the Dart `pdf` package cannot typeset LaTeX directly, so canonical expressions use their required readable fallback in PDF/Office export; visual PDF math fidelity is a release blocker until a verified typesetting path and rendered-page inspection are completed.

### Phase 5 evidence

- Files changed: paper/section configuration models, editor state, composer controls, template clone preservation, real-time validator and tests.
- Decisions: validation is linear, advisory during editing, and code-addressable; export may later treat error severity as a deliberate confirmation gate; expected marks can come from the explicit setting or a Maximum Marks header field.
- UX delivered: live marks/check banner with issue sheet, section duplication, page-break and keep-together preferences, answer-space line count, ruled/graph areas, expected maximum marks, cover page, repeated header/footer and page-number settings.
- Tests added: attempt-rule marks calculation, maximum mismatch, missing marks, invalid attempt count, empty sections, duplicate IDs/numbering, unresolved variables and incomplete internal choices.
- Commands/results: `git diff --check` passed; all section clone paths preserve the new composition settings. Flutter execution remains blocked by absent SDK.
- Remaining risks: page-layout preferences are modeled and editable but must be consumed and visually verified by Phase 6 export.

### Phase 6 evidence

- Files changed: typed export configuration, deterministic booklet imposition service, PDF generator/service, save/export sheet and focused unit tests.
- Decisions: output policy is explicit for all ten required modes; answer keys derive correct options without mutating questions; booklet sequencing is a pure page-order calculation with blank-page padding and optional signatures; printer duplex behavior is described as external rather than guaranteed.
- Export behavior delivered: A4/Letter override, portrait/landscape, colour/grayscale selection, cover, repeated header/footer/page count, set label, answer key, teacher explanation, answer space, compact/large-print scaling, page breaks and fold gutter.
- Tests added: configuration round trip/validation plus 4-, 5-, 8-page and fixed-signature booklet sequences.
- Commands/results: `git diff --check` passed. Flutter execution and representative rendered-page inspection remain blocked by the absent SDK; physical duplex/imposition must be verified with the target printer workflow.
- Remaining risks: this implementation supplies deterministic booklet order preview and gutter-aware logical PDF output, but the current exporter does not rewrite rendered PDF pages into printer spreads; the OS printer dialog must perform duplex booklet imposition. Formula source still uses its readable fallback rather than textbook-quality typesetting in PDFs.

### Phase 7 evidence

- Files changed: shared atomic JSON store/serialized mutation queue, all four local repositories, attachment lifecycle service, cooperative export task contract, PDF service/export UI and recovery/export tests.
- Decisions: legacy list files remain readable and migrate to a schema-versioned envelope on the next successful write; staged JSON is flushed and decoded before replacement; the previous valid generation is retained as `.bak`; corrupt primary data falls back to backup but corrupt primary plus corrupt backup raises a typed error instead of returning an empty library.
- Reliability delivered: serialized read-modify-write mutations, one-generation draft history, bounded corrupt-file preservation, nested attachment reference/orphan detection, recoverable trash movement restricted to the managed attachment root, PDF progress labels, cooperative cancellation checkpoints and actionable permission/storage/unsupported-content messages.
- Tests added: previous-generation backup, corrupt-primary recovery, corrupt-primary-and-backup failure, legacy paper migration, mutation ordering, nested attachment references, cancellation and error classification.
- Commands/results: `git diff --check` passed and repository scans found no remaining catch-and-return-empty behavior in the paper, question-bank or template data layers. Flutter execution remains blocked by the absent SDK.
- Remaining risks: PDF rendering itself is synchronous inside the third-party generator, so cancellation takes effect at cooperative boundaries rather than interrupting a page mid-render; low-storage/permission behavior must be fault-injected on Android; attachment trash cleanup is safe and available but retention scheduling is not wired into startup.

### Phase 8 evidence

- Files changed: bounded LRU formula-validation cache, safe renderer integration, paper performance profiler and 100/300/500-question benchmark-style tests.
- Decisions: cache keys contain both canonical source and readable fallback so an accessibility edit cannot reuse stale validation; the cache is capped at 200 least-recently-used entries; the profiler measures validation and UTF-8 serialization independently and reports exact processed counts/bytes.
- Tests added: cache hit/eviction behavior and service-level validation/serialization for 100, 300 and 500 formula-bearing questions across multiple sections, with a generous five-second host budget.
- Commands/results: `git diff --check` passed. The benchmark test could not execute without Flutter/Dart, so no timing result is claimed.
- Remaining risks: list scrolling, typing latency, keyboard animation, PDF time/memory, image-heavy papers, restoration after process death and low/mid-range Android behavior require Flutter DevTools and physical-device profiling; synchronous third-party PDF layout may still cause UI jank for very large papers.

### Phase 9 evidence

- Files changed: English/Hindi localization catalogue and delegate, app registration, localized save/PDF flow, focusable math key, formula semantics and accessibility/localization tests.
- Decisions: visual TeX descendants are excluded from screen-reader traversal and replaced by one readable fallback label; malformed formulas announce that attention is required without exposing raw markup; math keys provide explicit tap/long-press actions, a visible focus ring, Enter/Space activation and a minimum 48×48 target.
- Tests added: Hindi lookup/delegate loading, unsupported-locale fallback, semantic symbol label, minimum target size, keyboard activation, malformed-formula fallback and 200% text scaling.
- Commands/results: `git diff --check` passed. Widget tests and TalkBack/VoiceOver checks could not run without Flutter/device access.
- Remaining risks: the catalogue covers the newly introduced question-save/export flow, while substantial legacy screens still contain hard-coded English; a whole-app localization extraction is still required. Screen-reader focus order, switch access, hardware keyboard navigation, tablet/landscape layout, high contrast and 200% scaling require execution on supported targets. These are release blockers.

### Phase 10 evidence

- Files changed: test dependency/lock metadata, question-editor behavior widget test, expanded editor-state workflow test, save-sheet expectation and two service-level integration journeys.
- Coverage delivered: all 19 question types in a save/close/restore journey, formula persistence, option/internal-choice validation, blank-paper flow, blueprint variable resolution, independent IDs, answer-key configuration, booklet planning, type-picker radio-to-checkbox transition, insertion, duplication, reordering, update, undo and redo.
- Test inventory: 78 `test`/`testWidgets` declarations across 26 test files including two integration tests; earlier phases cover models, migrations, marks/attempt rules, numbering, templates, formula validation/cache, autosave, recovery, attachment lifecycle, export configuration/task behavior, performance and accessibility.
- Commands/results: static test inventory and `git diff --check` passed. No automated test executed because neither Flutter nor Dart is installed.
- Remaining risks: rendered formula/question-card/PDF/booklet golden baselines cannot be generated honestly without a Flutter renderer and approved baseline inspection; true UI integration for PDF preview/export needs platform plugins and target-device execution. Mandatory test pass evidence remains a release blocker.

### Phase 11 evidence

- Files changed: production Android permissions, scoped document discovery, dependency metadata, release signing configuration/example, safe visual-template/layout migration, migration test and final release documentation.
- Security/release decisions: removed broad all-files storage permissions and their unused packages; retained the system file picker for teacher-selected external documents; production declares no Android permission; release builds never reuse the debug key and are unsigned until authorized local credentials are supplied.
- Audit results: `git diff --check` passed; no app/test debug print or unfinished marker was found; common credential signature scan found no secret; remaining enum-index uses are bounds guarded. The source contains 79 test declarations in 26 files.
- Blocked commands: Flutter version, dependency resolution, analysis, test, integration test, debug build and release build all returned exit 127 because Flutter is absent; Dart format returned exit 127 because Dart is absent; Gradle tasks returned exit 127 because `android/gradlew` and its wrapper JAR are absent.
- Remaining risks: every blocker and required closure artifact is recorded in `QUESTION_CREATION_FINAL_RELEASE_REPORT.md`. No release-ready claim is made.

## Final release verdict

**The app is not ready for release. Do not release it until the documented blockers are resolved.**
