import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/question_math_content.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/safe_math_expression.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/word_paper_editor.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const half = MathExpression(
    id: 'word-surface-half',
    latex: r'\frac{1}{2}',
    plainText: 'one half',
  );
  const square = MathExpression(
    id: 'word-surface-square',
    latex: r'x^2',
    plainText: 'x squared',
  );

  testWidgets(
    'Word Mode renders active structured field math without replacing editable fallback',
    (tester) async {
      final option = QuestionOption(id: 'option-a', text: 'x squared');
      const content = QuestionMathContent(
        surfaces: {
          QuestionMathSurfaceKey.instructions: QuestionMathInlineDocument(
            parts: [
              QuestionMathInlinePart.text('Use '),
              QuestionMathInlinePart.math(half),
            ],
          ),
          'option:option-a': QuestionMathInlineDocument(
            parts: [QuestionMathInlinePart.math(square)],
          ),
        },
      );
      final question = Question(
        id: 'q1',
        text: 'Choose the correct value.',
        type: QuestionType.mcq,
        instructions: 'Use one half',
        options: [option],
        mathExpressions: const [half, square],
        metadata: content.writeToMetadata(const {}),
      );
      final paper = Paper(
        id: 'paper',
        title: 'Exam',
        createdAt: DateTime.utc(2026, 9, 8),
        sections: [
          PaperSection(
            id: 'section',
            title: 'Section A',
            questions: [question],
          ),
        ],
      );
      const template = PaperTemplate(
        id: 'phase7-test',
        name: 'Phase 7 Test',
        type: TemplateType.school,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 900,
                height: 900,
                child: WordPaperEditor(
                  paper: paper,
                  compact: false,
                  template: template,
                  onTitleChanged: (_) {},
                  onSchoolNameChanged: (_) {},
                  onInstructionChanged: (_) {},
                  onInstructionAlignmentChanged: (_) {},
                  onHeaderFieldChanged: (_, _) {},
                  onLogoChanged: (_, _) {},
                  onSectionTitleChanged: (_, _) {},
                  onSectionInstructionChanged: (_, _) {},
                  onReplaceSection: (_) {},
                  onEditQuestion: (_, _) {},
                  onReplaceQuestion: (_, _) {},
                  onInsertWordBlock: (_, _, _) {},
                  onDeleteQuestion: (_, _) {},
                  onAddSection: () {},
                  onAddFromQuestionBank: (_) async {},
                  onImportWord: () async {},
                  onArrangeHeader: () async {},
                  onApplyPageLayout: (_, _, _, _) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SafeMathExpression), findsAtLeastNWidgets(2));
      expect(find.text('Use '), findsOneWidget);
      expect(find.text('Use one half'), findsNothing);
      // The legacy option string remains present in the editable field while the
      // structured preview is rendered directly below it.
      expect(find.text('x squared'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
