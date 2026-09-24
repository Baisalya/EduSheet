import 'dart:io';

import 'package:edusheet/features/document_reader/presentation/widgets/viewers/word_fidelity_document_view.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/word_wm7_wm8_fixture.dart';

void main() {
  test('WM7 canonical parser preserves advanced Word inline intent', () async {
    final fixture = await writeWm78Fixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) await fixture.parent.delete(recursive: true);
    });

    final document = await DocxConversionParser.parse(fixture);
    expect(document.backgroundColorHex, 'FFF8E8');
    final inlines = document.sections.first.blocks
        .whereType<ConversionParagraph>()
        .expand((paragraph) => paragraph.inlines)
        .toList(growable: false);

    final field = inlines.whereType<ConversionFieldRun>().single;
    expect(field.fieldName, 'DATE');
    expect(field.resultText, '2026');
    expect(field.locked, isTrue);
    expect(inlines.whereType<ConversionDynamicFieldRun>(), hasLength(1));

    final math = inlines.whereType<ConversionMathRun>().single;
    expect(math.plainText, 'x+1');
    expect(math.ommlXml, contains('<m:oMath'));

    final notes = inlines.whereType<ConversionNoteReferenceRun>().toList();
    expect(notes, hasLength(2));
    expect(notes.first.blocks, isNotEmpty);
    expect(notes.last.blocks, isNotEmpty);

    final bookmarks = inlines.whereType<ConversionBookmarkMarkerRun>().toList();
    expect(bookmarks, hasLength(2));
    expect(bookmarks.first.name, 'Target_One');

    final commentMarkers = inlines.whereType<ConversionCommentMarkerRun>().toList();
    expect(commentMarkers, hasLength(3));
    final commentReference = commentMarkers.singleWhere(
      (marker) => marker.kind == ConversionWordMarkerKind.reference,
    );
    expect(commentReference.comment?.author, 'Teacher');
    expect(commentReference.comment?.text, contains('Check this wording.'));

    final internalLink = inlines.whereType<ConversionTextRun>().singleWhere(
      (run) => run.text == 'Jump back',
    );
    expect(internalLink.hyperlink, '#Target_One');

    final textPath = inlines.whereType<ConversionShapeRun>().singleWhere(
      (shape) => shape.kind == ConversionShapeKind.textPath,
    );
    expect(textPath.style.rotationDegrees, 315);
    expect(textPath.placement.behindText, isTrue);
    expect(
      textPath.blocks
          .whereType<ConversionParagraph>()
          .expand((paragraph) => paragraph.inlines)
          .whereType<ConversionTextRun>()
          .map((run) => run.text),
      contains('DRAFT'),
    );
    expect(WordFidelityDocumentView.shouldUseFor(document), isTrue);
  });

  testWidgets('WM7 fidelity viewer renders note stories and background safely', (
    tester,
  ) async {
    final fixture = (await tester.runAsync<File>(writeWm78Fixture))!;
    addTearDown(() => tester.runAsync(() async {
          if (await fixture.parent.exists()) {
            await fixture.parent.delete(recursive: true);
          }
        }));
    final document = (await tester.runAsync<ConversionDocument>(
      () => DocxConversionParser.parse(fixture),
    ))!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 1000,
            child: WordFidelityDocumentView(document: document, pageWidth: 816),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('word-note-area')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-footnote-reference-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-endnote-reference-3')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
