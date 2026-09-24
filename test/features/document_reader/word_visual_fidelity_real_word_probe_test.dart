import 'package:edusheet/features/document_reader/presentation/widgets/viewers/word_fidelity_document_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/word_visual_fidelity_real_word_fixture.dart';

void main() {
  late WordVisualRealWordFixture fixture;

  setUpAll(() async {
    final stopwatch = Stopwatch()..start();
    fixture = await WordVisualRealWordFixture.load();
    stopwatch.stop();
    // ignore: avoid_print
    print('VF8 isolated real Word setup: ${stopwatch.elapsedMilliseconds} ms');
  });

  testWidgets(
    'VF8 isolated real Microsoft Word composite risk probe renders safely',
    (tester) async {
      final buildTimer = Stopwatch()..start();
      final probe = buildWordVisualRealWordRiskProbe(fixture.document);
      buildTimer.stop();
      // ignore: avoid_print
      print(
        'VF8 isolated probe build: ${buildTimer.elapsedMilliseconds} ms; '
        'blocks=${probe.blockCount}; ${probe.summary}',
      );

      expect(probe.blockCount, greaterThanOrEqualTo(2));
      expect(probe.hasProse, isTrue);
      expect(probe.hasTable, isTrue);
      expect(probe.hasVisualRisk, isTrue);

      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1050, 820));

      final renderTimer = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordFidelityDocumentView(
              document: probe.document,
              pageWidth: 612,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.takeException(),
        isNull,
        reason: 'isolated real Word probe first frame',
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.takeException(),
        isNull,
        reason: 'isolated real Word probe second frame',
      );
      renderTimer.stop();
      // ignore: avoid_print
      print(
        'VF8 isolated probe render: ${renderTimer.elapsedMilliseconds} ms',
      );

      final list = find.byKey(
        const ValueKey('word-fidelity-lazy-page-list'),
      );
      expect(list, findsOneWidget);
      final pages = tester
          .widget<ListView>(list)
          .childrenDelegate
          .estimatedChildCount;
      expect(pages, isNotNull);
      expect(pages!, greaterThanOrEqualTo(1));

      final page = find.byKey(const ValueKey('word-fidelity-page')).first;
      final pageSize = tester.getSize(page);
      expect(pageSize.width, closeTo(612, 0.5));
      expect(pageSize.height, greaterThan(0));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.takeException(), isNull, reason: 'dispose isolated probe');
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
