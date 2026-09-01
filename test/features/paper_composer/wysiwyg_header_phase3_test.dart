import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/paper_composer/presentation/responsive/paper_page_canvas_metrics.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_header_layout_canvas.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/word_header_layout_editor_sheet.dart';
import 'package:edusheet/features/pdf/application/paper_header_layout_factory.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Preview and Word Mode share one page-canvas geometry contract', () {
    final metrics = PaperPageCanvasMetrics.resolve(
      layout: const PaperPageLayout(
        pageSize: PaperPageSize.a4,
        orientation: PaperPageOrientation.landscape,
        margins: PaperPageMargins(
          topPoints: 42,
          rightPoints: 36,
          bottomPoints: 48,
          leftPoints: 30,
        ),
      ),
      templatePageSize: PaperSize.letter,
      viewportWidth: 900,
    );

    expect(metrics.pagePoints.width, closeTo(841.89, 0.01));
    expect(metrics.pagePoints.height, closeTo(595.28, 0.01));
    expect(metrics.pageWidth, lessThanOrEqualTo(868));
    expect(metrics.pagePadding.left, greaterThan(0));
    expect(metrics.pagePadding.right, greaterThan(0));
    expect(metrics.pageMinHeight, greaterThan(0));
  });

  test('professional metadata slots keep teacher-added fields', () {
    const template = PaperTemplate(
      id: 'board',
      name: 'Board',
      type: TemplateType.board,
      headerLayout: HeaderLayout.dps,
    );
    final paper = Paper(
      id: 'p1',
      title: 'Exam',
      schoolName: 'School',
      createdAt: DateTime.utc(2026, 9, 1),
      headerFields: [
        PaperHeaderField(id: 'subject', label: 'Subject', value: 'Math'),
        PaperHeaderField(id: 'code', label: 'Paper Code', value: 'M-101'),
        PaperHeaderField(id: 'roll', label: 'Roll No', isPlaceholder: true),
        PaperHeaderField(id: 'custom', label: 'Invigilator', value: 'A. Rao'),
      ],
    );

    final layout = PaperHeaderLayoutFactory.resolveForPaper(template, paper);
    final block = layout.elements.firstWhere(
      (element) => element.type == ElementType.headerFieldsBlock,
    );
    final fields = PaperHeaderLayoutFactory.resolveHeaderFields(block, paper);

    expect(fields.map((field) => field.label), contains('Paper Code'));
    expect(fields.map((field) => field.label), contains('Roll No'));
    expect(fields.map((field) => field.label), contains('Invigilator'));
    expect(
      fields.firstWhere((field) => field.label == 'Subject').value,
      'Math',
    );
  });

  testWidgets('shared WYSIWYG header canvas edits the canonical paper fields', (
    tester,
  ) async {
    const template = PaperTemplate(
      id: 'school',
      name: 'School Formal',
      type: TemplateType.school,
      headerLayout: HeaderLayout.centered,
    );
    final paper = Paper(
      id: 'p1',
      title: 'Midterm',
      schoolName: 'ABC School',
      createdAt: DateTime.utc(2026, 9, 1),
      headerFields: [
        PaperHeaderField(id: 'subject', label: 'Subject', value: 'Math'),
        PaperHeaderField(id: 'class', label: 'Class', value: 'X'),
        PaperHeaderField(id: 'time', label: 'Time', value: '3 Hours'),
      ],
    );
    String? changedTitle;
    String? changedFieldId;
    String? changedFieldValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 700,
              child: PaperHeaderLayoutCanvas(
                template: template,
                paper: paper,
                editable: true,
                onSchoolNameChanged: (_) {},
                onTitleChanged: (value) => changedTitle = value,
                onHeaderFieldChanged: (fieldId, value) {
                  changedFieldId = fieldId;
                  changedFieldValue = value;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('word-paper-title')), findsOneWidget);
    final field = find.descendant(
      of: find.byKey(const Key('word-paper-title')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'Final Examination');
    await tester.pump();

    expect(changedTitle, 'Final Examination');

    final subjectField = find.descendant(
      of: find.byKey(const ValueKey('wysiwyg-header-field-subject')),
      matching: find.byType(TextField),
    );
    await tester.enterText(subjectField, 'Physics');
    await tester.pump();

    expect(changedFieldId, 'subject');
    expect(changedFieldValue, 'Physics');
    expect(tester.takeException(), isNull);
  });

  testWidgets('header designer exposes drag/snap layout controls', (
    tester,
  ) async {
    const template = PaperTemplate(
      id: 'school',
      name: 'School Formal',
      type: TemplateType.school,
      headerLayout: HeaderLayout.centered,
    );
    final paper = Paper(
      id: 'p1',
      title: 'Exam',
      schoolName: 'School',
      createdAt: DateTime.utc(2026, 9, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 800,
            child: WordHeaderLayoutEditorSheet(
              paper: paper,
              template: template,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arrange header'), findsOneWidget);
    expect(find.text('Snap 6 pt'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Line'), findsOneWidget);
    expect(find.byKey(const Key('header-layout-save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
