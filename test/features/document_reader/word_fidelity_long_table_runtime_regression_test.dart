import 'package:edusheet/features/document_reader/presentation/widgets/viewers/word_fidelity_document_view.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'long Word table rows paginate without duplicate preserved keys or overflow',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1536, 760));

      List<ConversionBlock> longCell(String prefix, int count) => <ConversionBlock>[
            const ConversionOpaqueOoxmlBlock(
              featureKind: 'contentControl',
              rawXml: '<w:sdt data-test="one"/>',
            ),
            const ConversionOpaqueOoxmlBlock(
              featureKind: 'contentControl',
              rawXml: '<w:sdt data-test="two"/>',
            ),
            for (var i = 0; i < count; i++)
              ConversionParagraph(
                spaceAfterPoints: 3,
                inlines: <ConversionInline>[
                  ConversionTextRun(
                    text: '$prefix item $i — realistic multi-page table content',
                  ),
                ],
              ),
          ];

      final document = ConversionDocument(
        sections: <ConversionSection>[
          ConversionSection(
            page: const ConversionPageSettings(
              widthPoints: 612,
              heightPoints: 792,
              marginTopPoints: 36,
              marginRightPoints: 36,
              marginBottomPoints: 36,
              marginLeftPoints: 36,
            ),
            blocks: <ConversionBlock>[
              ConversionTable(
                widthPercent: 100,
                gridColumnWidths: const <double>[180, 360],
                rows: <ConversionTableRow>[
                  ConversionTableRow(
                    cells: <ConversionTableCell>[
                      ConversionTableCell(
                        shadingHex: 'AA0000',
                        blocks: longCell('Sidebar', 95),
                      ),
                      ConversionTableCell(
                        blocks: longCell('Main', 140),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordFidelityDocumentView(
              document: document,
              pageWidth: 816,
            ),
          ),
        ),
      );

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }

      final list = find.byKey(const ValueKey('word-fidelity-lazy-page-list'));
      expect(list, findsOneWidget);

      // ListView.builder is intentionally lazy, so page 2 is not guaranteed to
      // have a mounted RepaintBoundary while the initial viewport is still on
      // page 1. Assert the logical page count through the delegate instead of
      // requiring an off-screen widget to exist eagerly.
      final pageList = tester.widget<ListView>(list);
      expect(
        pageList.childrenDelegate.estimatedChildCount,
        isNotNull,
      );
      expect(
        pageList.childrenDelegate.estimatedChildCount!,
        greaterThan(1),
        reason: 'the oversized Word table must paginate to multiple pages',
      );

      for (var i = 0; i < 5; i++) {
        await tester.drag(list, const Offset(0, -900));
        await tester.pump(const Duration(milliseconds: 32));
        expect(
          tester.takeException(),
          isNull,
          reason: 'page ${i + 2} must remain within the printable body',
        );
      }
      expect(find.textContaining('Main item', findRichText: true), findsWidgets);
    },
  );
}
