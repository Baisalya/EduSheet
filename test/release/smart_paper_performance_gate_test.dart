import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/paper_performance_profiler.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('200 advanced questions remain inside the existing service budget', () {
    const profiler = PaperPerformanceProfiler();
    final profile = profiler.profile(_advancedPaper(200));

    expect(profile.questionCount, 200);
    expect(profile.validation.hasErrors, isFalse);
    expect(profile.validationDuration, lessThan(const Duration(seconds: 5)));
    expect(profile.serializationDuration, lessThan(const Duration(seconds: 5)));
    expect(profile.serializedBytes, greaterThan(100000));
  });
}

Paper _advancedPaper(int count) {
  const advanced = QuestionAdvancedContent(
    stimulus: QuestionStimulus(
      kind: QuestionStimulusKind.sourceText,
      title: 'Data source',
      text:
          'A short source paragraph used to exercise advanced metadata serialization.',
    ),
    wordBank: ['alpha', 'beta', 'gamma'],
    answerSpace: QuestionAnswerSpace(
      style: QuestionAnswerSpaceStyle.ruled,
      lines: 2,
    ),
  );

  final questions = List<Question>.generate(count, (index) {
    return Question(
      id: 'advanced-performance-$index',
      text: 'Interpret data set $index and justify the result.',
      marks: 2,
      tableData: QuestionTable(
        headers: const ['X', 'Y'],
        rows: [
          ['$index', '${index + 1}'],
        ],
        caption: 'Data $index',
      ),
      subQuestions: [
        Question(
          id: 'advanced-performance-$index-a',
          text: 'State one observation.',
          marks: 1,
        ),
      ],
      internalChoices: [
        Question(
          id: 'advanced-performance-$index-or-a',
          text: 'Explain using words.',
          marks: 1,
        ),
        Question(
          id: 'advanced-performance-$index-or-b',
          text: 'Explain using a ratio.',
          marks: 1,
        ),
      ],
      metadata: advanced.writeToMetadata(const {'releaseGate': true}),
    );
  });

  return Paper(
    id: 'advanced-performance-paper',
    title: 'Advanced performance paper',
    createdAt: DateTime.utc(2026, 8, 31),
    sections: [
      PaperSection(
        id: 'advanced-performance-section',
        title: 'Section A',
        questions: questions,
      ),
    ],
  );
}
