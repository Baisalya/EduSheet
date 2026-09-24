import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/document_reader/presentation/widgets/viewers/word_fidelity_document_view.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('VF1/VF2 normalize page orientation and complex-script run metrics',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('word_vfa_geometry_');
    try {
      final file = await _writeGeometryFixture(tempDir);
      final document = await DocxConversionParser.parse(file);
      final section = document.sections.single;

      expect(section.page.widthPoints, closeTo(792, 0.1));
      expect(section.page.heightPoints, closeTo(612, 0.1));
      expect(section.page.marginLeftPoints, closeTo(36, 0.1));
      expect(section.page.marginTopPoints, closeTo(45, 0.1));

      final run = section.blocks
          .whereType<ConversionParagraph>()
          .first
          .inlines
          .whereType<ConversionTextRun>()
          .single;
      expect(run.style.fontFamily, 'Aptos');
      expect(run.style.fontSizePoints, closeTo(9, 0.01));
      expect(run.style.bold, isTrue);
      expect(run.style.italic, isTrue);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
    'VF3 resume-style oversized two-column row continues on the first page',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1536, 900));

      ConversionParagraph textBlock(
        String text, {
        double size = 10,
        bool bold = false,
        double before = 0,
        double after = 3,
      }) {
        return ConversionParagraph(
          spaceBeforePoints: before,
          spaceAfterPoints: after,
          inlines: <ConversionInline>[
            ConversionTextRun(
              text: text,
              style: ConversionTextStyle(
                fontFamily: 'Century Gothic',
                fontSizePoints: size,
                bold: bold,
              ),
            ),
          ],
        );
      }

      final sidebar = <ConversionBlock>[
        ConversionParagraph(
          spaceAfterPoints: 10,
          inlines: const <ConversionInline>[
            ConversionShapeRun(
              kind: ConversionShapeKind.rectangle,
              widthPoints: 126,
              heightPoints: 150,
              style: ConversionShapeStyle(fillColorHex: 'D9D9D9'),
            ),
          ],
        ),
        textBlock('PROFILE', size: 12, bold: true, before: 6, after: 4),
        textBlock(
          'Seeking a position that will utilize my talent to enhance the growth of the organization.',
          after: 8,
        ),
        textBlock('CONTACT', size: 12, bold: true, after: 4),
        for (var i = 0; i < 18; i++)
          textBlock('Sidebar detail $i — professional resume information'),
      ];

      final main = <ConversionBlock>[
        textBlock('BAISALYA', size: 32, after: 2),
        textBlock('ROUL', size: 30, after: 18),
        textBlock('PROJECTS', size: 12, bold: true, after: 6),
        textBlock('PROFESSIONAL WORK EXPERIENCE', size: 12, bold: true),
        for (var i = 0; i < 45; i++)
          textBlock(
            'PROJECT $i — Developed cross-platform business application with production workflows and professional document fidelity.',
            after: 3,
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
                layout: ConversionTableLayout.fixed,
                gridColumnWidths: const <double>[180, 360],
                rows: <ConversionTableRow>[
                  ConversionTableRow(
                    cells: <ConversionTableCell>[
                      ConversionTableCell(
                        shadingHex: 'F0EEEE',
                        paddingLeftPoints: 8,
                        paddingRightPoints: 8,
                        blocks: sidebar,
                      ),
                      ConversionTableCell(
                        paddingLeftPoints: 10,
                        paddingRightPoints: 10,
                        blocks: main,
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
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }

      final firstPage = find.byKey(
        const ValueKey('word-fidelity-page-boundary-0'),
      );
      expect(firstPage, findsOneWidget);

      // The old safety workaround reserved an entire page for each continuation
      // fragment, creating a large blank area below photo/name resume headers.
      // Super Phase A must be able to place at least two legal row fragments on
      // page 1 while keeping each fragment inside the printable body.
      expect(
        find.descendant(
          of: firstPage,
          matching: find.byKey(
            const ValueKey('word-table-cell-0-0-span-1'),
          ),
        ),
        findsAtLeastNWidgets(2),
      );
      expect(
        find.descendant(
          of: firstPage,
          matching: find.textContaining('PROFILE', findRichText: true),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: firstPage,
          matching: find.textContaining('PROJECTS', findRichText: true),
        ),
        findsWidgets,
      );

      final list = find.byKey(const ValueKey('word-fidelity-lazy-page-list'));
      expect(list, findsOneWidget);
      final pageList = tester.widget<ListView>(list);
      expect(pageList.childrenDelegate.estimatedChildCount, isNotNull);
      expect(pageList.childrenDelegate.estimatedChildCount!, greaterThan(1));

      for (var i = 0; i < 4; i++) {
        await tester.drag(list, const Offset(0, -850));
        await tester.pump(const Duration(milliseconds: 32));
        expect(tester.takeException(), isNull);
      }
    },
  );
}

Future<File> _writeGeometryFixture(Directory directory) async {
  const documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:r>
        <w:rPr>
          <w:rFonts w:cs="Aptos"/>
          <w:szCs w:val="18"/>
          <w:bCs/>
          <w:iCs/>
        </w:rPr>
        <w:t>Complex script metrics</w:t>
      </w:r>
    </w:p>
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840" w:orient="landscape"/>
      <w:pgMar w:top="900" w:right="720" w:bottom="720" w:left="720"/>
    </w:sectPr>
  </w:body>
</w:document>''';

  final archive = Archive()
    ..addFile(ArchiveFile.string('word/document.xml', documentXml));
  final file = File(p.join(directory.path, 'vf_geometry.docx'));
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  return file;
}
