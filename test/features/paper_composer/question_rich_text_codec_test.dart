import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_expression_embed_builder.dart';
import 'package:edusheet/features/paper_composer/application/question_rich_text_codec.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = QuestionRichTextCodec();

  test('legacy plain text remains editable', () {
    final question = Question(id: 'q', text: 'Find x.');
    final document = codec.decodeQuestion(question);

    expect(codec.plainText(document), 'Find x.');
  });

  test('Quill delta round-trips through persisted string', () {
    final document = Document()..insert(0, 'Solve x = 2');
    final encoded = codec.encode(document);
    final decoded = codec.decodeQuestion(Question(id: 'q', text: encoded));

    expect(codec.plainText(decoded), 'Solve x = 2');
    expect(jsonDecode(encoded), isA<List<dynamic>>());
  });

  test('inline math remains inside the sentence after a save round-trip', () {
    const expression = MathExpression(
      id: 'm1',
      latex: r'\frac{a+b}{c}',
      plainText: '(a plus b) over c',
    );
    final document = Document();
    document.insert(0, 'The equation is ');
    document.insert('The equation is '.length, MathExpressionEmbed(expression));
    document.insert('The equation is '.length + 1, '. Find its value.');

    final encoded = codec.encode(document);
    final decoded = codec.decodeQuestion(Question(id: 'q', text: encoded));

    expect(
      codec.accessibleText(decoded),
      'The equation is (a plus b) over c. Find its value.',
    );
    expect(codec.embeddedMathExpressions(decoded), [
      isA<MathExpression>()
          .having((item) => item.id, 'id', 'm1')
          .having((item) => item.latex, 'latex', r'\frac{a+b}{c}'),
    ]);
    final operations = jsonDecode(encoded) as List<dynamic>;
    final hasInlineMathEmbed = operations.any((operation) {
      if (operation is! Map<String, dynamic>) {
        return false;
      }
      final insertedValue = operation['insert'];
      return insertedValue is Map<String, dynamic> &&
          insertedValue[MathExpression.quillEmbedKey] is String;
    });

    expect(hasInlineMathEmbed, isTrue);
  });

  test('unplaced math excludes formulas already embedded in rich text', () {
    const inline = MathExpression(
      id: 'inline',
      latex: r'x^2',
      plainText: 'x squared',
    );
    const legacy = MathExpression(
      id: 'legacy',
      latex: r'y^2',
      plainText: 'y squared',
    );
    final document = Document()..insert(0, MathExpressionEmbed(inline));
    final question = Question(
      id: 'q',
      text: codec.encode(document),
      mathExpressions: const [inline, legacy],
    );

    expect(
      codec.unplacedMathExpressions(question).map((item) => item.id),
      ['legacy'],
    );
  });

  test('accessibility text represents geometry embeds', () {
    final question = Question(
      id: 'q',
      text: jsonEncode([
        {'insert': 'Use '},
        {
          'insert': {'geometry': '{"id":"g"}'},
        },
        {'insert': ' to answer.\n'},
      ]),
    );
    final document = codec.decodeQuestion(question);

    expect(codec.accessibleText(document), contains('[diagram]'));
  });
}
