# EduSheet Question Creation — Final Pre-Release Report

Date: 2026-07-19  
Branch: `codex/question-creation-refactor`  
Imported baseline: `1614f0c`  
Implementation audit range: `9c25e33..91932ce`

## Executive verdict

The source archive has been substantially completed and hardened, but it is **not release-ready**. The implementation adds the requested question domain, editor workflow, templates, formula model/editor, composer validation, export modes, booklet planning, atomic persistence, recovery, performance instrumentation, accessibility improvements, localization scaffolding and automated tests.

Release approval is blocked because this environment has no Flutter or Dart SDK, the Android Gradle wrapper executable/JAR is absent from the uploaded project, none of the 79 authored tests could execute, no supported build could be produced, no representative PDF could be rendered and inspected, and no signed-release/device/store evidence exists. Additional product gaps remain in PDF math typography, physical booklet imposition, legacy whole-app localization and real-device accessibility/performance verification.

## Scope and provenance

- The supplied ZIP did not contain Git history. A new repository and focused branch were created without altering the uploaded archive.
- Baseline import commit: `1614f0c chore: import uploaded EduSheet baseline`.
- No new hosted runtime dependency was introduced. `integration_test` is a Flutter SDK development dependency.
- Obsolete `permission_handler` and `device_info_plus` dependencies were removed after broad storage access was eliminated.
- Persistence remains offline JSON to preserve the existing architecture; migrations are versioned, additive and tested in source rather than implemented as SQL.

## Phase results

| Phase | Result | Evidence summary |
|---|---|---|
| 0 — Audit and plan | Complete | Baseline, architecture, docs, source, toolchain and release risks inventoried; master plan created. |
| 1 — Domain and migration | Code complete, execution blocked | 19 stable question types, rich metadata, canonical formulas, nested content and legacy enum/index preservation. |
| 2 — Mobile editor | Code complete, execution blocked | Searchable type picker, option behavior, insertion, move/duplicate/delete, 50-state undo/redo and serialized debounced autosave. |
| 3 — Templates | Code complete, execution blocked | Versioned question/section/paper templates, 10 paper starters, filters, smart variables and independent-ID cloning. |
| 4 — Math editor | Code complete, visual verification blocked | Expanded symbol catalogue, visual formula blocks, validation, safe fallbacks, favorites/recent state and accessible labels. |
| 5 — Composer | Code complete, execution blocked | Marks/attempt validation, section layout settings, answer areas, cover, branding, header/footer and page numbers. |
| 6 — PDF/booklet | Code complete with documented limitations | 10 output policies, page/orientation/colour options, answers/solutions, answer space, cover/footer and deterministic booklet sequence. |
| 7 — Reliability | Code complete, execution blocked | Atomic staged writes, retained backup, corrupt-primary recovery, typed errors, serialized mutations, attachment lifecycle and export cancellation checkpoints. |
| 8 — Performance | Instrumented, profiling blocked | Bounded LRU formula cache and 100/300/500-question validation/serialization profiles authored. |
| 9 — Accessibility/localization | Partial | New flow localized in English/Hindi; math keyboard focus/touch/semantics improved. Legacy strings and device checks remain. |
| 10 — Testing | Partial | 79 tests across 26 files authored, including two integration journeys. No test could execute and visual goldens were not generated. |
| 11 — Release audit | Audit complete; gates failed/blocked | Permissions, signing, unsafe enum migration, secrets/debug/TODO patterns and available source checks reviewed. Builds and platform verification blocked. |

## Implemented deliverables

### Question creation and editing

- Preserved legacy enum positions for MCQ, descriptive and fill-in-the-blank data while extending the model to 19 types.
- Added correct-answer policy, multiple-select behavior, marks/negative marks, difficulty, cognitive level, grade/subject/chapter/topic, tags, source, explanation, language, timing, status and version.
- Added images/diagrams/files with accessibility text, tables, subquestions, internal choices and arbitrary metadata.
- Added insertion above/below, move between sections, section/question duplication, reordering, editing, deletion confirmation, undo and redo.
- Added 650 ms debounced autosave with one serialized writer and visible waiting/saving/saved/failed state.

### Templates

- Added versioned question, section and full-paper template models and offline repository.
- Added 10 required paper starters and four section starters.
- Added filtering, save, insert, duplicate, rename and delete flows for custom question templates.
- Added safe smart-variable replacement, including Quill Delta operations containing quotes.
- Every inserted mutable record receives a new ID.

### Mathematics

- Added canonical formula source plus mandatory readable fallback.
- Added visual formula creation/editing, inline/block display, raw-source repair, malformed-input safeguards and fallback export.
- Added categories and symbols for school algebra, calculus, sets/logic, statistics, physics and chemistry, plus search, favorites, recent symbols, long-press actions and haptics.
- Added a 200-entry LRU validation cache to avoid parsing unchanged formulas repeatedly.

### Composer and export

- Added real-time, code-addressable paper validation for empty sections/questions, marks, attempt rules, duplicate records/numbering, unresolved variables and internal choices.
- Added page breaks, keep-together preference, answer line count, ruled/graph areas, cover, expected marks, branding, repeated header/footer and page-number settings.
- Added typed configuration for standard, answer-space, question-answer booklet, answer key, teacher solution, student, multiple set, worksheet, compact and large-print modes.
- Added A4/Letter override, portrait/landscape, colour/grayscale selection, spacing/font scaling and set labels.
- Added deterministic booklet padding, signature grouping and print-order preview.

### Persistence and protection

- Legacy list files remain readable and migrate to a schema-versioned envelope on the next successful write.
- Writes use flushed temporary JSON, decode verification, atomic replacement and a retained prior valid `.bak` generation.
- Corrupt primary data recovers from the backup; corrupt primary plus corrupt backup raises a typed error and never silently becomes an empty library.
- Paper, question-bank, visual-template and content-template mutations are serialized.
- Attachment reference/orphan detection includes nested questions and can move only confirmed managed orphans to a recoverable trash directory.
- PDF export exposes progress, classifies permission/space/content failures and supports cooperative cancellation checkpoints without discarding the saved paper.

### Security and platform configuration

- Removed Android `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` and `MANAGE_EXTERNAL_STORAGE` from the production manifest.
- Document discovery now scans app/scoped directories; the existing system file picker remains the path for user-selected external files.
- Removed now-unused storage-permission/device-info packages.
- Removed debug-key signing from the release build. A local ignored `key.properties` may configure the private release key; without it the output is unsigned.
- Added safe fallbacks for future/corrupt template and custom-layout enum indexes.
- Production Android manifest declares no permission. Debug/profile manifests declare `INTERNET` only for Flutter tooling.

## Migration and compatibility evidence

- Legacy question type indices 0, 1 and 2 are unchanged.
- Existing paper JSON without new properties receives backward-compatible defaults.
- Existing question-bank JSON retains its flattened record shape on import/export.
- Papers, question banks and custom visual templates accept both a legacy root list and the new schema envelope.
- Content-template data already uses an object schema and is now written atomically.
- Unknown question, difficulty, numbering, template, layout and element values use explicit safe fallbacks rather than unchecked list indexes.
- Tests cover legacy paper JSON, Quill-derived plain text, template enum corruption, repository migration and backup recovery.

## Automated test inventory

Static inventory found 79 `test`/`testWidgets` declarations in 26 files. Coverage includes:

- question/model round trips and unknown-value migration;
- marks, attempt rules, numbering and paper validation;
- templates, variable resolution and independent IDs;
- formula validation, fallback, catalogue and LRU cache;
- autosave debounce, serialization and failure state;
- editor insertion, move, duplicate, reorder, update, undo and redo;
- type-picker radio-to-checkbox behavior;
- booklet ordering and export configuration;
- atomic persistence, backup recovery and legacy migration;
- attachment lifecycle and export cancellation/error classification;
- 100/300/500-question service profiles;
- semantics, keyboard activation, target size, 200% scaling and localization;
- blank-paper and template-based integration journeys.

No test result is marked passed because the test runner was unavailable.

## Commands and results

| Command | Result |
|---|---|
| `git diff --check` | Passed repeatedly, including the final clean-tree audit. |
| `rg` scans for TODO/FIXME/HACK/XXX in app/test/Android app code | No unfinished marker found. |
| `rg` scans for `print`/`debugPrint` | No debug print found. |
| Secret signature scan for common Google/AWS/GitHub/OpenAI/private-key patterns | No credential value found. Property names and an empty example file are not credentials. |
| Android manifest permission scan | Production: none. Debug/profile: development `INTERNET` only. |
| Unchecked enum-index scan | Remaining matches are guarded by bounds checks. |
| `flutter --version` | Blocked, exit 127: `flutter: command not found`. |
| `dart --version` | Blocked, exit 127: `dart: command not found`. |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Blocked, exit 127: `dart: command not found`. |
| `flutter pub get` | Blocked, exit 127: `flutter: command not found`. |
| `flutter analyze` | Blocked, exit 127: `flutter: command not found`. |
| `flutter test` | Blocked, exit 127: `flutter: command not found`. |
| `flutter test integration_test` | Blocked, exit 127: `flutter: command not found`. |
| `flutter build apk --debug` | Blocked, exit 127: `flutter: command not found`. |
| `flutter build apk --release` | Blocked, exit 127: `flutter: command not found`. |
| `./gradlew tasks` | Blocked, exit 127: `android/gradlew` is absent. |

Available Java runtime: OpenJDK 17.0.19. `javac`, standalone Gradle, Flutter and Dart are absent.

## Release blockers

| ID | Severity | Blocker | Required closure evidence |
|---|---|---|---|
| BLK-001 | P0 | Flutter/Dart toolchain is absent; source was not formatted, resolved, analyzed or compiled. | Run the pinned supported Flutter SDK; attach clean format, dependency resolution and analyzer output. |
| BLK-002 | P0 | Android wrapper JAR and scripts are absent from the uploaded repository and standalone Gradle is unavailable. | Restore the correct wrapper, verify its checksum, and run Gradle/Flutter builds in CI. |
| BLK-003 | P0 | All 79 authored automated tests are unexecuted. | Pass unit, widget and integration suites on a clean checkout; triage every failure without weakening assertions. |
| BLK-004 | P0 | No Android debug or release artifact exists; release signing credentials/evidence were not available. | Build debug and signed release artifacts with authorized private credentials; verify signing and install/launch. |
| BLK-005 | P1 | Canonical LaTeX uses readable text fallback in PDF/Office output rather than textbook-quality equation typesetting. | Implement/verify a licensed maintained typesetting path and inspect representative formula pages. |
| BLK-006 | P1 | Booklet service computes correct logical order, but the exporter does not rewrite rendered PDF pages into physical printer spreads. Duplex behavior is delegated to the printer dialog. | Add or verify actual page imposition where supported; test blank pages, covers, gutter, flip edge and multiple signatures on target printers. |
| BLK-007 | P1 | No representative PDF, answer key, large-print paper or booklet was rendered and visually inspected. | Generate fixtures and inspect every page for clipping, fonts, Unicode, orphan headings, page count, images, math and accidental blanks. |
| BLK-008 | P1 | Whole-app localization is incomplete. Static scan still finds hundreds of legacy user-facing string sites outside the new export catalogue. | Extract all user-facing strings, complete translations/fallback policy, and pass locale/layout tests. |
| BLK-009 | P1 | Real-device accessibility, keyboard, phone/tablet, portrait/landscape and high-contrast verification is absent. | Run documented TalkBack/VoiceOver, switch/external-keyboard, 200% text and layout matrices on supported devices. |
| BLK-010 | P1 | Real-device performance, memory, image-heavy PDF, low-storage, permission failure and process-restoration profiles are absent. | Capture Flutter DevTools and fault-injection evidence on low/mid-range Android targets for 100/300/500-question scenarios. |
| BLK-011 | P1 | Visual golden/snapshot baselines were not generated because no renderer was available. | Approve and check in deterministic formula, question-card, preview, PDF and booklet baselines. |
| BLK-012 | P1 | Store-console, privacy manifest/declaration, dependency-license, legal, production crash/monitoring and data-retention evidence was not supplied. | Complete organizational release review and retain dated approvals/artifacts. |

## Known non-blocking limitations and follow-up

- Custom section and paper-blueprint authoring exists through the domain/repository API, but only question-template management has the complete dedicated UI.
- Export cancellation is cooperative between major stages; the third-party PDF renderer cannot stop midway through a page.
- Attachment cleanup can safely identify and trash orphans, but automatic retention/purge scheduling is not connected to app startup.
- Document reader automatic discovery is intentionally limited to scoped/app-accessible locations. Teachers use the system file picker for arbitrary external documents.
- The original archive contained no Git provenance, so upstream history and prior release tags cannot be verified.

## Commits created

1. `9c25e33` — phase 0: audit question creation baseline and safety risks
2. `82e6478` — phase 1: extend versioned question domain model
3. `0cbee33` — phase 2: make question editing mobile first and autosave safe
4. `a659a3e` — phase 3: add reusable question section and paper templates
5. `db626e0` — phase 4: integrate canonical mobile formula editing
6. `38721dd` — phase 5: add paper composition rules and live validation
7. `b005fc7` — Phase 6: add professional PDF modes and booklet planning
8. `fda3aad` — Phase 7: make offline storage atomic and recoverable
9. `77bee56` — Phase 8: bound formula caches and profile large papers
10. `17f8096` — Phase 9: improve accessible math and localize export flow
11. `3babee9` — Phase 10: expand behavioral and journey test coverage
12. `91932ce` — Phase 11: harden release permissions and legacy templates
13. Final documentation/package commit — contains this report and the final plan status.

## Files changed

The implementation before this final report changed 66 files with 7,368 insertions and 446 deletions. This report is the 67th changed file.

```text
M android/app/build.gradle.kts
M android/app/src/main/AndroidManifest.xml
A android/key.properties.example
A docs/pre_release/QUESTION_CREATION_REFACTOR_AND_RELEASE_PLAN.md
A docs/pre_release/QUESTION_CREATION_FINAL_RELEASE_REPORT.md
A integration_test/question_creation_journey_test.dart
M lib/features/document_reader/data/repositories/document_repository.dart
M lib/features/editor/data/repositories/local_paper_repository.dart
A lib/features/editor/domain/models/math_expression.dart
M lib/features/editor/domain/models/paper_model.dart
M lib/features/editor/presentation/providers/editor_provider.dart
M lib/features/editor/presentation/screens/create_paper_screen.dart
M lib/features/editor/presentation/widgets/question_editor_sheet.dart
A lib/features/editor/services/attachment_lifecycle_service.dart
A lib/features/editor/services/autosave_coordinator.dart
A lib/features/editor/services/paper_performance_profiler.dart
A lib/features/editor/services/paper_validator.dart
M lib/features/math_keyboard/domain/models/math_symbol.dart
A lib/features/math_keyboard/domain/services/math_expression_validator.dart
M lib/features/math_keyboard/presentation/providers/math_keyboard_controller.dart
M lib/features/math_keyboard/presentation/providers/math_keyboard_provider.dart
A lib/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart
M lib/features/math_keyboard/presentation/widgets/math_key.dart
M lib/features/math_keyboard/presentation/widgets/math_keyboard_view.dart
A lib/features/math_keyboard/presentation/widgets/safe_math_expression.dart
M lib/features/pdf/data/repositories/template_repository.dart
M lib/features/pdf/domain/models/custom_layout.dart
A lib/features/pdf/domain/models/paper_export_config.dart
A lib/features/pdf/services/booklet_imposition_service.dart
A lib/features/pdf/services/export_task.dart
M lib/features/pdf/services/pdf_service.dart
M lib/features/pdf/services/presentation_export_service.dart
M lib/features/pdf/services/question_paper_service.dart
M lib/features/pdf/services/spreadsheet_export_service.dart
M lib/features/pdf/services/word_export_service.dart
M lib/features/question_bank/data/repositories/local_question_bank_repository.dart
M lib/features/question_bank/domain/models/question_bank_model.dart
A lib/features/templates/data/built_in_content_templates.dart
A lib/features/templates/data/content_template_repository.dart
A lib/features/templates/domain/models/content_template.dart
A lib/features/templates/presentation/providers/content_template_provider.dart
A lib/features/templates/presentation/widgets/content_template_picker_sheet.dart
A lib/features/templates/services/template_clone_service.dart
M lib/main.dart
A lib/shared/localization/edusheet_localizations.dart
A lib/shared/persistence/atomic_json_file_store.dart
M pubspec.lock
M pubspec.yaml
A test/features/editor/attachment_lifecycle_service_test.dart
A test/features/editor/autosave_coordinator_test.dart
M test/features/editor/create_paper_save_sheet_test.dart
A test/features/editor/editor_state_workflow_test.dart
A test/features/editor/large_paper_performance_test.dart
A test/features/editor/paper_model_legacy_migration_test.dart
A test/features/editor/paper_validator_test.dart
A test/features/editor/question_domain_model_test.dart
A test/features/editor/question_editor_type_picker_test.dart
A test/features/math_keyboard/math_accessibility_test.dart
A test/features/math_keyboard/math_expression_validation_cache_test.dart
A test/features/math_keyboard/math_expression_validator_test.dart
A test/features/pdf/booklet_imposition_service_test.dart
A test/features/pdf/export_task_test.dart
A test/features/pdf/paper_export_config_test.dart
A test/features/pdf/template_migration_test.dart
A test/features/templates/content_template_test.dart
A test/shared/localization/edusheet_localizations_test.dart
A test/shared/persistence/atomic_json_file_store_test.dart
```

## Required next verification sequence

1. Restore the project’s intended Flutter version and Android Gradle wrapper from a trusted source.
2. Run dependency resolution and commit only the tool-generated lock/wrapper changes after review.
3. Run Dart formatting, Flutter analysis, all tests and the integration suite.
4. Fix every compiler/analyzer/test failure and repeat on a clean checkout.
5. Generate representative PDFs for every output policy and approve visual/golden evidence.
6. Run debug and authorized signed-release builds, then verify install/launch/migration on existing user data.
7. Complete the physical-device accessibility/performance/fault-injection matrix.
8. Close localization, privacy, legal, license, store and monitoring gates.

## Final release verdict

**The app is not ready for release. Do not release it until the documented blockers are resolved.**
