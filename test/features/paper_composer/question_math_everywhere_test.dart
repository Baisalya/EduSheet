import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/application/question_math_surface_service.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';
import 'package:edusheet/features/paper_composer/domain/question_details_draft.dart';
import 'package:edusheet/features/editor/domain/models/question_math_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = QuestionMathSurfaceService();
  const expression = MathExpression(
    id: 'surface-math-1',
    latex: r'x^2',
    plainText: 'x squared',
  );

  QuestionMathInlineDocument optionDocument() {
    return const QuestionMathInlineDocument(
      parts: [
        QuestionMathInlinePart.text('Choose '),
        QuestionMathInlinePart.math(expression),
        QuestionMathInlinePart.text(' now'),
      ],
    );
  }

  test('structured option math preserves readable legacy fallback', () {
    final initial = QuestionDraft.create(type: QuestionType.mcq);
    final option = initial.options.first;
    final updated = service.applyDocument(
      initial,
      QuestionMathSurfaceKey.option(option.id),
      optionDocument(),
    );

    expect(updated.options.first.text, 'Choose x squared now');
    expect(updated.mathContent.structuredSurfaceCount, 1);

    final saved = updated.toQuestion(
      plainTextAccessibility: 'Pick the correct expression.',
    );
    expect(saved.options.first.text, 'Choose x squared now');
    expect(
      saved.mathExpressions.map((item) => item.id),
      contains('surface-math-1'),
    );
    final persisted = QuestionMathContent.fromQuestion(saved);
    expect(persisted.structuredSurfaceCount, 1);
    expect(
      persisted
          .documentFor(
            QuestionMathSurfaceKey.option(option.id),
            currentFallback: saved.options.first.text,
          )
          ?.expressions
          .single
          .latex,
      r'x^2',
    );
  });

  test('plain editing a field fences out stale structured metadata', () {
    final initial = QuestionDraft.create(type: QuestionType.mcq);
    final option = initial.options.first;
    final withMath = service.applyDocument(
      initial,
      QuestionMathSurfaceKey.option(option.id),
      optionDocument(),
    );
    final plainEdited = withMath.copyWith(
      options: [
        withMath.options.first.copyWith(text: 'Completely different option'),
        ...withMath.options.skip(1),
      ],
    );

    final saved = plainEdited.toQuestion(plainTextAccessibility: 'Question');
    expect(QuestionMathContent.fromQuestion(saved).structuredSurfaceCount, 0);
    expect(saved.options.first.text, 'Completely different option');
    expect(
      saved.mathExpressions.map((item) => item.id),
      isNot(contains('surface-math-1')),
    );
  });

  test('direct Question reconciliation fences stale Word Mode edits', () {
    final initial = QuestionDraft.create(type: QuestionType.mcq);
    final option = initial.options.first;
    final withMath = service.applyDocument(
      initial,
      QuestionMathSurfaceKey.option(option.id),
      optionDocument(),
    );
    final saved = withMath.toQuestion(plainTextAccessibility: 'Question');
    final options = [...saved.options]
      ..[0] = saved.options.first.copyWith(text: 'Edited in Word Mode');

    final reconciled = service.reconcileQuestion(
      saved.copyWith(options: options),
    );

    expect(QuestionMathContent.fromQuestion(reconciled).hasAny, isFalse);
    expect(
      reconciled.mathExpressions.map((item) => item.id),
      isNot(contains('surface-math-1')),
    );
  });

  test(
    'surface discovery covers options, advanced blocks, table and details',
    () {
      final draft = QuestionDraft.create(type: QuestionType.mcq).copyWith(
        advancedContent: const QuestionAdvancedContent(
          stimulus: QuestionStimulus(title: 'Given', text: 'Use the graph'),
          wordBank: ['alpha', 'beta'],
        ),
        tableData: const QuestionTable(
          headers: ['x', 'y'],
          rows: [
            ['1', '2'],
          ],
          caption: 'Values',
        ),
        attachments: const [
          QuestionAttachment(
            id: 'image-1',
            kind: QuestionAttachmentKind.image,
            path: '/tmp/plot.png',
            alternativeText: 'Plot',
            caption: 'Graph',
          ),
        ],
        details: const QuestionDetailsDraft(
          instructions: 'Show working',
          correctAnswer: 'x squared',
          explanation: 'Square the value',
        ),
      );

      final keys = service
          .descriptorsForDraft(draft)
          .map((descriptor) => descriptor.key)
          .toSet();
      expect(
        keys,
        contains(QuestionMathSurfaceKey.option(draft.options.first.id)),
      );
      expect(keys, contains(QuestionMathSurfaceKey.tableHeader(0)));
      expect(keys, contains(QuestionMathSurfaceKey.tableCell(0, 1)));
      expect(keys, contains(QuestionMathSurfaceKey.tableCaption));
      expect(keys, contains(QuestionMathSurfaceKey.stimulusTitle));
      expect(keys, contains(QuestionMathSurfaceKey.stimulusText));
      expect(keys, contains(QuestionMathSurfaceKey.wordBank(1)));
      expect(
        keys,
        contains(QuestionMathSurfaceKey.attachmentCaption('image-1')),
      );
      expect(keys, contains(QuestionMathSurfaceKey.instructions));
      expect(keys, contains(QuestionMathSurfaceKey.correctAnswer));
      expect(keys, contains(QuestionMathSurfaceKey.explanation));
    },
  );

  test(
    'nested questions keep independent math-surface metadata on JSON round trip',
    () {
      final childContent = QuestionMathContent(
        surfaces: {QuestionMathSurfaceKey.instructions: optionDocument()},
      );
      final child = Question(
        id: 'child',
        text: 'Child',
        instructions: 'Choose x squared now',
        metadata: childContent.writeToMetadata(const {}),
      );
      final parent = Question(
        id: 'parent',
        text: 'Parent',
        subQuestions: [child],
      );

      final restored = Question.fromJson(parent.toJson());
      final restoredContent = QuestionMathContent.fromQuestion(
        restored.subQuestions.single,
      );
      expect(restoredContent.structuredSurfaceCount, 1);
      expect(
        restoredContent.documentFor(
          QuestionMathSurfaceKey.instructions,
          currentFallback: 'Choose x squared now',
        ),
        isNotNull,
      );
    },
  );
}
