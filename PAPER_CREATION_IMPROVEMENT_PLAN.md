# EduSheet: Paper Creation Improvement Plan

This document outlines the strategy to enhance the paper creation experience, making it more reliable, user-friendly, and efficient by combining modular structured data with a fluid, "MS Word-like" editing experience.

---

## 1. Modular Mode Enhancements (Reliability & Speed)
Modular mode is essential for maintaining structure (marks, types, sections). We will make it "faster" by reducing the "friction" of opening/closing sheets.

### **A. "Save & Add Next" Workflow**
*   **Current Issue**: User adds a question -> saves -> sheet closes -> user clicks "Add Question" again.
*   **Improvement**: Add a "Save & Next" button in `QuestionEditorSheet`.
*   **Effect**: Clears the editor and resets focus to the question title immediately after saving, allowing for rapid-fire question entry.

### **B. In-Place Mini-Editors**
*   **Current Issue**: To change 1 word in a question, you must open the full sheet.
*   **Improvement**: Clicking a question on the main screen expands it into an "Inline Editor" instead of a modal sheet.
*   **Effect**: Users can see the context of other questions while editing.

### **C. Intelligent Defaulting**
*   **Improvement**: The editor should remember the last used `Marks` and `QuestionType` (e.g., if you are adding 10 MCQs worth 1 mark, you shouldn't have to select "MCQ" and type "1" ten times).

---

## 2. "Word Mode" Implementation (Document-Style Editing)
To satisfy the "MS Word" requirement, we will introduce a view where a whole section is a single continuous document.

### **A. The Unified Section Editor**
*   **Concept**: A full-screen `QuillEditor` that represents one `PaperSection`.
*   **Question Breaks**: Use a custom Quill Block Embed (e.g., a "Question Divider") that clearly marks where Question 1 ends and Question 2 begins.
*   **Mathematical Integration**: The floating Math Keyboard remains active at the bottom, allowing the user to insert complex LaTeX into any part of the continuous document.

### **B. Smart Parsing**
*   When the user finishes "Word Mode", the app parses the document:
    *   Everything between `Divider A` and `Divider B` becomes `Question 1`.
    *   Automatically detects bullet points (a, b, c, d) to convert them into `QuestionOptions` for MCQs.

---

## 3. Keyboard & Accessibility Improvements
Power users should rarely need to touch the screen.

*   **Keyboard Shortcuts**:
    *   `Ctrl + S`: Save Paper.
    *   `Ctrl + Enter`: Save Question & Add Next.
    *   `Tab`: Move from Question text to Options text.
*   **Math Keyboard Focus**: Ensure that when the Math Keyboard is visible, the cursor position in the `QuillEditor` is maintained and the view scrolls to keep the cursor visible above the keyboard.

---

## 4. Visual "WYSIWYG" (What You See Is What You Get)
Align the editor UI with the Template Creator's output.

*   **Template Sync**: Apply the fonts, primary colors, and margins selected in the **Template Designer** directly to the `QuillEditor` background and text style.
*   **Real-time Preview**: Use a split-screen layout on tablets/desktop where the PDF preview updates in real-time as the user types in Modular or Word mode.

---

## 5. Technical Action Items
1.  **Refactor `EditorState`**: Add `bulkUpdateQuestions` to support Word Mode parsing.
2.  **Update `QuestionEditorSheet`**: Implement the `addAnother` logic.
3.  **Enhance `MathKeyboardField`**: Improve focus node management to prevent keyboard flickering during rapid navigation.
4.  **Parsing Engine**: Develop a utility that converts a single `Quill Delta` with dividers into a `List<Question>`.
