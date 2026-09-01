# EduSheet Step 6 QA Fix 2

## Trigger
`flutter analyze` is clean, but `flutter test test/release` still had one release-gate failure in the preview semantic parity test.

The failing marker was the main question text `Study the evidence and answer the following.`. The preview visibly renders question bodies through Flutter Quill (`RenderEditable`), so those bodies are not ordinary `Text` widgets. The previous gate only concatenated descendant `Text` widgets and therefore reported valid Quill-rendered question text as missing.

## Production fix
`QuestionRichTextPreview` now exposes one stable accessibility `Semantics` label derived from `QuestionRichTextCodec.accessibleText(...)`. Nested Quill semantics are excluded to avoid duplicate screen-reader output. This also preserves readable math-embed fallbacks in the semantic label.

## Release-gate fix
The preview parity gate still checks ordinary paper text first. For markers rendered by Quill it now requires a descendant semantic label inside `paper-preview-document`. It does not read the model directly and does not bypass the preview: the content must actually be exposed by the rendered preview accessibility surface.

## Scope
- 1 production file changed
- 1 release test changed
- no DB/schema changes
- no package/dependency changes
- PDF/Word parity checks remain unchanged

## Validation to run
```powershell
dart format .
flutter analyze
flutter test test/release
flutter test
```
