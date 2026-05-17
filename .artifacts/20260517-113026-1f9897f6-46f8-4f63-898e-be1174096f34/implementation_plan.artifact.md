# Implementation Plan - Custom Template Enhancements

This plan outlines the changes to improve custom template persistence, naming, and rendering accuracy.

## User Review Required

- **Naming Dialog**: A dialog will appear when clicking 'Save' in the Template Designer if it's a new template or to allow renaming.
- **Header Fields**: Custom "Fields Block" in the designer will now dynamically pull data from the actual paper being edited.

## Proposed Changes

### Domain & Data Layer

#### [paper_template.dart](file:///C:/Users/baish/StudioProjects/EduSheet/lib/features/pdf/domain/models/paper_template.dart)
- Ensure `PaperSize` is fully integrated and used in `copyWith`.

#### [template_repository.dart](file:///C:/Users/baish/StudioProjects/EduSheet/lib/features/pdf/data/repositories/template_repository.dart)
- Update `_toJson` and `_fromJson` to persist `paperSize`.

---

### Presentation Layer

#### [template_designer_screen.dart](file:///C:/Users/baish/StudioProjects/EduSheet/lib/features/pdf/presentation/screens/template_designer_screen.dart)
- Implement `_showSaveDialog` to ask for a template name.
- Update the save button logic to use this dialog.

#### [template_selector.dart](file:///C:/Users/baish/StudioProjects/EduSheet/lib/features/pdf/presentation/widgets/template_selector.dart)
- (Optional) Improve the preview icon/thumbnail if needed, although standard icons are usually fine for mobile lists.

---

### Services Layer

#### [pdf_service.dart](file:///C:/Users/baish/StudioProjects/EduSheet/lib/features/pdf/services/pdf_service.dart)
- Update `generateAndPreview` to fetch the template from the `templateProvider` (all templates) instead of just `predefinedTemplates`.

#### [header_builders.dart](file:///C:/Users/baish/StudioProjects/EduSheet/lib/features/pdf/services/builders/header_builders.dart)
- Update `CustomHeaderBuilder` to use `paper.headerFields` when rendering `ElementType.headerFieldsBlock`.
- Ensure `paper.schoolName` and `paper.schoolLogo` are used correctly in custom elements.

---

## Verification Plan

### Manual Verification
1.  **Saving with Name**: Open Designer -> Design -> Click Save -> Dialog appears -> Enter Name -> Save. Check if it appears in the selector with that name.
2.  **Field Syncing**: Create a paper -> Add a custom header field "Subject: Physics" -> Choose a custom template with a Fields Block. Preview PDF. Check if "Physics" shows up.
3.  **Logo Syncing**: Add a logo in the Branding section of the Paper Editor. Preview PDF with a custom template that has a logo element. Check if the logo is present.
4.  **Paper Size**: Design an A3 template. Generate PDF. Verify the PDF size is A3.
