Create Paper structured-math integration fix

Problem:
The Create Paper Quill question body was registered directly with the math keyboard.
QuillMathEditorAdapter intentionally serializes TeX structures to plain-text/Unicode
approximations, so fractions/roots/functions appeared as normal symbols/text.

Fix:
- The normal Quill question field is no longer a direct MathKeyboardField target.
- Tapping "Math keyboard" opens FormulaEditorSheet in structured visual mode.
- FormulaEditorSheet automatically focuses MathFieldEditingController and opens the
  math keyboard when launched from Create Paper.
- The math keyboard therefore sends fraction/root/power/integral/function commands
  to MathFieldEditorAdapter, which builds structured textbook-style formulas.
- The formula editor moves its Insert Formula action above the global math-keyboard
  overlay on mobile.
- Added widget regression coverage for entering the structured MathField flow.

No dependency, database, persisted Paper/Question schema, or geometry change.
