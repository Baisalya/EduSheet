import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:edusheet/features/document_reader/presentation/widgets/viewers/word_fidelity_document_view.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  testWidgets(
    'VF4 paragraph-relative floating objects keep page anchors, wrap space and non-overlap',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1100, 900));

      const firstPlacement = ConversionObjectPlacement.floating(
        horizontalRelativeFrom: 'column',
        verticalRelativeFrom: 'paragraph',
        horizontalOffsetPoints: 0,
        verticalOffsetPoints: 0,
        allowOverlap: false,
        wrapStyle: 'wrapSquare',
        wrapText: 'right',
        distanceRightPoints: 6,
        relativeHeight: 10,
      );
      const secondPlacement = ConversionObjectPlacement.floating(
        horizontalRelativeFrom: 'column',
        verticalRelativeFrom: 'paragraph',
        horizontalOffsetPoints: 0,
        verticalOffsetPoints: 0,
        allowOverlap: false,
        wrapStyle: 'wrapTight',
        wrapText: 'right',
        distanceTopPoints: 4,
        distanceRightPoints: 6,
        relativeHeight: 20,
      );
      expect(firstPlacement.isPagePositioned, isFalse);
      expect(firstPlacement.isViewerPositioned, isTrue);
      expect(firstPlacement.affectsTextFlow, isTrue);

      final document = ConversionDocument(
        sections: <ConversionSection>[
          ConversionSection(
            page: const ConversionPageSettings(
              widthPoints: 612,
              heightPoints: 792,
              marginTopPoints: 54,
              marginRightPoints: 54,
              marginBottomPoints: 54,
              marginLeftPoints: 54,
            ),
            blocks: const <ConversionBlock>[
              ConversionParagraph(
                spaceAfterPoints: 8,
                inlines: <ConversionInline>[
                  ConversionTextRun(
                    text:
                        'Anchored paragraph text wraps to the right of the floating shapes and must remain readable.',
                    style: ConversionTextStyle(fontSizePoints: 11),
                  ),
                  ConversionShapeRun(
                    kind: ConversionShapeKind.rectangle,
                    widthPoints: 108,
                    heightPoints: 58,
                    style: ConversionShapeStyle(
                      fillColorHex: 'D9EAF7',
                      strokeColorHex: '2E75B6',
                    ),
                    placement: firstPlacement,
                  ),
                  ConversionShapeRun(
                    kind: ConversionShapeKind.roundedRectangle,
                    widthPoints: 108,
                    heightPoints: 50,
                    style: ConversionShapeStyle(
                      fillColorHex: 'FFF2CC',
                      strokeColorHex: 'BF9000',
                      dashStyle: 'dashDot',
                    ),
                    placement: secondPlacement,
                  ),
                ],
              ),
              ConversionParagraph(
                inlines: <ConversionInline>[
                  ConversionTextRun(text: 'Following paragraph after anchor region.'),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordFidelityDocumentView(document: document, pageWidth: 612),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }

      final firstFinder = find.byKey(const ValueKey('word-floating-0-10'));
      final secondFinder = find.byKey(const ValueKey('word-floating-1-20'));
      expect(firstFinder, findsOneWidget);
      expect(secondFinder, findsOneWidget);
      expect(
        find.byKey(const ValueKey('word-anchor-wrap-reservation')),
        findsWidgets,
      );

      final first = tester.widget<Positioned>(firstFinder);
      final second = tester.widget<Positioned>(secondFinder);
      expect(first.top, isNotNull);
      expect(second.top, isNotNull);
      // Second object has allowOverlap=false and begins at the same Word anchor.
      expect(second.top!, greaterThan(first.top! + 50));
    },
  );

  testWidgets(
    'VF5 long prose can continue on the current page while keep-lines-safe flow remains overflow free',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(900, 720));

      final longText = StringBuffer('FLOW_START ');
      for (var i = 0; i < 125; i++) {
        longText.write(
          'professional document pagination keeps readable lines and Word flow $i ',
        );
      }
      longText.write(' FLOW_END');

      final document = ConversionDocument(
        sections: <ConversionSection>[
          ConversionSection(
            page: const ConversionPageSettings(
              widthPoints: 432,
              heightPoints: 360,
              marginTopPoints: 24,
              marginRightPoints: 24,
              marginBottomPoints: 24,
              marginLeftPoints: 24,
            ),
            blocks: <ConversionBlock>[
              const ConversionParagraph(
                spaceAfterPoints: 4,
                inlines: <ConversionInline>[
                  ConversionShapeRun(
                    kind: ConversionShapeKind.rectangle,
                    widthPoints: 40,
                    heightPoints: 138,
                    style: ConversionShapeStyle(fillColorHex: 'EEEEEE'),
                  ),
                ],
              ),
              ConversionParagraph(
                widowControl: true,
                keepLines: false,
                spaceAfterPoints: 4,
                inlines: <ConversionInline>[
                  ConversionTextRun(
                    text: longText.toString(),
                    style: const ConversionTextStyle(fontSizePoints: 10),
                  ),
                ],
              ),
              const ConversionParagraph(
                keepWithNext: true,
                inlines: <ConversionInline>[
                  ConversionTextRun(text: 'KEEP_WITH_NEXT_HEADING'),
                ],
              ),
              const ConversionParagraph(
                inlines: <ConversionInline>[
                  ConversionTextRun(text: 'KEEP_WITH_NEXT_BODY'),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordFidelityDocumentView(document: document, pageWidth: 720),
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
      // Without VF5 paragraph fragmentation the whole long paragraph is moved
      // away from the first page after the 138pt leading object.
      expect(
        find.descendant(
          of: firstPage,
          matching: find.textContaining('FLOW_START', findRichText: true),
        ),
        findsWidgets,
      );

      final list = find.byKey(const ValueKey('word-fidelity-lazy-page-list'));
      final pageList = tester.widget<ListView>(list);
      final pageCount = pageList.childrenDelegate.estimatedChildCount;
      expect(pageCount, isNotNull);
      expect(pageCount!, greaterThan(1));
      for (var i = 0; i < 4; i++) {
        await tester.drag(list, const Offset(0, -600));
        await tester.pump(const Duration(milliseconds: 32));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'VF5 compatible continuous and next-column sections stay in one visual page flow',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1000, 850));

      const page = ConversionPageSettings(
        widthPoints: 612,
        heightPoints: 792,
        marginTopPoints: 54,
        marginRightPoints: 54,
        marginBottomPoints: 54,
        marginLeftPoints: 54,
      );
      const columns = ConversionColumns(count: 2, spacingPoints: 24);
      ConversionParagraph paragraph(String text) => ConversionParagraph(
            spaceAfterPoints: 4,
            inlines: <ConversionInline>[ConversionTextRun(text: text)],
          );

      final document = ConversionDocument(
        sections: <ConversionSection>[
          ConversionSection(
            page: page,
            columns: columns,
            blocks: <ConversionBlock>[paragraph('SECTION_A_COLUMN_1')],
          ),
          ConversionSection(
            page: page,
            columns: columns,
            breakType: ConversionSectionBreakType.nextColumn,
            blocks: <ConversionBlock>[paragraph('SECTION_B_COLUMN_2')],
          ),
          ConversionSection(
            page: page,
            columns: columns,
            breakType: ConversionSectionBreakType.continuous,
            blocks: <ConversionBlock>[paragraph('SECTION_C_CONTINUOUS')],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordFidelityDocumentView(document: document, pageWidth: 720),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 32));
      expect(tester.takeException(), isNull);

      final list = find.byKey(const ValueKey('word-fidelity-lazy-page-list'));
      final pageList = tester.widget<ListView>(list);
      expect(pageList.childrenDelegate.estimatedChildCount, 1);
      expect(find.textContaining('SECTION_A_COLUMN_1', findRichText: true), findsOneWidget);
      expect(find.textContaining('SECTION_B_COLUMN_2', findRichText: true), findsOneWidget);
      expect(find.textContaining('SECTION_C_CONTINUOUS', findRichText: true), findsOneWidget);
      expect(find.byKey(const ValueKey('word-column-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('word-column-1')), findsOneWidget);
    },
  );

  testWidgets(
    'VF4/VF6 parser keeps simplePos, paragraph shading, page-border spacing and VML dash style',
    (tester) async {
      final fixture = (await tester.runAsync<File>(_writeAdvancedFixture))!;
      addTearDown(
        () => tester.runAsync(() async {
          if (await fixture.parent.exists()) {
            await fixture.parent.delete(recursive: true);
          }
        }),
      );
      final document = (await tester.runAsync<ConversionDocument>(
        () => DocxConversionParser.parse(fixture),
      ))!;
      final section = document.sections.single;
      final paragraphs = section.blocks.whereType<ConversionParagraph>().toList();
      final shaded = paragraphs.first;
      expect(shaded.shadingHex, 'FFF2CC');
      expect(section.page.pageBorders.borders.top?.spacePoints, closeTo(18, 0.01));

      final inlines = paragraphs.expand((paragraph) => paragraph.inlines).toList();
      final image = inlines.whereType<ConversionImageRun>().single;
      expect(image.placement.horizontalRelativeFrom, 'page');
      expect(image.placement.verticalRelativeFrom, 'page');
      expect(image.placement.horizontalOffsetPoints, closeTo(10, 0.01));
      expect(image.placement.verticalOffsetPoints, closeTo(20, 0.01));
      expect(image.placement.isViewerPositioned, isTrue);

      final dashed = inlines.whereType<ConversionShapeRun>().single;
      expect(dashed.style.dashStyle?.toLowerCase(), contains('dash'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordFidelityDocumentView(document: document, pageWidth: 612),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }
      expect(find.byKey(const ValueKey('word-paragraph-shading')), findsOneWidget);
      expect(find.byKey(const ValueKey('word-page-border')), findsOneWidget);
      expect(find.byKey(const ValueKey('word-shape-visual')), findsWidgets);
    },
  );
}

Future<File> _writeAdvancedFixture() async {
  final directory = await Directory.systemTemp.createTemp('word-vfb-');
  final file = File(p.join(directory.path, 'advanced_fidelity.docx'));
  final png = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR4nGNkaPj/n4GBgYGJAQoAJRkCgp9o0gYAAAAASUVORK5CYII=',
    ),
  );

  const documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
 xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
 xmlns:v="urn:schemas-microsoft-com:vml">
 <w:body>
  <w:p>
   <w:pPr><w:shd w:fill="FFF2CC"/><w:pBdr><w:bottom w:val="double" w:sz="8" w:space="3" w:color="4472C4"/></w:pBdr></w:pPr>
   <w:r><w:t>Advanced shaded paragraph</w:t></w:r>
  </w:p>
  <w:p><w:r><w:drawing>
   <wp:anchor simplePos="1" relativeHeight="77" behindDoc="0" layoutInCell="1" allowOverlap="0" distT="12700" distB="12700" distL="12700" distR="12700">
    <wp:simplePos x="127000" y="254000"/>
    <wp:extent cx="1270000" cy="635000"/>
    <wp:wrapSquare wrapText="right"/>
    <wp:docPr id="1" name="simple-position-picture"/>
    <a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
     <pic:pic><pic:nvPicPr><pic:cNvPr id="1" name="photo.png"/><pic:cNvPicPr/></pic:nvPicPr>
      <pic:blipFill><a:blip r:embed="rIdPhoto"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
      <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="1270000" cy="635000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
     </pic:pic>
    </a:graphicData></a:graphic>
   </wp:anchor>
  </w:drawing></w:r></w:p>
  <w:p><w:r><w:pict>
   <v:rect id="dashShape" fillcolor="#EAF2F8" strokecolor="#2E75B6" strokeweight="1pt" style="width:120pt;height:36pt">
    <v:stroke dashstyle="dashDot"/>
   </v:rect>
  </w:pict></w:r></w:p>
  <w:sectPr>
   <w:pgSz w:w="12240" w:h="15840"/>
   <w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720" w:header="360" w:footer="360"/>
   <w:pgBorders w:offsetFrom="page"><w:top w:val="single" w:sz="12" w:space="18" w:color="2E75B6"/></w:pgBorders>
  </w:sectPr>
 </w:body>
</w:document>''';

  const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rIdPhoto" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/photo.png"/>
</Relationships>''';

  final archive = Archive()
    ..addFile(ArchiveFile.string('word/document.xml', documentXml))
    ..addFile(ArchiveFile.string('word/_rels/document.xml.rels', rels))
    ..addFile(ArchiveFile.bytes('word/media/photo.png', png));
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  return file;
}
