import 'package:edusheet/features/document_reader/presentation/widgets/viewers/word_fidelity_document_view.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'real-document regression: nested Word tables do not re-enter layout',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1536, 700));

      const nested = ConversionTable(
        widthPercent: 100,
        gridColumnWidths: <double>[120, 180],
        rows: <ConversionTableRow>[
          ConversionTableRow(
            cells: <ConversionTableCell>[
              ConversionTableCell(
                blocks: <ConversionBlock>[
                  ConversionParagraph(
                    inlines: <ConversionInline>[
                      ConversionTextRun(text: 'Nested left'),
                    ],
                  ),
                ],
              ),
              ConversionTableCell(
                blocks: <ConversionBlock>[
                  ConversionParagraph(
                    inlines: <ConversionInline>[
                      ConversionTextRun(text: 'Nested right'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      const outer = ConversionTable(
        widthPercent: 100,
        gridColumnWidths: <double>[260, 260],
        rows: <ConversionTableRow>[
          ConversionTableRow(
            cells: <ConversionTableCell>[
              ConversionTableCell(
                verticalAlignment:
                    ConversionTableCellVerticalAlignment.center,
                blocks: <ConversionBlock>[
                  ConversionParagraph(
                    inlines: <ConversionInline>[
                      ConversionTextRun(text: 'Outer cell'),
                    ],
                  ),
                  nested,
                ],
              ),
              ConversionTableCell(
                blocks: <ConversionBlock>[
                  ConversionParagraph(
                    inlines: <ConversionInline>[
                      ConversionTextRun(
                        text:
                            'Second cell with enough content to require row-height measurement.',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      const document = ConversionDocument(
        sections: <ConversionSection>[
          ConversionSection(
            page: ConversionPageSettings(
              widthPoints: 612,
              heightPoints: 792,
              marginTopPoints: 36,
              marginRightPoints: 36,
              marginBottomPoints: 36,
              marginLeftPoints: 36,
            ),
            blocks: <ConversionBlock>[
              ConversionParagraph(
                inlines: <ConversionInline>[
                  ConversionTextRun(text: 'Nested table runtime fixture'),
                ],
              ),
              outer,
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WordFidelityDocumentView(
              document: document,
              pageWidth: 816,
            ),
          ),
        ),
      );

      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }

      expect(
        find.byKey(const ValueKey('word-fidelity-lazy-page-list')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('word-fidelity-page')),
        findsWidgets,
      );
      expect(find.text('Nested left', findRichText: true), findsOneWidget);
      expect(find.text('Nested right', findRichText: true), findsOneWidget);
    },
  );
}
