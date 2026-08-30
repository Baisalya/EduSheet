import 'dart:io';

import 'package:edusheet/features/editor/data/repositories/local_paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/paper_validator.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';
import 'package:edusheet/features/pdf/domain/models/paper_export_config.dart';
import 'package:edusheet/features/pdf/services/booklet_imposition_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('edusheet_journey_');
    file = File('${directory.path}/papers.json');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  testWidgets('blank paper supports every persisted type, save and restore', (
    _,
  ) async {
    final questions = QuestionType.values.map((type) {
      final options = type.usesOptions
          ? [
              QuestionOption(id: 'a-${type.name}', text: 'A', isCorrect: true),
              QuestionOption(id: 'b-${type.name}', text: 'B'),
            ]
          : const <QuestionOption>[];
      final choices = type == QuestionType.internalChoice
          ? [
              Question(id: 'choice-a', text: 'First alternative'),
              Question(id: 'choice-b', text: 'Second alternative'),
            ]
          : const <Question>[];
      return Question(
        id: 'question-${type.name}',
        text: 'A ${type.label} question',
        type: type,
        options: options,
        internalChoices: choices,
        mathExpressions: type == QuestionType.mathematicalExpression
            ? const [
                MathExpression(
                  id: 'formula',
                  latex: r'x^2=4',
                  plainText: 'x squared equals four',
                ),
              ]
            : const [],
      );
    }).toList();
    final paper = Paper(
      id: 'blank-journey',
      title: 'Complete paper',
      createdAt: DateTime.utc(2025),
      sections: [
        PaperSection(id: 'section', title: 'Section A', questions: questions),
      ],
    );
    final repository = LocalPaperRepository(fileResolver: () async => file);

    expect(const PaperValidator().validate(paper).hasErrors, isFalse);
    await repository.savePaper(paper);
    final reopened = await LocalPaperRepository(
      fileResolver: () async => file,
    ).getAllPapers();

    expect(reopened.single.sections.single.questions, hasLength(19));
    expect(
      reopened.single.sections.single.questions
          .map((item) => item.type)
          .toSet(),
      QuestionType.values.toSet(),
    );
  });

  testWidgets(
    'new composer draft preserves data and export planning contracts',
    (_) async {
      final source = Question(
        id: 'existing',
        text: 'Original wording',
        subject: 'Physics',
        chapter: 'Motion',
        correctAnswer: '9.8 m/s²',
        metadata: const {'teacherNote': 'retain'},
        version: 3,
      );
      final edited = QuestionDraft.fromQuestion(source)
          .copyWith(text: 'Updated wording', marks: 4)
          .toQuestion(plainTextAccessibility: 'Updated wording');

      expect(edited.correctAnswer, source.correctAnswer);
      expect(edited.subject, source.subject);
      expect(edited.chapter, source.chapter);
      expect(edited.metadata['teacherNote'], 'retain');
      expect(edited.version, 4);

      const answerKey = PaperExportConfig(
        outputMode: PaperOutputMode.answerKey,
        pageSize: ExportPageSize.a4,
      );
      expect(answerKey.includesAnswers, isTrue);
      expect(answerKey.validate(), isEmpty);
      expect(
        const BookletImpositionService()
            .previewSequence(5)
            .map((page) => page.logicalPage)
            .toList(),
        [null, 1, 2, null, null, 3, 4, 5],
      );
    },
  );
}
