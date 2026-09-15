import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/safe_math_expression.dart';
import 'package:edusheet/features/editor/domain/models/question_math_content.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_math_surface_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expression = MathExpression(
    id: 'view-math',
    latex: r'\frac{1}{2}',
    plainText: 'one half',
  );

  testWidgets(
    'matching surface renders structured math instead of plain-only text',
    (tester) async {
      const document = QuestionMathInlineDocument(
        parts: [
          QuestionMathInlinePart.text('Value is '),
          QuestionMathInlinePart.math(expression),
        ],
      );
      final content = QuestionMathContent(
        surfaces: {QuestionMathSurfaceKey.instructions: document},
      );
      final question = Question(
        id: 'q',
        text: 'Question',
        instructions: 'Value is one half',
        metadata: content.writeToMetadata(const {}),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestionMathSurfaceView(
              question: question,
              surfaceKey: QuestionMathSurfaceKey.instructions,
              fallbackText: question.instructions,
            ),
          ),
        ),
      );

      expect(find.byType(SafeMathExpression), findsOneWidget);
      expect(find.text('Value is '), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stale surface falls back to current legacy string', (
    tester,
  ) async {
    const document = QuestionMathInlineDocument(
      parts: [QuestionMathInlinePart.math(expression)],
    );
    final content = QuestionMathContent(
      surfaces: {QuestionMathSurfaceKey.instructions: document},
    );
    final question = Question(
      id: 'q',
      text: 'Question',
      instructions: 'New plain instructions',
      metadata: content.writeToMetadata(const {}),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestionMathSurfaceView(
            question: question,
            surfaceKey: QuestionMathSurfaceKey.instructions,
            fallbackText: question.instructions,
          ),
        ),
      ),
    );

    expect(find.byType(SafeMathExpression), findsNothing);
    expect(find.text('New plain instructions'), findsOneWidget);
  });
  testWidgets('structured-only mode stays hidden for plain fallback surfaces', (
    tester,
  ) async {
    final question = Question(
      id: 'plain',
      text: 'Question',
      instructions: 'Plain instructions',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestionMathSurfaceView(
            question: question,
            surfaceKey: QuestionMathSurfaceKey.instructions,
            fallbackText: question.instructions,
            showFallback: false,
          ),
        ),
      ),
    );

    expect(find.text('Plain instructions'), findsNothing);
    expect(find.byType(SafeMathExpression), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
