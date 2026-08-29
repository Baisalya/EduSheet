EduSheet Fix 7 — Question Typing Viewport

Use the Full ZIP as a complete project snapshot.

If applying the Modified Files ZIP over the previous Fix6 tree, copy its files to the project root while preserving paths.

Recommended verification on your PC:
  dart format lib test
  flutter analyze
  flutter test test/features/paper_composer/question_composer_typing_viewport_test.dart
  flutter test
  flutter run -d windows

Manual flow:
  New/Edit question -> type some text -> Geometry -> create graph -> return -> keep typing below graph.
  Resize Windows narrow/wide and verify the current typing line remains visually reachable.
