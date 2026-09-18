import 'package:edusheet/features/document_reader/presentation/responsive/presentation_stage_policy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PresentationStagePolicy', () {
    test('fits a 16:9 slide inside a portrait phone without cropping', () {
      final metrics = PresentationStagePolicy.contain(
        viewport: const Size(320, 720),
        aspectRatio: 16 / 9,
      );

      expect(metrics.slideSize.width, closeTo(320, 0.001));
      expect(metrics.slideSize.height, closeTo(180, 0.001));
      expect(metrics.letterbox.left, closeTo(0, 0.001));
      expect(metrics.letterbox.top, closeTo(270, 0.001));
    });

    test('fits a 16:9 slide inside a landscape window without stretching', () {
      final metrics = PresentationStagePolicy.contain(
        viewport: const Size(720, 320),
        aspectRatio: 16 / 9,
      );

      expect(metrics.slideSize.height, closeTo(320, 0.001));
      expect(metrics.slideSize.width, closeTo(568.888, 0.01));
      expect(
        metrics.slideSize.width / metrics.slideSize.height,
        closeTo(16 / 9, 0.0001),
      );
      expect(metrics.letterbox.left, closeTo(75.555, 0.01));
    });

    test('preserves a 4:3 deck ratio in a widescreen window', () {
      final metrics = PresentationStagePolicy.contain(
        viewport: const Size(1280, 800),
        aspectRatio: 4 / 3,
      );

      expect(metrics.slideSize.width, closeTo(1066.666, 0.01));
      expect(metrics.slideSize.height, closeTo(800, 0.001));
      expect(
        metrics.slideSize.width / metrics.slideSize.height,
        closeTo(4 / 3, 0.0001),
      );
    });

    test('falls back safely for an invalid aspect ratio', () {
      final metrics = PresentationStagePolicy.contain(
        viewport: const Size(1600, 900),
        aspectRatio: 0,
      );

      expect(metrics.slideSize, const Size(1600, 900));
    });
  });
}
