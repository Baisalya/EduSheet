# EduSheet Teaching Planner Portable File (`.eds`)

Teaching Planner exports use the `.eds` extension so a teacher can move the complete local planner workspace between EduSheet installations on Android and Windows.

## Container

A new file starts with this UTF-8 header:

`EDUSHEET-PLANNER/1`

The remaining content is the existing versioned Teaching Planner backup JSON payload. The payload keeps the canonical planner document and its `schemaVersion`, so normal migrations and integrity validation still apply during import.

Portable backup version 2 also embeds the bytes for every Teaching Planner file resource by stable resource id. That includes files owned by lesson plans and by syllabus Classes, Subjects, Units, Chapters, and Topics.

## Attachment portability guarantee

- Image, PDF, document, spreadsheet, presentation, audio, video, text, and other file resources use the same private Teaching Planner resource store.
- The original external Downloads/Desktop/provider path is not retained as the source of truth. EduSheet stores its own private copy.
- `.eds` export must contain bytes for every file resource present in the workspace. The codec refuses to create an incomplete portable file.
- `.eds` version 2 import also rejects a payload when a planner file resource has no matching embedded bytes or when unexplained attachment bytes are present.
- Resource owner metadata is part of the planner document, so restored files return to the same Class, Subject, Unit, Chapter, Topic, or Lesson Plan.

## Safety and compatibility

- New exports use `.eds`.
- Import accepts `.eds` and legacy Phase 18 `.json` backups.
- Restore is rejected unless the EduSheet backup format/version and planner document are valid.
- The current workspace is not overwritten until validation succeeds and the teacher confirms restore.
- The format is local and portable; it does not require a Baisalya/EduSheet server.
