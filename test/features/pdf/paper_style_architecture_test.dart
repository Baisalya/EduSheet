import 'dart:io';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/application/paper_header_layout_factory.dart';
import 'package:edusheet/features/pdf/application/paper_marks_resolver.dart';
import 'package:edusheet/features/pdf/application/paper_style_catalog.dart';
import 'package:edusheet/features/pdf/application/paper_template_resolver.dart';
import 'package:edusheet/features/pdf/data/repositories/template_repository.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('curated catalog has a real stable default and unique IDs', () {
    final all = PaperStyleCatalog.allBuiltInTemplates;
    final ids = all.map((template) => template.id).toList();

    expect(
      all.any((template) => template.id == PaperStyleCatalog.defaultTemplateId),
      isTrue,
    );
    expect(ids.toSet().length, ids.length);
    expect(PaperStyleCatalog.visibleTemplates.length, greaterThanOrEqualTo(8));
  });

  test('teacher-facing preset names do not claim institutional branding', () {
    const prohibited = [
      'cbse',
      'icse',
      'dps',
      'ssvm',
      'allen',
      'aakash',
      'xavier',
    ];
    for (final template in PaperStyleCatalog.visibleTemplates) {
      final name = template.name.toLowerCase();
      for (final term in prohibited) {
        expect(
          name,
          isNot(contains(term)),
          reason: '${template.id} exposed $term',
        );
      }
    }
  });

  test(
    'legacy template IDs remain resolvable but hidden from main chooser',
    () {
      const legacyIds = {
        'school_ssvm_style',
        'school_dps_style',
        'school_xavier_style',
        'coaching_allen',
        'coaching_akash',
        'kids_cartoon',
      };
      final all = PaperStyleCatalog.allBuiltInTemplates;

      for (final id in legacyIds) {
        final resolved = PaperTemplateResolver.resolve(id, all);
        expect(resolved.id, id);
        expect(PaperStyleCatalog.isVisibleBuiltIn(id), isFalse);
      }
    },
  );

  test(
    'all persisted header-layout values resolve without branded static copy',
    () {
      for (final layout in HeaderLayout.values) {
        final custom = CustomLayout(
          elements: [
            TemplateElement(
              id: 'custom-title',
              type: ElementType.paperTitle,
              x: 0,
              y: 0,
            ),
          ],
          canvasHeight: 50,
        );
        final template = PaperTemplate(
          id: 'layout-${layout.name}',
          name: layout.name,
          type: TemplateType.school,
          headerLayout: layout,
          customLayout: layout == HeaderLayout.custom ? custom : null,
        );
        final resolved = PaperHeaderLayoutFactory.resolve(template);

        expect(resolved.elements, isNotEmpty);
        expect(resolved.canvasHeight, greaterThan(0));
        final staticText = resolved.elements
            .where((element) => element.type == ElementType.staticText)
            .map((element) => element.content.toLowerCase())
            .join(' ');
        expect(staticText, isNot(contains('dps')));
        expect(staticText, isNot(contains('ssvm')));
      }
    },
  );

  test('built-in header expands for additional teacher metadata', () {
    final template = PaperStyleCatalog.presets.first.template;
    final paper = Paper(
      id: 'metadata-paper',
      title: 'Examination',
      schoolName: 'School',
      createdAt: DateTime(2026),
      headerFields: [
        for (var index = 0; index < 7; index++)
          PaperHeaderField(
            id: 'field-$index',
            label: 'Field ${index + 1}',
            value: 'Value ${index + 1}',
          ),
      ],
    );

    final base = PaperHeaderLayoutFactory.resolve(template);
    final expanded = PaperHeaderLayoutFactory.resolveForPaper(template, paper);

    expect(expanded.canvasHeight, greaterThan(base.canvasHeight));
    final baseMarks = base.elements.firstWhere(
      (element) => element.type == ElementType.maxMarks,
    );
    final expandedMarks = expanded.elements.firstWhere(
      (element) => element.type == ElementType.maxMarks,
    );
    expect(expandedMarks.y, greaterThan(baseMarks.y));
  });

  test('unknown template ID resolves to School Formal', () {
    final resolved = PaperTemplateResolver.resolve(
      'missing-template',
      PaperStyleCatalog.allBuiltInTemplates,
    );
    expect(resolved.id, PaperStyleCatalog.defaultTemplateId);
  });

  test('marks resolver explains under and over assignment', () {
    final section = PaperSection(
      id: 's1',
      title: 'Section A',
      questions: [
        Question(id: 'q1', text: 'One', marks: 30),
        Question(id: 'q2', text: 'Two', marks: 20),
      ],
    );
    final under = Paper(
      id: 'p1',
      title: 'Paper',
      sections: [section],
      maximumMarks: 60,
      createdAt: DateTime(2026),
    );
    final over = under.copyWith(maximumMarks: 40);

    expect(
      PaperMarksResolver.summarize(under).balance,
      PaperMarksBalance.underAssigned,
    );
    expect(
      PaperMarksResolver.summarize(under).teacherMessage,
      contains('10 marks'),
    );
    expect(
      PaperMarksResolver.summarize(over).balance,
      PaperMarksBalance.overAssigned,
    );
    expect(PaperMarksResolver.summarize(over).teacherMessage, contains('10'));
  });

  test('custom clone preserves page size', () async {
    final directory = await Directory.systemTemp.createTemp(
      'edusheet_style_clone_',
    );
    addTearDown(() async => directory.delete(recursive: true));
    final file = File('${directory.path}/templates.json');
    final repository = TemplateRepository(fileResolver: () async => file);
    final notifier = TemplateNotifier(repository);
    addTearDown(notifier.dispose);
    await notifier.loadCustomTemplates();

    const base = PaperTemplate(
      id: 'legal-source',
      name: 'Legal source',
      type: TemplateType.college,
      paperSize: PaperSize.legal,
      paperLayout: PaperLayout.twoColumn,
      headerLayout: HeaderLayout.academic,
    );
    await notifier.saveAsCustom(base, 'Legal copy');

    final saved = notifier.state.custom.singleWhere(
      (template) => template.name == 'Legal copy',
    );
    expect(saved.paperSize, PaperSize.legal);
    expect(saved.paperLayout, PaperLayout.twoColumn);
    expect(saved.headerLayout, HeaderLayout.academic);
  });
}
