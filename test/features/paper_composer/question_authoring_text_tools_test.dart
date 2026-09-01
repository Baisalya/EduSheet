import 'package:edusheet/features/paper_composer/application/question_authoring_text_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuestionAuthoringTextTools', () {
    test('blank is printable ordinary text', () {
      expect(QuestionAuthoringTextTools.blank(width: 8), '________');
      expect(QuestionAuthoringTextTools.blank(width: 1), '____');
    });

    test('sub-question helper follows existing line-start labels', () {
      expect(
        QuestionAuthoringTextTools.nextSubQuestionInsertion('Question'),
        '\n(a) ',
      );
      expect(
        QuestionAuthoringTextTools.nextSubQuestionInsertion(
          'Question\n(a) First\n(b) Second',
        ),
        '\n(c) ',
      );
    });

    test('sub-question labels continue beyond z instead of resetting', () {
      final parts = List.generate(
        26,
        (index) => '(${String.fromCharCode(97 + index)}) Part',
      ).join('\n');
      expect(
        QuestionAuthoringTextTools.nextSubQuestionInsertion(parts),
        '\n(aa) ',
      );
    });

    test('OR and instruction helpers remain editable printable text', () {
      expect(
        QuestionAuthoringTextTools.orDividerInsertion('Question'),
        '\n\nOR\n',
      );
      expect(
        QuestionAuthoringTextTools.instructionInsertion('Question'),
        '\nInstruction: ',
      );
    });

    test(
      'mid-document helpers use text before the saved cursor for spacing',
      () {
        const fullText = 'First line\nSecond line';
        expect(
          QuestionAuthoringTextTools.instructionInsertion(
            fullText,
            textBeforeInsertion: 'First line\n',
          ),
          'Instruction: ',
        );
        expect(
          QuestionAuthoringTextTools.orDividerInsertion(
            fullText,
            textBeforeInsertion: 'First line',
          ),
          '\n\nOR\n',
        );
      },
    );
  });
}
