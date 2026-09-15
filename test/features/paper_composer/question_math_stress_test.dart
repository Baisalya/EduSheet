import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_compatibility_service.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_export_typesetting.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_production_policy.dart';
import 'package:edusheet/features/paper_composer/application/question_math_validation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    MathCompatibilityCache.shared.clear(resetStatistics: true);
    MathExportTypesettingCache.shared.clear(resetStatistics: true);
  });

  tearDown(() {
    MathCompatibilityCache.shared.clear(resetStatistics: true);
    MathExportTypesettingCache.shared.clear(resetStatistics: true);
  });

  test('500-question math booklet validates deterministically', () {
    final questions = List.generate(500, (index) {
      final source = switch (index % 5) {
        0 => r'\frac{x+1}{2}',
        1 => r'x^2+y^2',
        2 => r'\sqrt{x+4}',
        3 => r'\sum_{i=1}^{n}i',
        _ => r'\begin{pmatrix}a&b\\c&d\end{pmatrix}',
      };
      return Question(
        id: 'q$index',
        text: 'Question $index',
        richTextFormat: 'plain-text-v1',
        mathExpressions: [
          MathExpression(
            id: 'm$index',
            latex: source,
            plainText: 'formula ${index % 5}',
          ),
        ],
      );
    });
    final paper = Paper(
      id: 'stress-paper',
      title: '500 Question Stress Paper',
      createdAt: DateTime.utc(2026, 9, 8),
      sections: [
        PaperSection(id: 'section-a', title: 'A', questions: questions),
      ],
    );

    const service = QuestionMathValidationService();
    final first = service.validateAndRepairPaper(paper);
    final second = service.validateAndRepairPaper(first.safePaper);

    expect(first.safePaper.sections.single.questions, hasLength(500));
    expect(first.formulaCount, 500);
    expect(first.invalidFormulaCount, 0);
    expect(second.invalidFormulaCount, 0);
    expect(
      jsonEncode(second.safePaper.toJson()),
      jsonEncode(first.safePaper.toJson()),
    );

    final compatibilityStats = MathCompatibilityCache.shared.snapshot;
    expect(compatibilityStats.entries, lessThanOrEqualTo(5));
    expect(compatibilityStats.hits, greaterThan(900));
  });

  test(
    'question validation preserves oversized source with resource diagnostic',
    () {
      final source = List.filled(
        MathProductionLimits.maxSourceCharacters + 1,
        'x',
      ).join();
      final question = Question(
        id: 'oversized',
        text: 'Oversized formula',
        richTextFormat: 'plain-text-v1',
        mathExpressions: [
          MathExpression(
            id: 'oversized-math',
            latex: source,
            plainText: 'complex expression',
          ),
        ],
      );

      final result = const QuestionMathValidationService().validateAndRepair(
        question,
      );

      expect(result.safeQuestion.mathExpressions.single.latex, source);
      expect(result.screenFallbackCount, 1);
      expect(result.pdfFallbackCount, 1);
      expect(result.wordFallbackCount, 1);
      expect(
        result.issues.any(
          (issue) =>
              issue.code ==
              QuestionMathIntegrityIssueCode.resourceBudgetExceeded,
        ),
        isTrue,
      );
    },
  );

  test('validator stops safely at pathological nested question depth', () {
    Question nested = Question(
      id: 'leaf',
      text: 'Leaf',
      richTextFormat: 'plain-text-v1',
    );
    for (
      var depth = MathProductionLimits.maxQuestionNestingDepth + 4;
      depth >= 0;
      depth--
    ) {
      nested = Question(
        id: 'nested-$depth',
        text: 'Nested $depth',
        richTextFormat: 'plain-text-v1',
        subQuestions: [nested],
      );
    }

    final result = const QuestionMathValidationService().validateAndRepair(
      nested,
    );

    expect(
      result.issues.any(
        (issue) =>
            issue.code == QuestionMathIntegrityIssueCode.validationDepthLimit,
      ),
      isTrue,
    );
    expect(result.safeQuestion.id, 'nested-0');
  });
}
