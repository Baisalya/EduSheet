# EduSheet Formula Keyboard Session Fix 4

This patch addresses the remaining widget-test/runtime race where the formula math keyboard could close immediately after being auto-opened.

Root cause: the custom math-keyboard session was still being released on any formula-field focus loss. On Windows and in widget tests, MathField/overlay route transitions can briefly move or clear focus even though the user has not moved to another editor.

Fix:
- math-keyboard ownership now survives transient/null focus and focus moves to non-editable controls;
- ownership is released when focus actually enters another editable control outside the math keyboard;
- the keyboard's nested Navigator has `requestFocus: false`, so revealing it does not steal focus from the formula field;
- existing keyboard-local modal panels already use `requestFocus: false` and remain on the nested Navigator.

Expected regression result:
`formula math keyboard stays active through its local category panel` should no longer fail at the initial `Math keyboard open` assertion.
