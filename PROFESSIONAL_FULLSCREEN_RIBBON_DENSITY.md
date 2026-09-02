# EduSheet Professional Full-Screen Ribbon Density Polish

Baseline: Professional Adaptive Ribbon Polish.

## What changed
- Desktop Word-mode Home group no longer consumes a fixed 4/11 share of the ribbon.
- Idle Home is capped at 190 px and uses the concise hint `Select content to format`.
- When contextual Home formatting is active, Home expands responsively up to 500 px.
- Structure / Insert / Layout receive the reclaimed width.
- Desktop ribbon buttons use a denser desktop-only button treatment; Android touch targets keep the existing mobile treatment.
- Desktop group separators/spacings are tightened without changing actions or behavior.
- Existing horizontal scrolling remains as the safety fallback for Windows free-form/narrow widths.

## Regression coverage
- Full-screen desktop case now starts at 1920x840 and asserts the Home group stays <= 200 px.
- The same test asserts the right-most Layout action is inside the 1920 px viewport, then rechecks 1392x840 and 820x620 resize safety.

## Scope
No paper model, autosave, database, geometry, PDF/DOCX, or Android behavior changes.
