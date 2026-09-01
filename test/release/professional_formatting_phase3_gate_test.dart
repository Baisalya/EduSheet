import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/application/paper_header_layout_factory.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Phase 3 custom header geometry remains canonical and export-resolvable',
    () {
      final layout = CustomLayout(
        canvasHeight: 180,
        elements: [
          TemplateElement(
            id: 'school',
            type: ElementType.schoolName,
            x: 24,
            y: 12,
            width: 420,
            properties: const {
              'fontSize': 18.0,
              'bold': true,
              'alignment': 'center',
            },
          ),
          TemplateElement(
            id: 'line',
            type: ElementType.horizontalLine,
            x: 0,
            y: 164,
            width: CustomLayout.designWidth,
            properties: const {'thickness': 1.0},
          ),
        ],
      );
      final template = PaperTemplate(
        id: 'custom-phase3',
        name: 'Custom Phase 3',
        type: TemplateType.school,
        headerLayout: HeaderLayout.custom,
        customLayout: layout,
      );
      final paper = Paper(
        id: 'p1',
        title: 'Exam',
        schoolName: 'School',
        createdAt: DateTime.utc(2026, 9, 1),
      );

      final resolved = PaperHeaderLayoutFactory.resolveForPaper(
        template,
        paper,
      );

      expect(resolved.canvasHeight, 180);
      expect(resolved.elements.first.x, 24);
      expect(resolved.elements.first.y, 12);
      expect(resolved.elements.last.type, ElementType.horizontalLine);
    },
  );

  test('Phase 3 built-in headers provide professional metadata hierarchy', () {
    const board = PaperTemplate(
      id: 'board',
      name: 'Board',
      type: TemplateType.board,
      headerLayout: HeaderLayout.dps,
    );
    final paper = Paper(
      id: 'p2',
      title: 'Board Exam',
      schoolName: 'School',
      createdAt: DateTime.utc(2026, 9, 1),
      headerFields: [
        PaperHeaderField(id: 'subject', label: 'Subject', value: 'Science'),
        PaperHeaderField(id: 'class', label: 'Class', value: 'X'),
        PaperHeaderField(id: 'time', label: 'Time', value: '3 Hours'),
        PaperHeaderField(id: 'code', label: 'Paper Code', value: 'S-10'),
        PaperHeaderField(id: 'set', label: 'Set', value: 'A'),
      ],
    );

    final layout = PaperHeaderLayoutFactory.resolveForPaper(board, paper);
    final block = layout.elements.firstWhere(
      (element) => element.type == ElementType.headerFieldsBlock,
    );
    final fields = PaperHeaderLayoutFactory.resolveHeaderFields(block, paper);
    final labels = fields.map((field) => field.label).toSet();

    expect(
      labels,
      containsAll({'Subject', 'Class', 'Time', 'Paper Code', 'Set'}),
    );
    expect(
      layout.elements
          .where((element) => element.type == ElementType.horizontalLine)
          .length,
      greaterThanOrEqualTo(2),
    );
  });
}
