EduSheet DF6 nested-table regression finder hotfix
==================================================

Observed result
---------------
Static analysis passed.

The new nested-table runtime test then failed only because Flutter's default
find.text(...) does not search RichText/TextSpan content in this renderer.

The production renderer uses RichText for Word paragraph runs. Therefore:
  find.text('Nested left')
can return zero even when the text is rendered correctly inside RichText.

Hotfix
------
Test-only change:

  find.text('Nested left', findRichText: true)
  find.text('Nested right', findRichText: true)

No production code changes.
No DOCX layout behavior changes.

Why this is appropriate
-----------------------
The runtime regression's primary purpose is to prove:
- no re-entrant layout exception;
- no missing-size/sliver cascade;
- nested table content reaches the rendered tree.

Using findRichText: true matches the actual renderer architecture and is the
same style of finder needed by high-fidelity Word RichText tests.

Run
---
flutter test test/features/document_reader/word_fidelity_nested_table_runtime_regression_test.dart

Then:
powershell -ExecutionPolicy Bypass -File .\tool\run_df6_word_real_document_runtime_hotfix_gate.ps1
