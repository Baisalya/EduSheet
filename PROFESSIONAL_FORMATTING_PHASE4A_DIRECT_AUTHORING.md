# Professional Formatting Phase 4A — Direct WYSIWYG Authoring

Status: IMPLEMENTATION COMPLETE — awaiting Windows QA / manual smoke before lock
Baseline: RC Candidate 2 automated-green tree / Professional Formatting Phase 3 QA Fix 1

## Scope

Phase 4A is intentionally limited to three teacher-facing upgrades:

1. Direct Word Mode question creation/editing on the paper page.
2. Direct header logo choose/replace/remove with the actual logo rendered in Word Mode and Preview.
3. Picture insertion into the active assessment question, with replace/remove controls.

Shapes, wrapping/floating placement and free-form geometry belong to Phase 4B/4C and are not introduced here.

## Canonical architecture

`Paper` and `Question` remain the only persisted source of truth. Word Mode does not create a parallel document model.

- New inline questions are normal assessment `Question` objects.
- Pictures are normal image `QuestionAttachment` objects on the active assessment question.
- A free Word paragraph/table is not silently converted into an assessment question when Picture is used; the existing free-image-block path remains available there.
- Header logo paths continue to use `Paper.logos`; header layout geometry remains in `PaperTemplate` / `CustomLayout`.
- Replacing a picture preserves the attachment id so selection/export references remain stable.

## Completed implementation

- Added `WordDirectAuthoringService` for blank canonical assessment questions and image append/replace/remove mutations.
- Word Mode `Question` buttons insert a blank assessment question inline and autofocus it instead of navigating to `QuestionComposerPage`.
- Full question composer remains reachable through the existing advanced/settings action.
- Existing inline Math and Geometry commands continue to operate through the active Word rich-text session/caret.
- Word Mode Picture targets the active assessment question. When no assessment question owns the current editing target, existing standalone free-image behavior is preserved.
- Question pictures expose Replace and Remove actions directly in Word Mode. Non-picture attachment kinds are not accidentally routed through the picture replacement flow.
- Shared header canvas maps logo slots by canonical template order, renders the real selected file, and exposes direct editable logo targets.
- Word Mode logo target opens Choose / Replace / Remove and writes through `EditorState.updateBranding`.
- Paper Setup logo control previews the selected image and uses Choose / Replace terminology.
- Word rich-text session restores focus after picture selection/replacement so Math/Geometry/caret authoring can continue naturally.
- DOCX export now preserves sparse logo-slot indexes (for example, slot 0 empty and slot 1 populated) instead of shifting later logos into earlier slots.
- Existing Preview/PDF question-image and logo rendering remain the export/render path; no duplicate Phase-4A renderer was introduced.
- Added focused Phase 4A tests, Office export regression coverage, and a release-gate test for canonical question/image/logo persistence.

## Scope safety

- No database/schema migration.
- No dependency upgrade.
- No Smart/Word canonical paper split.
- No question numbering/marks-calculation rewrite.
- No floating image/wrap/shape model introduced early.
- RC Candidate 2 remains the automated-green baseline, but Phase 4A requires a fresh analyzer/test/build/manual pass before release lock.

## Required completion QA

```powershell
dart format .
flutter analyze

flutter test test/features/paper_composer/word_direct_authoring_phase4a_test.dart
flutter test test/features/paper_composer/dual_editor_mode_test.dart
flutter test test/features/paper_composer/wysiwyg_header_phase3_test.dart
flutter test test/release/professional_formatting_phase4a_gate_test.dart
flutter test test/features/pdf/office_export_services_test.dart
flutter test test/release
flutter test
```

## Manual Windows + Android smoke

1. Word Mode → add section → `Question`; confirm no full-screen New Question page opens and the inline question receives focus.
2. Type text, insert Math and Geometry, continue typing, and verify caret/focus does not jump to the end unexpectedly.
3. With that assessment question active, choose `Picture`; verify it appears under the same question, then Replace and Remove it.
4. Focus a free paragraph and use Picture; verify it stays free document content rather than turning the paragraph into an assessment question.
5. Tap an empty header logo slot → Choose logo; verify the actual image appears in Word Mode and Preview.
6. Tap the populated slot → Replace, then Remove; verify Preview/PDF/DOCX follow the canonical logo state.
7. Export PDF/DOCX with a question picture and verify the image/caption survive.
8. Smart → Word → Smart round-trip and autosave/reopen; verify direct question text, picture attachments and logo paths remain intact.
