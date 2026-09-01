import 'dart:io';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_preview_page.dart';
import 'package:edusheet/features/pdf/application/paper_style_catalog.dart';
import 'package:edusheet/features/pdf/data/repositories/template_repository.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late TemplateRepository templateRepository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'edusheet_advanced_preview_',
    );
    templateRepository = TemplateRepository(
      fileResolver: () async =>
          File('${tempDirectory.path}${Platform.pathSeparator}templates.json'),
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  testWidgets('preview renders composable advanced question blocks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateRepositoryProvider.overrideWithValue(templateRepository),
        ],
        child: MaterialApp(home: PaperPreviewPage(paper: _paper())),
      ),
    );
    await tester.pumpAndSettle();

    final document = find.byKey(const Key('paper-preview-document'));
    expect(document, findsOneWidget);
    expect(
      find.descendant(of: document, matching: find.text('Reading source')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: document,
        matching: find.text('Water boils at 100°C at standard pressure.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: document, matching: find.text('solid')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: document, matching: find.text('liquid')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: document, matching: find.text('State table')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: document, matching: find.text('(a)')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: document, matching: find.text('OR')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Paper _paper() {
  const advanced = QuestionAdvancedContent(
    stimulus: QuestionStimulus(
      kind: QuestionStimulusKind.sourceText,
      title: 'Reading source',
      text: 'Water boils at 100°C at standard pressure.',
    ),
    wordBank: ['solid', 'liquid', 'gas'],
    answerSpace: QuestionAnswerSpace(
      style: QuestionAnswerSpaceStyle.ruled,
      lines: 2,
    ),
  );
  return Paper(
    id: 'preview-advanced',
    title: 'Advanced Preview',
    templateId: PaperStyleCatalog.defaultTemplateId,
    createdAt: DateTime(2026, 8, 31),
    sections: [
      PaperSection(
        id: 'section',
        title: 'Science',
        questions: [
          Question(
            id: 'question',
            text: 'Read and answer.',
            marks: 4,
            tableData: const QuestionTable(
              headers: ['State', 'Example'],
              rows: [
                ['Liquid', 'Water'],
              ],
              caption: 'State table',
            ),
            subQuestions: [
              Question(id: 'part-a', text: 'Name the process.', marks: 2),
            ],
            internalChoices: [
              Question(id: 'choice-a', text: 'Explain boiling.', marks: 2),
              Question(id: 'choice-b', text: 'Explain melting.', marks: 2),
            ],
            metadata: advanced.writeToMetadata(const {}),
          ),
        ],
      ),
    ],
  );
}
