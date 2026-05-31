import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/section_word_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('splits document text on dividers', () {
    final questions = SectionWordParser.parsePlainText('''
--- Question 1 ---
Define a polynomial.

--- Question 2 ---
Solve x + 4 = 10.
''', defaultMarks: 2);

    expect(questions, hasLength(2));
    expect(_plainText(questions.first.text), 'Define a polynomial.\n');
    expect(_plainText(questions.last.text), 'Solve x + 4 = 10.\n');
    expect(questions.every((question) => question.marks == 2), isTrue);
  });

  test('detects MCQ options from lettered lines', () {
    final questions = SectionWordParser.parsePlainText('''
1. Which value is prime?
a) 4
b) 9
c) 11
d) 21
''');

    expect(questions, hasLength(1));
    expect(questions.single.type, QuestionType.mcq);
    expect(questions.single.options.map((option) => option.text), [
      '4',
      '9',
      '11',
      '21',
    ]);
  });

  test('splits numbered questions without explicit dividers', () {
    final questions = SectionWordParser.parsePlainText('''
1. Simplify 2x + 3x.
2. Factor x^2 - 9.
''');

    expect(questions, hasLength(2));
    expect(_plainText(questions.first.text), 'Simplify 2x + 3x.\n');
    expect(_plainText(questions.last.text), 'Factor x^2 - 9.\n');
  });

  test('ignores page break markers', () {
    final questions = SectionWordParser.parsePlainText('''
--- Question 1 ---
Find x.

--- Page Break ---

--- Question 2 ---
Find y.
''');

    expect(questions, hasLength(2));
    expect(_plainText(questions.first.text), 'Find x.\n');
    expect(_plainText(questions.last.text), 'Find y.\n');
  });

  test('splits localized and alphabetic question dividers', () {
    final questions = SectionWordParser.parsePlainText('''
--- Question a ---
Write any identity.

--- Question १ ---
Solve one equation.

--- Question ୨ ---
Draw a triangle.
''');

    expect(questions, hasLength(3));
    expect(_plainText(questions.first.text), 'Write any identity.\n');
    expect(_plainText(questions[1].text), 'Solve one equation.\n');
    expect(_plainText(questions.last.text), 'Draw a triangle.\n');
  });
}

String _plainText(String deltaString) {
  final delta = jsonDecode(deltaString) as List<dynamic>;
  return delta.map((op) => (op as Map<String, dynamic>)['insert']).join();
}
