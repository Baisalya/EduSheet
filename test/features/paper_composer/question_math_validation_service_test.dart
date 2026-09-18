import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/question_math_content.dart';
import 'package:edusheet/features/paper_composer/application/question_math_surface_service.dart';
import 'package:edusheet/features/paper_composer/application/question_math_validation_service.dart';
import 'package:edusheet/features/paper_composer/application/question_rich_text_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = QuestionMathValidationService();
  const codec = QuestionRichTextCodec();
  const surfaceService = QuestionMathSurfaceService();

  test(
    'stale Math Everywhere metadata is detached without changing field text',
    () {
      const expression = MathExpression(
        id: 'surface-1',
        latex: r'\frac{1}{2}',
        plainText: 'one half',
      );
      final content = QuestionMathContent(
        surfaces: {
          QuestionMathSurfaceKey.option('a'): QuestionMathInlineDocument(
            parts: [QuestionMathInlinePart.math(expression)],
          ),
        },
      );
      final question = Question(
        id: 'q1',
        text: 'Question',
        options: [QuestionOption(id: 'a', text: 'edited option')],
        mathExpressions: const [expression],
        metadata: content.writeToMetadata(const {}),
      );

      final result = service.validateAndRepair(question);

      expect(result.safeQuestion.options.single.text, 'edited option');
      expect(
        QuestionMathContent.fromQuestion(result.safeQuestion).hasAny,
        isFalse,
      );
      expect(
        result.issues.map((issue) => issue.code),
        contains(QuestionMathIntegrityIssueCode.staleSurface),
      );
    },
  );

  test(
    'valid rich text preserves explicit accessibility wording verbatim',
    () {
      final question = Question(
        id: 'accessible-verbatim',
        text: jsonEncode([
          {'insert': 'Second page verification with √x, θ and π.\n'},
        ]),
        richTextFormat: 'quill-delta-json-v1',
        plainTextAccessibility:
            'Second page verification with square root x theta and pi.',
      );

      final result = service.validateAndRepair(question);

      expect(result.issues, isEmpty);
      expect(
        result.safeQuestion.plainTextAccessibility,
        'Second page verification with square root x theta and pi.',
      );
    },
  );

  test(
    'malformed body math embed becomes readable fallback instead of crash',
    () {
      final text = jsonEncode([
        {
          'insert': {
            MathExpression.quillEmbedKey: '{ definitely not valid json',
          },
        },
        {'insert': '\n'},
      ]);
      final question = Question(
        id: 'q2',
        text: text,
        richTextFormat: 'quill-delta-json-v1',
      );

      final result = service.validateAndRepair(question);
      final decoded = codec.decodeQuestion(result.safeQuestion);

      expect(codec.plainText(decoded), contains('[formula]'));
      expect(
        result.issues.map((issue) => issue.code),
        contains(QuestionMathIntegrityIssueCode.malformedMathEmbed),
      );
    },
  );

  test(
    'conflicting expression ids are repaired without losing either formula',
    () {
      const bodyExpression = MathExpression(
        id: 'shared-id',
        latex: 'x',
        plainText: 'x',
      );
      const optionExpression = MathExpression(
        id: 'shared-id',
        latex: 'y',
        plainText: 'y',
      );
      final body = jsonEncode([
        {
          'insert': {
            MathExpression.quillEmbedKey: bodyExpression.toQuillEmbedData(),
          },
        },
        {'insert': '\n'},
      ]);
      final content = QuestionMathContent(
        surfaces: {
          QuestionMathSurfaceKey.option('a'): QuestionMathInlineDocument(
            parts: const [QuestionMathInlinePart.math(optionExpression)],
          ),
        },
      );
      final question = Question(
        id: 'q3',
        text: body,
        options: [QuestionOption(id: 'a', text: 'y')],
        mathExpressions: const [bodyExpression, optionExpression],
        metadata: content.writeToMetadata(const {}),
      );

      final result = service.validateAndRepair(question);
      final bodyMath = codec.embeddedMathExpressions(
        codec.decodeQuestion(result.safeQuestion),
      );
      final optionMath = surfaceService
          .activeContentForQuestion(result.safeQuestion)
          .expressions;

      expect(bodyMath, hasLength(1));
      expect(optionMath, hasLength(1));
      expect(bodyMath.single.latex, 'x');
      expect(optionMath.single.latex, 'y');
      expect(bodyMath.single.id, isNot(optionMath.single.id));
      expect(result.safeQuestion.mathExpressions, hasLength(2));
      expect(
        result.issues.map((issue) => issue.code),
        contains(QuestionMathIntegrityIssueCode.conflictingExpressionId),
      );
    },
  );

  test('missing canonical mirror is rebuilt for placed formula', () {
    const expression = MathExpression(
      id: 'placed',
      latex: r'x^2',
      plainText: 'x squared',
    );
    final body = jsonEncode([
      {
        'insert': {MathExpression.quillEmbedKey: expression.toQuillEmbedData()},
      },
      {'insert': '\n'},
    ]);
    final question = Question(id: 'q4', text: body);

    final result = service.validateAndRepair(question);

    expect(result.safeQuestion.mathExpressions, hasLength(1));
    expect(result.safeQuestion.mathExpressions.single.id, 'placed');
    expect(
      result.issues.map((issue) => issue.code),
      contains(QuestionMathIntegrityIssueCode.missingCanonicalExpression),
    );
  });

  test('nested questions are validated recursively', () {
    const malformed = MathExpression(
      id: '',
      latex: r'\frac{1}{',
      plainText: 'unfinished fraction',
    );
    final child = Question(
      id: 'child',
      text: 'Child',
      mathExpressions: const [malformed],
    );
    final parent = Question(
      id: 'parent',
      text: 'Parent',
      subQuestions: [child],
    );

    final result = service.validateAndRepair(parent);
    final repaired =
        result.safeQuestion.subQuestions.single.mathExpressions.single;

    expect(repaired.id, startsWith('math.safe.'));
    expect(repaired.latex, malformed.latex);
    expect(result.invalidFormulaCount, 1);
    expect(
      result.issues.any((issue) => issue.path.contains('subQuestions[0]')),
      isTrue,
    );
  });

  test(
    'future Math Everywhere metadata is preserved and not destructively parsed',
    () {
      final futurePayload = {
        'version': 99,
        'surfaces': {
          'option:a': {
            'futureShape': {'unknown': true},
          },
        },
      };
      final question = Question(
        id: 'future-surface',
        text: 'Question',
        options: [QuestionOption(id: 'a', text: 'legacy fallback')],
        metadata: {QuestionMathContent.metadataKey: futurePayload},
      );

      final result = service.validateAndRepair(question);

      expect(
        result.safeQuestion.metadata[QuestionMathContent.metadataKey],
        futurePayload,
      );
      expect(
        result.issues.map((issue) => issue.code),
        contains(QuestionMathIntegrityIssueCode.futureSurfaceMetadataVersion),
      );
    },
  );
}
