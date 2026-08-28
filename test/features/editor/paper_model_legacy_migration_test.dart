import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('legacy paper JSON', () {
    test('loads the pre-refactor three question types without data loss', () {
      final paper = Paper.fromJson({
        'id': 'paper-legacy',
        'title': 'Legacy paper',
        'schoolName': 'Example School',
        'sections': [
          {
            'id': 'section-a',
            'title': 'Section A',
            'questions': [
              {
                'id': 'q-mcq',
                'text': 'Choose one',
                'type': 0,
                'marks': 1,
                'options': [
                  {'id': 'a', 'text': 'A', 'isCorrect': true},
                  {'id': 'b', 'text': 'B', 'isCorrect': false},
                ],
              },
              {
                'id': 'q-description',
                'text': 'Explain',
                'type': 1,
                'marks': 5.5,
                'alignment': TextAlign.center.index,
              },
              {
                'id': 'q-blank',
                'text': 'Complete _____',
                'type': 2,
                'marks': 2,
              },
            ],
          },
        ],
        'createdAt': '2026-06-19T09:39:00.000',
      });

      expect(paper.id, 'paper-legacy');
      expect(paper.sections.single.questions, hasLength(3));
      expect(paper.sections.single.questions[0].type, QuestionType.mcq);
      expect(paper.sections.single.questions[1].type, QuestionType.descriptive);
      expect(
        paper.sections.single.questions[2].type,
        QuestionType.fillInTheBlanks,
      );
      expect(paper.sections.single.questions[1].marks, 5.5);
      expect(paper.sections.single.questions[1].alignment, TextAlign.center);
    });

    test('round trip keeps immutable IDs, options and numbering settings', () {
      final original = Paper(
        id: 'paper-1',
        title: 'Round trip',
        createdAt: DateTime.utc(2026, 7, 19),
        questionNumberStyle: QuestionNumberStyle.lowerRoman,
        sections: [
          PaperSection(
            id: 'section-1',
            title: 'Section I',
            questions: [
              Question(
                id: 'question-1',
                text: '2 + 2 = ?',
                type: QuestionType.mcq,
                options: [
                  QuestionOption(id: 'option-1', text: '4', isCorrect: true),
                ],
              ),
            ],
          ),
        ],
      );

      final decoded = Paper.fromJson(original.toJson());

      expect(decoded.id, original.id);
      expect(decoded.sections.single.id, 'section-1');
      expect(decoded.sections.single.questions.single.id, 'question-1');
      expect(
        decoded.sections.single.questions.single.options.single.id,
        'option-1',
      );
      expect(decoded.questionNumberStyle, QuestionNumberStyle.lowerRoman);
    });
  });
}
