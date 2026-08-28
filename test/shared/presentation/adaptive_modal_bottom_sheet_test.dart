import 'package:edusheet/shared/presentation/widgets/adaptive_app_viewport.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('adaptive bottom sheet fills a narrow desktop window safely', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(366, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late double sheetWidth;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: AdaptiveAppViewport(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAdaptiveModalBottomSheet<void>(
                    context: context,
                    useSafeArea: true,
                    isScrollControlled: true,
                    builder: (context) => LayoutBuilder(
                      builder: (context, constraints) {
                        sheetWidth = constraints.maxWidth;
                        return const SizedBox(height: 240);
                      },
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(sheetWidth, 366);
    expect(tester.takeException(), isNull);
  });
}
