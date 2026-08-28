import 'package:edusheet/shared/presentation/widgets/adaptive_app_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the real width at normal compact sizes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late double laidOutWidth;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: AdaptiveAppViewport(
          child: LayoutBuilder(
            builder: (context, constraints) {
              laidOutWidth = constraints.maxWidth;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    expect(laidOutWidth, 360);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provides a 320px app canvas for ultra-narrow mobile viewports', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(180, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late double laidOutWidth;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: AdaptiveAppViewport(
          child: LayoutBuilder(
            builder: (context, constraints) {
              laidOutWidth = constraints.maxWidth;
              return Row(
                children: const [
                  SizedBox(width: 150, height: 40),
                  SizedBox(width: 150, height: 40),
                ],
              );
            },
          ),
        ),
      ),
    );

    expect(laidOutWidth, AdaptiveAppViewport.minimumContentWidth);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop free-form windows keep a stable 360x480 canvas', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(240, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late Size laidOutSize;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: AdaptiveAppViewport(
          child: LayoutBuilder(
            builder: (context, constraints) {
              laidOutSize = Size(constraints.maxWidth, constraints.maxHeight);
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    expect(
      laidOutSize,
      const Size(
        AdaptiveAppViewport.minimumDesktopContentWidth,
        AdaptiveAppViewport.minimumDesktopContentHeight,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
