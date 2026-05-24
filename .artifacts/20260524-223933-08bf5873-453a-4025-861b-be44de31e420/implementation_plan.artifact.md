# Implementation Plan - Improved Keyboard UX and Scrolling (Math & System)

Improve the user experience in the `AddEditQuestionScreen` and other screens by implementing automatic scrolling to the focused field and adding a smart preview bar above BOTH the math keyboard and the system keyboard.

## Proposed Changes

### Math Keyboard & Preview Component

#### [NEW] [keyboard_smart_preview.dart](file:///C:/Users/baish/StudioProjects/EduSheet/lib/features/math_keyboard/presentation/widgets/keyboard_smart_preview.dart)
- Create a new widget that displays a rendered preview of the current field's content.
- This widget will be used for both Math and System keyboards.
- Use `flutter_math_fork` for rendering TeX if the content contains LaTeX-like patterns.
- Implement a floating-style overlay or a fixed bar that sits exactly above the keyboard.

#### [math_keyboard_view.dart](file:///C:/Users/baish/StudioProjects/EduSheet/lib/features/math_keyboard/presentation/widgets/math_keyboard_view.dart)
- Integrate `KeyboardSmartPreview` at the top of the math keyboard view.

#### [math_keyboard_wrapper.dart](file:///C:/Users/baish/StudioProjects/EduSheet/lib/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart)
- Add a listener to `mathKeyboardControllerProvider` for focus changes.
- Add a listener for system keyboard visibility (using `MediaQuery.of(context).viewInsets.bottom` or a dedicated package/listener).
- Implement `_scrollToActiveField` to ensure the `activeFocusNode` is visible above the active keyboard.
- **System Keyboard Preview**: Add logic to show the `KeyboardSmartPreview` above the system keyboard when a `MathKeyboardField` is focused but math keyboard is NOT active.

#### [math_keyboard_field.dart](file:///C:/Users/baish/StudioProjects/EduSheet/lib/features/math_keyboard/presentation/widgets/math_keyboard_field.dart)
- Ensure it communicates focus to the `MathKeyboardController` even when using the system keyboard, so the preview knows which controller to watch.

### Question Bank Component

#### [add_edit_question_screen.dart](file:///C:/Users/baish/StudioProjects/EduSheet/lib/features/question_bank/presentation/screens/add_edit_question_screen.dart)
- No major changes needed if the wrapper handles the scrolling globally, but ensure the `ListView` has enough bottom padding.

## Verification Plan

### Manual Verification
1.  **Test System Keyboard Preview**:
    *   Tap a math-enabled field.
    *   Use the normal keyboard.
    *   Verify a preview bar appears above the system keyboard.
2.  **Test Math Keyboard Preview**:
    *   Switch to Math Keyboard.
    *   Verify the preview bar appears above it.
3.  **Test Auto-Scrolling**:
    *   Ensure fields at the bottom of the screen scroll up so they aren't hidden by either keyboard.
    *   Test switching between fields.
