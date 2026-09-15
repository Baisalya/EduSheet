import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_safety_validation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = MathSafetyValidationService();

  test('malformed formula is preserved but forced to safe fallback', () {
    const expression = MathExpression(
      id: 'bad-1',
      latex: r'\frac{1}{',
      plainText: 'one divided by an unfinished denominator',
    );

    final report = service.inspect(expression, path: 'question.body');

    expect(report.canPersist, isTrue);
    expect(report.hasErrors, isTrue);
    expect(
      report.issues.map((issue) => issue.code),
      contains(MathValidationIssueCode.malformedSyntax),
    );
    expect(report.readableFallback, contains('unfinished denominator'));
    expect(service.repairForPersistence(expression), same(expression));
  });

  test('empty source is rejected as a math object', () {
    const expression = MathExpression(id: 'empty', latex: '   ', plainText: '');

    final report = service.inspect(expression);

    expect(report.canPersist, isFalse);
    expect(
      report.issues.map((issue) => issue.code),
      contains(MathValidationIssueCode.emptySource),
    );
    expect(service.repairForPersistence(expression), isNull);
  });

  test('future math format is preserved without destructive conversion', () {
    const expression = MathExpression(
      id: 'future',
      latex: r'x^2',
      plainText: 'x squared',
      formatVersion: MathExpression.currentFormatVersion + 5,
    );

    final report = service.inspect(expression);

    expect(report.canPersist, isTrue);
    expect(
      report.issues.map((issue) => issue.code),
      contains(MathValidationIssueCode.futureFormatVersion),
    );
    expect(service.repairForPersistence(expression)?.formatVersion, 6);
  });

  test('MathExpression JSON accepts numeric strings without throwing', () {
    final expression = MathExpression.fromJson({
      'id': 'legacy',
      'latex': r'x+1',
      'plainText': 'x plus one',
      'formatVersion': '1',
    });

    expect(expression.formatVersion, 1);
    expect(expression.latex, r'x+1');
  });

  test('persistent identity is stable across metadata key ordering', () {
    const first = MathExpression(
      id: 'stable',
      latex: 'x',
      plainText: 'x',
      metadata: {
        'b': 2,
        'a': {'z': true, 'y': false},
      },
    );
    const second = MathExpression(
      id: 'stable',
      latex: 'x',
      plainText: 'x',
      metadata: {
        'a': {'y': false, 'z': true},
        'b': 2,
      },
    );

    expect(first.persistentIdentity, second.persistentIdentity);
  });
}
