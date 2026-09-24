import 'dart:io';
import 'dart:typed_data';

import 'package:edusheet/features/document_reader/data/services/word_fidelity_document_cache.dart';
import 'package:edusheet/features/document_reader/presentation/widgets/viewers/word_fidelity_document_view.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_interop_embed_builders.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DF5 Word fidelity cache reuses unchanged parses and invalidates changes',
      () async {
    final directory = await Directory.systemTemp.createTemp('edusheet-df5-cache-');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final file = File('${directory.path}${Platform.pathSeparator}sample.docx');
    await file.writeAsBytes(<int>[1, 2, 3], flush: true);

    final cache = WordFidelityDocumentCache(maxEntries: 2);
    var calls = 0;
    Future<ConversionDocument> loader(File _) async {
      calls += 1;
      return _singlePageDocument('cache-$calls');
    }

    final first = await cache.load(file, loader);
    final second = await cache.load(file, loader);
    expect(calls, 1);
    expect(identical(first, second), isTrue);
    expect(cache.length, 1);

    await file.writeAsBytes(<int>[1, 2, 3, 4], flush: true);
    final third = await cache.load(file, loader);
    expect(calls, 2);
    expect(identical(third, first), isFalse);
  });

  test('DF5 Smart Editor payload decoding is cached for stable embed data', () {
    final imageData = SmartEditorInteropImagePayload(
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      objectId: 'image-1',
      widthPoints: 320,
      heightPoints: 180,
    ).encode();
    final firstImage = SmartEditorInteropImagePayload.fromData(imageData);
    final secondImage = SmartEditorInteropImagePayload.fromData(imageData);
    expect(identical(firstImage, secondImage), isTrue);

    const table = SmartEditorInteropTablePayload(
      widthPoints: 620,
      gridColumnWidths: <double>[220, 400],
      rows: <SmartEditorInteropTableRow>[
        SmartEditorInteropTableRow(
          cells: <SmartEditorInteropTableCell>[
            SmartEditorInteropTableCell(text: 'Left'),
            SmartEditorInteropTableCell(text: 'Right'),
          ],
        ),
      ],
    );
    final tableData = table.encode();
    final firstTable = SmartEditorInteropTablePayload.fromData(tableData);
    final secondTable = SmartEditorInteropTablePayload.fromData(tableData);
    expect(identical(firstTable, secondTable), isTrue);
  });

  test('DF5 narrow Smart Editor preserves fixed Word table geometry by scroll',
      () {
    const fixed = SmartEditorInteropTablePayload(
      widthPoints: 620,
      gridColumnWidths: <double>[220, 400],
      rows: <SmartEditorInteropTableRow>[],
    );
    final phone = SmartEditorInteropTableViewportPolicy.resolve(fixed, 300);
    expect(phone.horizontalScroll, isTrue);
    expect(phone.contentWidth, 620);

    final desktop = SmartEditorInteropTableViewportPolicy.resolve(fixed, 900);
    expect(desktop.horizontalScroll, isFalse);
    expect(desktop.contentWidth, 620);

    const fluid = SmartEditorInteropTablePayload(
      widthPercent: 85,
      rows: <SmartEditorInteropTableRow>[],
    );
    final fluidPhone =
        SmartEditorInteropTableViewportPolicy.resolve(fluid, 300);
    expect(fluidPhone.horizontalScroll, isFalse);
    expect(fluidPhone.contentWidth, closeTo(255, 0.01));
  });

  testWidgets('DF5 high-fidelity viewer lazily builds a long multi-page DOCX',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 700));

    final document = ConversionDocument(
      sections: <ConversionSection>[
        ConversionSection(
          page: const ConversionPageSettings(),
          blocks: List<ConversionBlock>.generate(
            40,
            (index) => ConversionParagraph(
              pageBreakBefore: index > 0,
              inlines: <ConversionInline>[
                ConversionTextRun(text: 'DF5 page ${index + 1}'),
              ],
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WordFidelityDocumentView(
            document: document,
            pageWidth: 374,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('word-fidelity-lazy-page-list')),
      findsOneWidget,
    );
    final builtPages = find.byKey(const ValueKey('word-fidelity-page'));
    expect(builtPages, findsWidgets);
    expect(builtPages.evaluate().length, lessThan(40));
    expect(tester.takeException(), isNull);
  });
}

ConversionDocument _singlePageDocument(String text) {
  return ConversionDocument(
    sections: <ConversionSection>[
      ConversionSection(
        page: const ConversionPageSettings(),
        blocks: <ConversionBlock>[
          ConversionParagraph(
            inlines: <ConversionInline>[ConversionTextRun(text: text)],
          ),
        ],
      ),
    ],
  );
}
