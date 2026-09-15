# Teaching Planner Phase 5 + 6 — Syllabus Attachments and Portable `.eds`

## Scope

Phase 5 exposes file attachments directly inside the adaptive Syllabus Manager for Class, Subject, Unit, Chapter, and Topic nodes. Phase 6 hardens `.eds` portability so those files cannot be silently omitted from a portable planner backup.

## Architecture

The feature reuses the Phase 1/2 generic `TeachingResourceOwner`, `TeachingResourceAttachmentService`, and `TeachingResourceFileStore`. No parallel syllabus file database was introduced.

`SyllabusAttachmentSection` is a presentation-only component. The Syllabus Manager coordinates file picking, private-copy persistence, opening, and safe archive/remove actions through existing Teaching Planner providers.

## UX

Each selected syllabus entity has one consistent Attachments section:

- Add one or multiple files.
- Show filename, file family, and size.
- Open using the platform file handler.
- Remove from the active syllabus without deleting recovery data.
- Single-column cards on compact/free-form screens and multi-column cards on wider Windows layouts.

## `.eds` guarantee

`TeachingPlannerBackupCodec` version 2 now validates a one-to-one set between planner file resources and embedded `resourceFiles` payloads. A missing file payload or an unknown payload causes a `FormatException` instead of producing/accepting an incomplete portable backup.

The existing backup screen already iterates all `workspace.resources`, so no Insights UI or behavior changes were needed.

## Protected areas

Planner Insights calculations/UI, Track Progress, and Premium/Subscription entitlement behavior are not modified by this phase.
