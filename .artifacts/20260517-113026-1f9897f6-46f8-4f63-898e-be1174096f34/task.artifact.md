# Task Management

- [ ] Update Domain Models
    - [x] Research existing models
    - [ ] Add `PaperSize` support to `PaperTemplate`
- [ ] Improve Template Persistence
    - [ ] Update `TemplateRepository` to handle `PaperSize`
    - [ ] Implement naming dialog in `TemplateDesignerScreen`
- [ ] Fix Rendering and Preview
    - [ ] Ensure `TemplateSelector` reflects custom designs accurately
    - [ ] Update `PdfService` to use custom templates during generation
- [ ] Dynamic Header Fields Handling
    - [ ] Update `HeaderBuilder` to use paper's actual header fields in custom blocks
    - [ ] Ensure branding (logo, school name) syncs correctly
- [ ] Verification
    - [ ] Verify template saving with name
    - [ ] Verify preview matches design
    - [ ] Verify PDF generation with custom templates
