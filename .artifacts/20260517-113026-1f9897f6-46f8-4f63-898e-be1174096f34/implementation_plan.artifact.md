# Implementation Plan - Professional Header Syncing & Filtering

This plan outlines the changes to ensure only template-required fields are shown in the paper editor and support multiple logos.

## User Review Required

- **Automatic UI Filtering**: The "Setup" screen in the paper editor will now dynamically hide branding or header fields if they aren't part of the selected template.
- **Multiple Logos**: If you add 3 logo boxes in the designer, you will see 3 logo pickers in the paper editor.

## Proposed Changes

### Domain Layer

#### [paper_model.dart](file:///C:/Users/baish/StudioProjects/EduSheet/lib/features/editor/domain/models/paper_model.dart)
- Replace `schoolLogo` with `List<String> logos`.
- Add a helper to get logo at index or null.

---

### Presentation Layer

#### [create_paper_screen.dart](file:///C:/Users/baish/StudioProjects/EduSheet/lib/features/editor/presentation/screens/create_paper_screen.dart)
- Update `_buildBrandingEditor` to show multiple logo pickers based on the template.
- Dynamically hide the "School Name" card if not in template.
- Filter the `ReorderableListView` in `_buildHeaderFieldsEditor` to only show fields present in the template.

#### [template_selector.dart](file:///C:/Users/baish/StudioProjects/EduSheet/lib/features/pdf/presentation/widgets/template_selector.dart)
- (Already implemented visual previews, no changes needed).

---

### Services Layer

#### [header_builders.dart](file:///C:/Users/baish/StudioProjects/EduSheet/lib/features/pdf/services/builders/header_builders.dart)
- Update `CustomHeaderBuilder` to map logo elements to the new `paper.logos` list by index.

#### [editor_provider.dart](file:///C:/Users/baish/StudioProjects/EduSheet/lib/features/editor/presentation/providers/editor_provider.dart)
- Update `updateTemplate` to ensure `state.logos` has enough slots for the selected template.
- Update `updateBranding` to handle multiple logos.

---

## Verification Plan

### Manual Verification
1.  **Empty Template**: Choose a template with NO school name and NO logos. Verify the "Branding" card in the editor becomes minimal or disappears.
2.  **Multi-Logo Sync**: Design a template with 2 logos. Verify the editor shows "Logo 1" and "Logo 2" pickers.
3.  **Field Pruning**: Design a template with only "Subject". Verify that in the editor's General Info, only "Subject" is editable/visible (or others are moved to an "Unused" section).
