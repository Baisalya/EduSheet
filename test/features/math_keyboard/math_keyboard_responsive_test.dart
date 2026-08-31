import 'package:edusheet/features/math_keyboard/domain/models/math_symbol.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keyboard layout matrix remains free of overflow', (
    tester,
  ) async {
    const cases = <({Size size, double scale})>[
      (size: Size(320, 520), scale: 1),
      (size: Size(360, 640), scale: 1.3),
      (size: Size(600, 800), scale: 1.5),
      (size: Size(1024, 768), scale: 2),
    ];
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final layoutCase in cases) {
      tester.view.physicalSize = layoutCase.size;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: layoutCase.size,
                textScaler: TextScaler.linear(layoutCase.scale),
              ),
              child: const Scaffold(body: MathKeyboardView()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const ValueKey('math-build-button')), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: '${layoutCase.size.width}px at ${layoutCase.scale}x text scale',
      );
    }
  });

  testWidgets('Recent category shows its real empty state', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(mathKeyboardControllerProvider.notifier);
    controller.clearRecentSymbols();
    controller.setCategory(MathCategory.recent);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: MathKeyboardView())),
      ),
    );

    expect(find.text('No recent math yet'), findsOneWidget);
    expect(find.text('Browse math keys'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide but vertically compact keyboard keeps teacher labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: MathKeyboardView())),
      ),
    );

    expect(find.text('Common'), findsOneWidget);
    expect(find.text('Algebra'), findsOneWidget);
    expect(find.text('Calculus'), findsOneWidget);
    expect(find.text('Science'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Space'), findsOneWidget);
    expect(find.text('Next box'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shapes opens inside the keyboard instead of another route', (
    tester,
  ) async {
    final container = ProviderContainer();
    final editor = QuillController.basic();
    final focusNode = FocusNode();
    final semantics = tester.ensureSemantics();
    addTearDown(container.dispose);
    addTearDown(editor.dispose);
    addTearDown(focusNode.dispose);

    container
        .read(mathKeyboardControllerProvider.notifier)
        .showMathKeyboardFor(editor, focusNode);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(height: 360, child: MathKeyboardView()),
          ),
        ),
      ),
    );

    await tester.tap(find.text('MORE'));
    await tester.pump(const Duration(milliseconds: 200));

    final categoryBrowser = find.byKey(const ValueKey('math-category-browser'));
    final format = find.text('FORMAT');
    await tester.dragUntilVisible(
      format,
      categoryBrowser,
      const Offset(0, -120),
    );
    await tester.tap(format);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Shapes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const ValueKey('math-shape-browser')), findsOneWidget);
    expect(find.bySemanticsLabel('Insert shape 1'), findsOneWidget);
    final keyboardContext = tester.element(find.byType(MathKeyboardView));
    expect(Navigator.of(keyboardContext).canPop(), isFalse);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
