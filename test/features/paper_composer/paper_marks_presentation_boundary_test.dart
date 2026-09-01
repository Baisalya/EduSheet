import 'dart:io';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_inspector_panel.dart';
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
      'edusheet_marks_boundary_',
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

  testWidgets(
    'student paper preview renders maximum marks once and hides diagnostics',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1200));
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
        find.descendant(of: document, matching: find.text('Maximum Marks: 60')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: document,
          matching: find.textContaining('Assigned:'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: document,
          matching: find.textContaining('marks are not assigned yet'),
        ),
        findsNothing,
      );

      expect(
        find.byKey(const Key('paper-preview-teacher-diagnostics')),
        findsOneWidget,
      );
      expect(find.text('Teacher check • Not printed'), findsOneWidget);
      expect(find.text('40 marks are not assigned yet.'), findsOneWidget);
    },
  );

  testWidgets('teacher inspector keeps assigned/max mismatch diagnostics', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateRepositoryProvider.overrideWithValue(templateRepository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              child: PaperInspectorPanel(
                paper: _paper(),
                onEditDetails: _noop,
                onChooseStyle: _noop,
                onPreview: _noop,
                onExportPdf: _noop,
                onExportWord: _noop,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assigned marks'), findsOneWidget);
    expect(find.text('Maximum marks'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
    expect(find.text('40 marks are not assigned yet.'), findsOneWidget);
  });
}

void _noop() {}

Paper _paper() {
  return Paper(
    id: 'paper-marks-boundary',
    title: 'Unit Test',
    schoolName: 'Sample School',
    templateId: PaperStyleCatalog.defaultTemplateId,
    maximumMarks: 60,
    createdAt: DateTime(2026, 8, 31),
    headerFields: [
      PaperHeaderField(id: 'subject', label: 'Subject', value: 'Mathematics'),
      PaperHeaderField(id: 'class', label: 'Class', value: '10'),
      PaperHeaderField(id: 'time', label: 'Time', value: '2 Hours'),
    ],
    sections: [
      PaperSection(
        id: 'section-1',
        title: 'Section 1',
        questions: [Question(id: 'q1', text: 'Question one', marks: 20)],
      ),
    ],
  );
}
