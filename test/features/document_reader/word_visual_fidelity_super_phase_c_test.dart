import 'dart:convert';
import 'dart:io';

import 'package:edusheet/features/document_reader/domain/services/word_visual_certification_snapshot.dart';
import 'package:edusheet/features/document_reader/domain/services/word_visual_compatibility_profile.dart';
import 'package:edusheet/features/document_reader/presentation/widgets/viewers/word_fidelity_document_view.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/word_visual_fidelity_real_word_fixture.dart';

void main() {
  late WordVisualRealWordFixture realWordFixture;

  setUpAll(() async {
    final stopwatch = Stopwatch()..start();
    realWordFixture = await WordVisualRealWordFixture.load();
    stopwatch.stop();
    // ignore: avoid_print
    print('VF8 real Word setup: ${stopwatch.elapsedMilliseconds} ms');
  });

  test('VF7 compatibility profiles cover the universal document corpus', () async {
    final manifest = jsonDecode(
      await File(
        'test/fixtures/word_visual_fidelity/certification_manifest.json',
      ).readAsString(),
    ) as Map<String, dynamic>;
    final requiredProfiles = (manifest['requiredProfiles'] as List<dynamic>)
        .cast<String>()
        .toSet();
    final corpus = _canonicalCorpus();
    final categories = <WordVisualCompatibilityCategory>{};

    for (final entry in corpus.entries) {
      final profile = WordVisualCompatibilityProfile.analyze(entry.value);
      categories.add(profile.category);
      expect(
        profile.signature.paragraphs,
        greaterThan(0),
        reason: entry.key,
      );
      expect(
        profile.paragraphFragmentTargetFraction,
        inInclusiveRange(0.30, 0.60),
        reason: entry.key,
      );
      expect(
        profile.tableContinuationTargetFraction,
        inInclusiveRange(0.35, 0.60),
        reason: entry.key,
      );
    }

    expect(
      categories,
      containsAll(WordVisualCompatibilityCategory.values),
    );
    expect(
      categories.map((category) => category.name).toSet(),
      equals(requiredProfiles),
    );
  });

  test('VF8 certification snapshots are deterministic and category-sensitive', () {
    final corpus = _canonicalCorpus();
    final fingerprints = <String>{};

    for (final entry in corpus.entries) {
      final first = WordVisualCertificationSnapshot.fromDocument(entry.value);
      final second = WordVisualCertificationSnapshot.fromDocument(entry.value);
      expect(first.profileId, second.profileId, reason: entry.key);
      expect(
        first.structuralFingerprint,
        second.structuralFingerprint,
        reason: entry.key,
      );
      expect(first.structuralFingerprint, hasLength(16), reason: entry.key);
      expect(first.pageGeometry, isNotEmpty, reason: entry.key);
      fingerprints.add(first.structuralFingerprint);
    }

    expect(fingerprints.length, corpus.length);
  });

  testWidgets(
    'VF8 universal corpus renders bounded Word pages without runtime exceptions',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1050, 820));

      for (final entry in _canonicalCorpus().entries) {
        final sourceWidth = entry.value.sections.first.page.widthPoints;
        final sourceHeight = entry.value.sections.first.page.heightPoints;
        const targetWidth = 612.0;
        final expectedHeight = targetWidth / sourceWidth * sourceHeight;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WordFidelityDocumentView(
                document: entry.value,
                pageWidth: targetWidth,
              ),
            ),
          ),
        );
        for (var frame = 0; frame < 4; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull, reason: entry.key);
        }

        final list = find.byKey(const ValueKey('word-fidelity-lazy-page-list'));
        expect(list, findsOneWidget, reason: entry.key);
        final pages = tester.widget<ListView>(list).childrenDelegate.estimatedChildCount;
        expect(pages, isNotNull, reason: entry.key);
        expect(pages!, greaterThanOrEqualTo(1), reason: entry.key);

        final page = find.byKey(const ValueKey('word-fidelity-page')).first;
        final size = tester.getSize(page);
        expect(size.width, closeTo(targetWidth, 0.5), reason: entry.key);
        expect(size.height, closeTo(expectedHeight, 0.5), reason: entry.key);

        await tester.drag(list, const Offset(0, -420));
        await tester.pump(const Duration(milliseconds: 24));
        expect(tester.takeException(), isNull, reason: entry.key);
      }
    },
  );

  test(
    'VF8 real Microsoft Word corpus produces a stable full-document certification snapshot',
    () {
      expect(realWordFixture.file.existsSync(), isTrue);
      expect(
        realWordFixture.actualSha256,
        realWordFixture.reference['sourceSha256'] as String,
      );
      expect(
        realWordFixture.producerMetadata,
        contains(realWordFixture.reference['producer'] as String),
      );

      final snapshot = WordVisualCertificationSnapshot.fromDocument(
        realWordFixture.document,
      );
      expect(snapshot.sectionCount, greaterThan(0));
      expect(
        snapshot.signature.tables,
        greaterThanOrEqualTo(
          realWordFixture.reference['minimumTables'] as int,
        ),
      );
      expect(
        snapshot.signature.images,
        greaterThanOrEqualTo(
          realWordFixture.reference['minimumImages'] as int,
        ),
      );
      expect(snapshot.structuralFingerprint, hasLength(16));
      expect(snapshot.pageGeometry, isNotEmpty);
    },
  );

  test('VF8 real Microsoft Word risk probe stays bounded and representative', () {
    final probe = buildWordVisualRealWordRiskProbe(realWordFixture.document);
    expect(probe.blockCount, inInclusiveRange(2, 3));
    expect(probe.document.sections.length, inInclusiveRange(1, 3));
    expect(probe.hasProse, isTrue);
    expect(probe.hasTable, isTrue);
    expect(probe.hasVisualRisk, isTrue);
  });



}

Map<String, ConversionDocument> _canonicalCorpus() => <String, ConversionDocument>{
      'resume': _resumeDocument(),
      'invoice': _invoiceDocument(),
      'report': _reportDocument(),
      'floating': _floatingDocument(),
      'editorial': _multiColumnDocument(),
      'academic': _academicDocument(),
      'multilingual': _multilingualDocument(),
    };

ConversionPageSettings get _page => const ConversionPageSettings(
      widthPoints: 612,
      heightPoints: 792,
      marginTopPoints: 54,
      marginRightPoints: 54,
      marginBottomPoints: 54,
      marginLeftPoints: 54,
    );

ConversionParagraph _p(
  String text, {
  bool decorated = false,
  double after = 4,
}) =>
    ConversionParagraph(
      spaceAfterPoints: after,
      shadingHex: decorated ? 'F2F2F2' : null,
      borders: decorated
          ? const ConversionBorders(
              bottom: ConversionBorderSide(
                style: ConversionBorderStyle.single,
                widthPoints: 0.75,
                colorHex: '808080',
              ),
            )
          : const ConversionBorders(),
      inlines: <ConversionInline>[
        ConversionTextRun(
          text: text,
          style: const ConversionTextStyle(fontSizePoints: 10.5),
        ),
      ],
    );

ConversionDocument _resumeDocument() {
  final left = List<ConversionBlock>.generate(
    6,
    (i) => _p('PROFILE ITEM $i'),
  );
  final right = List<ConversionBlock>.generate(
    7,
    (i) => _p('PROJECT OR EXPERIENCE $i'),
  );
  return ConversionDocument(
    sections: <ConversionSection>[
      ConversionSection(
        page: _page,
        blocks: <ConversionBlock>[
          ConversionTable(
            layout: ConversionTableLayout.fixed,
            widthPoints: 504,
            gridColumnWidths: const <double>[170, 334],
            rows: <ConversionTableRow>[
              ConversionTableRow(
                cells: <ConversionTableCell>[
                  ConversionTableCell(blocks: left, widthPoints: 170),
                  ConversionTableCell(blocks: right, widthPoints: 334),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

ConversionDocument _invoiceDocument() => ConversionDocument(
      sections: <ConversionSection>[
        ConversionSection(
          page: _page,
          blocks: <ConversionBlock>[
            _p('INVOICE', decorated: true),
            for (var table = 0; table < 2; table++)
              ConversionTable(
                showBorders: true,
                rows: <ConversionTableRow>[
                  for (var row = 0; row < 3; row++)
                    ConversionTableRow(
                      cells: <ConversionTableCell>[
                        ConversionTableCell(
                          blocks: <ConversionBlock>[
                            _p('Item ${table + 1}.$row', decorated: true),
                          ],
                        ),
                        ConversionTableCell(
                          blocks: <ConversionBlock>[_p('₹${(row + 1) * 125}')],
                        ),
                      ],
                    ),
                ],
              ),
          ],
        ),
      ],
    );

ConversionDocument _reportDocument() => ConversionDocument(
      sections: <ConversionSection>[
        ConversionSection(
          page: _page,
          blocks: <ConversionBlock>[
            for (var i = 0; i < 7; i++)
              _p(
                'Section $i explains a professional report in continuous prose. '
                'The paragraph is intentionally long enough to exercise ordinary '
                'Word line wrapping, pagination and justified report-style flow '
                'without being classified as a short resume or form paragraph.',
                after: 8,
              ),
          ],
        ),
      ],
    );

ConversionDocument _floatingDocument() => ConversionDocument(
      sections: <ConversionSection>[
        ConversionSection(
          page: _page,
          blocks: <ConversionBlock>[
            ConversionParagraph(
              inlines: <ConversionInline>[
                const ConversionTextRun(
                  text: 'Marketing brochure body wraps around anchored objects.',
                ),
                for (var i = 0; i < 4; i++)
                  ConversionShapeRun(
                    kind: ConversionShapeKind.rectangle,
                    widthPoints: 72,
                    heightPoints: 42,
                    style: const ConversionShapeStyle(
                      fillColorHex: 'D9EAF7',
                      strokeColorHex: '2E75B6',
                    ),
                    placement: ConversionObjectPlacement.floating(
                      horizontalRelativeFrom: 'column',
                      verticalRelativeFrom: 'paragraph',
                      horizontalOffsetPoints: i * 78.0,
                      verticalOffsetPoints: i * 48.0,
                      wrapStyle: 'wrapSquare',
                      wrapText: 'bothSides',
                      relativeHeight: 10 + i,
                    ),
                  ),
              ],
            ),
            _p('Follow-up brochure text remains in normal document flow.'),
          ],
        ),
      ],
    );

ConversionDocument _multiColumnDocument() => ConversionDocument(
      sections: <ConversionSection>[
        ConversionSection(
          page: _page,
          columns: const ConversionColumns(count: 2, spacingPoints: 24),
          blocks: <ConversionBlock>[
            for (var i = 0; i < 8; i++)
              _p(
                'Editorial column paragraph $i contains enough words to exercise '
                'multi-column flow and balanced professional page geometry.',
              ),
          ],
        ),
      ],
    );

ConversionDocument _academicDocument() => ConversionDocument(
      sections: <ConversionSection>[
        ConversionSection(
          page: _page,
          blocks: <ConversionBlock>[
            const ConversionParagraph(
              inlines: <ConversionInline>[
                ConversionTextRun(text: 'Equation one: '),
                ConversionMathRun(
                  ommlXml: '<m:oMath><m:r><m:t>x²+y²</m:t></m:r></m:oMath>',
                  plainText: 'x² + y² = z²',
                ),
              ],
            ),
            const ConversionParagraph(
              inlines: <ConversionInline>[
                ConversionTextRun(text: 'Equation two: '),
                ConversionMathRun(
                  ommlXml: '<m:oMath><m:r><m:t>E=mc²</m:t></m:r></m:oMath>',
                  plainText: 'E = mc²',
                ),
              ],
            ),
            _p('Technical explanation and references continue below equations.'),
          ],
        ),
      ],
    );

ConversionDocument _multilingualDocument() => ConversionDocument(
      sections: <ConversionSection>[
        ConversionSection(
          page: _page,
          blocks: <ConversionBlock>[
            _p(
              'English classroom guidance with हिन्दी शिक्षा सामग्री और '
              'ଓଡ଼ିଆ ଶିକ୍ଷା ବିଷୟବସ୍ତୁ for mixed-script rendering validation.',
            ),
            _p(
              'Teacher notes continue in English जबकि विद्यार्थी सामग्री '
              'ବହୁଭାଷୀ ଭାବରେ ପ୍ରଦର୍ଶିତ ହୁଏ.',
            ),
          ],
        ),
      ],
    );

