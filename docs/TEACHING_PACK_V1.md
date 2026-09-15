# EduSheet Teaching Pack v1

Extension: `.edtp`

Magic header: `EDUSHEET-TEACHING-PACK/1`

Purpose: move lesson-specific teaching resources between teachers/devices without replacing the receiving teacher's planner.

A Teaching Pack contains source labels (class, subject, chapter, lesson), resource metadata, and embedded bytes for file resources. On import, EduSheet creates fresh stable resource IDs and copies the resources into a lesson selected by the receiving teacher. Existing resources remain unchanged.

Supported resource kinds: note, file/media (including PDF, image and video), web link, and EduSheet geometry diagram. Math notes use the existing EduSheet Math Keyboard and are stored as note content.

Safety rules:
- `.edtp` import never replaces the whole Teaching Planner workspace.
- The receiving teacher explicitly chooses/accepts the target lesson.
- URLs must use `http` or `https`.
- File payloads are copied into EduSheet's private Teaching Planner resource storage.
- Geometry data is kept as editable EduSheet geometry JSON.
- `.eds` remains the full-workspace backup format; from Teaching Planner schema v6 onward its portable backup container can embed lesson attachment bytes too.
