import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/shortcuts/math_keyboard_productivity_shortcuts.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_field.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_view.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_keyboard/math_keyboard.dart';

void main() {
  testWidgets('shortcut help exposes explicit screen-reader semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: MathKeyboardView())),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('math-keyboard-shortcuts-button')),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const ValueKey('math-keyboard-shortcut-help')),
      findsOneWidget,
    );

    final toggleSemantics = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.label ?? '').startsWith(
            'Toggle math keyboard. Shortcut Ctrl+Shift+M.',
          ),
    );
    expect(toggleSemantics, findsOneWidget);

    final shortcutHelp = find.byKey(
      const ValueKey('math-keyboard-shortcut-help'),
    );
    final shortcutScroll = find.descendant(
      of: shortcutHelp,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Next formula box'),
      180,
      scrollable: shortcutScroll,
    );
    await tester.pump();

    final nextSlotSemantics = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.label ?? '').startsWith(
            'Next formula box. Shortcut Tab.',
          ),
    );
    expect(nextSlotSemantics, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category and controller status expose stable semantics', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: MathKeyboardView())),
      ),
    );

    final common = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Common math category',
    );
    expect(common, findsOneWidget);
    final commonSemantics = tester.widget<Semantics>(common);
    expect(commonSemantics.properties.selected, isTrue);
    expect(commonSemantics.properties.button, isTrue);
    expect(commonSemantics.properties.onTap, isNotNull);

    container
        .read(mathKeyboardControllerProvider.notifier)
        .requestPanel(MathKeyboardPanelRequest.shortcuts);
    await tester.pump();
    await tester.pump();

    final liveStatus = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.liveRegion == true &&
          widget.properties.label == 'Opening keyboard shortcuts.',
    );
    expect(liveStatus, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion removes the custom keyboard slide duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: MathKeyboardWrapper(child: child!),
          ),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );

    final slide = tester.widget<AnimatedSlide>(
      find.byKey(const ValueKey('math-keyboard-slide')),
    );
    expect(slide.duration, Duration.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('productivity commands act on the focused math field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    final mathController = MathFieldEditingController();
    final focusNode = FocusNode(debugLabel: 'phase11-shortcut-field');
    addTearDown(container.dispose);
    addTearDown(mathController.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MathKeyboardWrapper(child: child!),
          home: Scaffold(
            body: MathKeyboardField(
              controller: mathController,
              focusNode: focusNode,
              retainMathSessionOnFocusLoss: true,
              builder: (context, fieldFocusNode, isMathActive) => MathField(
                controller: mathController,
                focusNode: fieldFocusNode,
                opensKeyboard: !isMathActive,
              ),
            ),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    final controller = container.read(mathKeyboardControllerProvider.notifier);
    controller.showMathKeyboardFor(mathController, focusNode);
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      controller.handleProductivityCommand(
        MathKeyboardProductivityCommand.insertFraction,
      ),
      isTrue,
    );
    await tester.pump();

    expect(
      mathController.currentEditingValue(placeholderWhenEmpty: false),
      contains(r'\frac'),
    );
    expect(focusNode.hasFocus, isTrue);

    expect(
      controller.handleProductivityCommand(
        MathKeyboardProductivityCommand.search,
      ),
      isTrue,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Find math quickly'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('math-search-scrollable-layout')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
