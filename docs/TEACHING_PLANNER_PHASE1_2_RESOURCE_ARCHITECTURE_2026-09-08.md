# Teaching Planner Phase 1 + Phase 2 — Resource Ownership & Attachment Architecture

Date: 2026-09-08

## Scope completed

- Promoted Teaching Workspace resources from lesson-only ownership to a generic owner model.
- Supported resource ownership by Class, Subject, Unit, Chapter, Topic, and Lesson Plan.
- Preserved legacy `lessonPlanId` construction/access for existing lesson workspace and Teaching Pack code.
- Advanced the Teaching Planner document schema from v6 to v7.
- Added v6 → v7 migration that maps old `lessonPlanId` resources to `owner: {type: lessonPlan, id: ...}`.
- Kept older schema migration chains intact.
- Added generic workspace resource queries for every syllabus level.
- Added owner-aware integrity validation and active-owner validation for new writes.
- Added a reusable attachment application service.
- Added multi-file attachment with one planner metadata transaction.
- Added best-effort file rollback when storage or planner persistence fails.
- Centralized file MIME/category recognition for images, PDF, video, audio, text, Office/OpenDocument files.
- Moved file picking/byte loading out of `teaching_workspace_screen.dart` into a reusable picker service.
- Existing lesson Teaching Workspace now uses the same reusable multi-file attachment pipeline that future syllabus UI can call.

## Backward compatibility

- Existing `TeachingResource(lessonPlanId: ...)` callers remain supported.
- Existing `.edtp` Teaching Pack v1 decode remains supported because legacy `lessonPlanId` JSON is still accepted.
- New lesson resources serialize both generic owner metadata and legacy `lessonPlanId` compatibility metadata.
- Existing `.eds` backups whose planner document uses schema v6 migrate to v7 automatically.
- `.eds` backup code already iterates all `workspace.resources`, so generic syllabus-owned file resources can use the same portable attachment-byte mechanism without a parallel storage system.

## Protected areas

No feature logic was changed in:

- Planner Insights service/screen behavior.
- Track Progress service/screen behavior.
- Premium/subscription/entitlement model.

Schema-version assertions in existing tests were updated from 6 to 7 because the shared Teaching Planner document schema changed globally.

## New files

- `domain/models/teaching_resource_owner.dart`
- `application/teaching_resource_attachment_service.dart`
- `application/teaching_resource_file_metadata.dart`
- `presentation/services/teaching_resource_file_picker.dart`
- `test/features/teaching_planner/teaching_resource_ownership_phase1_test.dart`
- `test/features/teaching_planner/teaching_resource_attachment_phase2_test.dart`

## Validation note

This execution environment does not contain the Flutter/Dart SDK, so `flutter analyze` and `flutter test` cannot be executed here. Structural delimiter checks and local-import resolution checks were run over all modified Dart files. Run the normal project gates on a Flutter SDK machine before release.
