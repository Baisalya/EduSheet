import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/templates/data/built_in_content_templates.dart';
import 'package:edusheet/features/templates/domain/models/content_template.dart';
import 'package:edusheet/features/templates/services/template_clone_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('content templates', () {
    test('ships all required offline paper starter styles', () {
      final names = BuiltInContentTemplates.papers
          .map((item) => item.name)
          .toSet();

      expect(names, contains('School unit test'));
      expect(names, contains('Monthly examination'));
      expect(names, contains('Term examination'));
      expect(names, contains('Board-style examination'));
      expect(names, contains('Mathematics worksheet'));
      expect(names, contains('Practice assignment'));
      expect(names, contains('Multiple-choice test'));
      expect(names, contains('Question-and-answer booklet'));
      expect(names, contains('Answer sheet'));
      expect(names, contains('Custom blank template'));
      expect(BuiltInContentTemplates.papers, hasLength(10));
    });

    test('insertion creates independent IDs at every mutable level', () {
      var next = 0;
      final service = TemplateCloneService(newId: () => 'new-${next++}');
      final source = Question(
        id: 'source-question',
        text: 'Source',
        options: [QuestionOption(id: 'source-option', text: 'A')],
        subQuestions: [Question(id: 'source-part', text: 'Part A')],
      );

      final inserted = service.cloneQuestion(source);
      final edited = inserted.copyWith(text: 'Changed inside paper');

      expect(inserted.id, isNot(source.id));
      expect(inserted.options.single.id, isNot(source.options.single.id));
      expect(inserted.subQuestions.single.id, isNot(source.subQuestions.single.id));
      expect(source.text, 'Source');
      expect(edited.text, 'Changed inside paper');
    });

    test('resolves variables inside Quill JSON without breaking quotes', () {
      const resolver = TemplateVariableResolver();
      final paper = Paper(
        id: 'paper',
        title: '{{exam_name}}',
        schoolName: '{{school_name}}',
        createdAt: DateTime(2026),
        sections: [
          PaperSection(
            id: 'section',
            title: '{{subject}}',
            questions: [
              Question(
                id: 'question',
                text: '[{"insert":"Class: {{class}}\\n"}]',
              ),
            ],
          ),
        ],
      );

      final resolved = resolver.resolvePaper(paper, {
        'exam_name': 'Term "A"',
        'school_name': 'Example School',
        'subject': 'Mathematics',
        'class': '10',
      });

      expect(resolved.title, 'Term "A"');
      final operations = jsonDecode(
        resolved.sections.single.questions.single.text,
      ) as List<dynamic>;
      expect((operations.single as Map)['insert'], 'Class: 10\n');
      expect(
        resolved.sections.single.questions.single.plainTextAccessibility,
        'Class: 10',
      );
      expect(resolver.unresolvedVariables(resolved), isEmpty);
    });

    test('reports variables that were not supplied', () {
      final paper = Paper(
        id: 'paper',
        title: '{{exam_name}}',
        schoolName: '{{school_name}}',
        createdAt: DateTime(2026),
      );

      final unresolved = const TemplateVariableResolver().unresolvedVariables(
        paper,
      );

      expect(unresolved, {'exam_name', 'school_name'});
    });

    test('template library data round trips every template category', () {
      final source = TemplateLibraryData(
        questions: [
          QuestionTemplate(
            id: 'question-template',
            name: 'Question',
            question: Question(id: 'q', text: 'Q'),
          ),
        ],
        sections: [BuiltInContentTemplates.sections.first],
        papers: [BuiltInContentTemplates.papers.first],
      );

      final restored = TemplateLibraryData.fromJson(source.toJson());

      expect(restored.questions.single.id, 'question-template');
      expect(restored.sections.single.section.questions, isNotEmpty);
      expect(restored.papers.single.paper.headerFields, isNotEmpty);
    });
  });
}
