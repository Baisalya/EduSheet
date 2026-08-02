import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/paper_performance_profiler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profiles 100, 300 and 500-question papers within service budget', () {
    const profiler = PaperPerformanceProfiler();
    final profiles = <int, PaperPerformanceProfile>{};

    for (final count in [100, 300, 500]) {
      final profile = profiler.profile(_paperWithQuestions(count));
      profiles[count] = profile;
      expect(profile.questionCount, count);
      expect(profile.validation.hasErrors, isFalse);
      expect(profile.validationDuration, lessThan(const Duration(seconds: 5)));
      expect(
        profile.serializationDuration,
        lessThan(const Duration(seconds: 5)),
      );
    }

    expect(
      profiles[500]!.serializedBytes,
      greaterThan(profiles[300]!.serializedBytes),
    );
    expect(
      profiles[300]!.serializedBytes,
      greaterThan(profiles[100]!.serializedBytes),
    );
  });
}

Paper _paperWithQuestions(int count) {
  const questionsPerSection = 25;
  final sections = <PaperSection>[];
  var created = 0;
  while (created < count) {
    final sectionIndex = sections.length;
    final questions = <Question>[];
    for (
      var index = 0;
      index < questionsPerSection && created < count;
      index++, created++
    ) {
      questions.add(
        Question(
          id: 'question-$created',
          text: 'Solve question $created and justify each step.',
          marks: 2,
          mathExpressions: [
            MathExpression(
              id: 'formula-$created',
              latex: r'\frac{x^2 + 1}{x + 1}',
              plainText: '(x squared plus one) divided by (x plus one)',
            ),
          ],
        ),
      );
    }
    sections.add(
      PaperSection(
        id: 'section-$sectionIndex',
        title: 'Section ${sectionIndex + 1}',
        questions: questions,
      ),
    );
  }
  return Paper(
    id: 'performance-$count',
    title: '$count question paper',
    sections: sections,
    createdAt: DateTime.utc(2025),
  );
}
