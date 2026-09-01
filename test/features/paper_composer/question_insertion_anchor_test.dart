import 'package:edusheet/features/paper_composer/application/question_insertion_anchor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuestionInsertionAnchor', () {
    test('describes an empty question as line one position one', () {
      final anchor = QuestionInsertionAnchor.fromDocument(
        plainText: '\n',
        documentEnd: 0,
        baseOffset: 0,
        extentOffset: 0,
      );

      expect(anchor.start, 0);
      expect(anchor.length, 0);
      expect(anchor.lineNumber, 1);
      expect(anchor.columnNumber, 1);
      expect(anchor.compactLocation, 'Line 1 · position 1');
      expect(anchor.isAtDocumentEnd, isTrue);
    });

    test('reports line and position for a caret in multiline text', () {
      const text = 'Alpha\nBeta\n';
      final anchor = QuestionInsertionAnchor.fromDocument(
        plainText: text,
        documentEnd: text.length - 1,
        baseOffset: 7,
        extentOffset: 7,
      );

      expect(anchor.lineNumber, 2);
      expect(anchor.columnNumber, 2);
      expect(anchor.linePreview, 'Beta');
      expect(anchor.actionLabel, 'Insert at Line 2 · position 2');
    });

    test('normalizes reverse selections and exposes replacement intent', () {
      const text = 'Question text\n';
      final anchor = QuestionInsertionAnchor.fromDocument(
        plainText: text,
        documentEnd: text.length - 1,
        baseOffset: 8,
        extentOffset: 3,
      );

      expect(anchor.start, 3);
      expect(anchor.length, 5);
      expect(anchor.hasSelection, isTrue);
      expect(anchor.actionLabel, contains('Replace selection'));
    });

    test('clamps stale selection offsets to the live document', () {
      const text = 'Short\n';
      final anchor = QuestionInsertionAnchor.fromDocument(
        plainText: text,
        documentEnd: text.length - 1,
        baseOffset: 500,
        extentOffset: 500,
      );

      expect(anchor.start, text.length - 1);
      expect(anchor.length, 0);
      expect(anchor.isAtDocumentEnd, isTrue);
    });
  });
}
