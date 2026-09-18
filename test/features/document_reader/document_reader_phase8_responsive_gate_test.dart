import 'dart:io';

import 'package:edusheet/features/document_reader/data/services/presentation_parser_service.dart';
import 'package:edusheet/features/document_reader/domain/models/document_model.dart';
import 'package:edusheet/features/document_reader/domain/models/presentation_model.dart';
import 'package:edusheet/features/document_reader/presentation/responsive/document_viewport_policy.dart';
import 'package:edusheet/features/document_reader/presentation/responsive/presentation_stage_policy.dart';
import 'package:edusheet/features/document_reader/presentation/screens/file_preview_screen.dart';
import 'package:edusheet/features/document_reader/presentation/widgets/viewers/presentation_document_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 8 document viewport release contract', () {
    test('Word fit-width remains inside every production viewport', () {
      const cases = <({double width, double height, double expectedFitWidth})>[
        (width: 320, height: 720, expectedFitWidth: 304),
        (width: 360, height: 800, expectedFitWidth: 344),
        (width: 390, height: 844, expectedFitWidth: 374),
        (width: 600, height: 700, expectedFitWidth: 568),
        (width: 899, height: 700, expectedFitWidth: 860),
      ];

      for (final entry in cases) {
        final policy = DocumentViewportPolicy(
          width: entry.width,
          height: entry.height,
        );
        expect(policy.preferWordFitWidth, isTrue);
        expect(policy.wordFitWidthPageWidth, entry.expectedFitWidth);
        expect(
          policy.wordFitWidthPageWidth + (policy.wordHorizontalGutter * 2),
          lessThanOrEqualTo(entry.width),
        );
        expect(policy.documentToolbarHeight, greaterThanOrEqualTo(48));
      }
    });

    test('desktop Word defaults remain bounded and print-oriented', () {
      for (final width in const [900.0, 1024.0, 1280.0, 1600.0]) {
        final policy = DocumentViewportPolicy(width: width, height: 800);
        expect(policy.preferWordFitWidth, isFalse);
        expect(policy.wordPrintLayoutPageWidth, lessThanOrEqualTo(width));
        expect(policy.wordPrintLayoutPageWidth, lessThanOrEqualTo(794));
      }
    });

    test('PPT stage contains 16:9 slides without crop or stretch', () {
      const viewports = <Size>[
        Size(320, 720),
        Size(360, 800),
        Size(390, 844),
        Size(600, 700),
        Size(720, 540),
        Size(1280, 800),
      ];

      for (final viewport in viewports) {
        final metrics = PresentationStagePolicy.contain(
          viewport: viewport,
          aspectRatio: 16 / 9,
        );
        expect(metrics.slideSize.width, lessThanOrEqualTo(viewport.width));
        expect(metrics.slideSize.height, lessThanOrEqualTo(viewport.height));
        expect(
          metrics.slideSize.width / metrics.slideSize.height,
          closeTo(16 / 9, 0.0001),
        );
        final rect = metrics.centeredRect(viewport);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(viewport.width));
        expect(rect.bottom, lessThanOrEqualTo(viewport.height));
      }
    });
  });

  testWidgets(
    'capability strip uses local allocation inside a narrow nested pane',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final document = _document(
        'A very long legacy presentation filename that must never overflow.ppt',
        '.ppt',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              height: 720,
              child: FilePreviewScreen(document: document),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('External Office viewer recommended'), findsWidgets);
      // The description remains in the unsupported-viewer card, but compact
      // capability chrome must not render a second copy above it.
      expect(
        find.text(
          'This legacy/OpenDocument format is recognized, but the current authorized renderer cannot reproduce it faithfully in-app.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PPT preview and Present mode stay overflow-safe across release viewports',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final document = _document(
        'A deliberately long classroom presentation title for responsive regression.pptx',
        '.pptx',
      );
      final parser = _Phase8PresentationParser();
      const viewports = <Size>[
        Size(320, 720),
        Size(360, 800),
        Size(390, 844),
        Size(600, 700),
        Size(720, 540),
        Size(1280, 800),
      ];

      for (final size in viewports) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PresentationDocumentViewer(
                key: ValueKey(
                  'phase8-ppt-${size.width.toInt()}x${size.height.toInt()}',
                ),
                document: document,
                parserService: parser,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byKey(const ValueKey('slide-1')),
            matching: find.text('Phase 8 title'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: 'Preview overflow at $size');

        final presentLabel = size.width < 650 ? 'Play' : 'Present';
        await tester.tap(find.text(presentLabel).last);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('presentation-mode-stage')), findsOneWidget);
        expect(
          find.byKey(const Key('presentation-mode-controls')),
          findsOneWidget,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'Present chrome overflow at $size',
        );

        await tester.tap(find.byTooltip('Slide overview'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('presentation-slide-overview')),
          findsOneWidget,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'Slide overview overflow at $size',
        );

        await tester.tap(
          find.byKey(const ValueKey('presentation-overview-slide-1')),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('present-2')),
            matching: find.text('Phase 8 second slide'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.byTooltip('Exit presentation'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('presentation-mode-stage')), findsNothing);
        // Exiting Present mode intentionally keeps the slide selected in the
        // normal viewer. This assertion protects that UX while each viewport
        // case gets a fresh keyed viewer State on the next loop iteration.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('slide-2')),
            matching: find.text('Phase 8 second slide'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}

DocumentFile _document(String name, String extension) {
  return DocumentFile(
    name: name,
    path: 'C:/Documents/$name',
    extension: extension,
    size: 1024,
    lastModified: DateTime(2026, 9, 17),
    type: DocumentFile.getDocumentType(extension),
  );
}

class _Phase8PresentationParser extends PresentationParserService {
  @override
  Future<PresentationDocument> load(File file) async {
    return const PresentationDocument(
      slideWidth: 1600,
      slideHeight: 900,
      slides: [
        PresentationSlide(
          number: 1,
          hasNativeAnimations: true,
          transition: PresentationTransition(
            kind: PresentationTransitionKind.fade,
          ),
          animations: [
            PresentationAnimationStep(
              targetObjectId: '2',
              kind: PresentationAnimationKind.fadeIn,
              trigger: PresentationAnimationTrigger.onClick,
              duration: Duration(milliseconds: 80),
            ),
          ],
          elements: [
            PresentationElement(
              type: PresentationElementType.text,
              objectId: '2',
              left: 0.08,
              top: 0.1,
              width: 0.84,
              height: 0.22,
              hasBounds: true,
              text: 'Phase 8 title',
              fontSizePoints: 34,
              bold: true,
            ),
          ],
        ),
        PresentationSlide(
          number: 2,
          elements: [
            PresentationElement(
              type: PresentationElementType.text,
              objectId: '3',
              left: 0.1,
              top: 0.3,
              width: 0.8,
              height: 0.2,
              hasBounds: true,
              text: 'Phase 8 second slide',
              fontSizePoints: 28,
            ),
          ],
        ),
      ],
    );
  }
}
