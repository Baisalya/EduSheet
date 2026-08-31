import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_field.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_keyboard/math_keyboard.dart';

void main() {
  testWidgets(
    'windowed keyboard opens monotonically and ignores the departing native IME inset',
    (tester) async {
      tester.view.physicalSize = const Size(800, 440);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harnessKey = GlobalKey<_WindowInsetHarnessState>();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => MathKeyboardWrapper(child: child!),
            home: _WindowInsetHarness(key: harnessKey),
          ),
        ),
      );

      final overlay = find.byKey(const ValueKey('math-keyboard-overlay'));
      final openingTops = <double>[];
      final openingStates = <String>[];
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
        openingTops.add(tester.getTopLeft(overlay).dy);
        final editorContext = tester.element(find.byType(FormulaEditorSheet));
        final container = ProviderScope.containerOf(
          editorContext,
          listen: false,
        );
        final state = container.read(mathKeyboardControllerProvider);
        openingStates.add(
          '${state.isVisible}/${state.type}/${state.activeController.runtimeType}/${state.activeFocusNode?.hasFocus}',
        );
      }

      for (var index = 1; index < openingTops.length; index++) {
        expect(
          openingTops[index],
          lessThanOrEqualTo(openingTops[index - 1] + 0.01),
          reason:
              'The custom keyboard must move upward once, never bounce. '
              'tops=$openingTops states=$openingStates',
        );
      }

      await tester.pump(const Duration(milliseconds: 400));
      final expectedHeight = effectiveMathKeyboardHeight(
        const Size(800, 440),
        320,
      );
      expect(tester.getSize(overlay).height, closeTo(expectedHeight, 0.01));

      final editorMathInset = tester.widget<AnimatedPadding>(
        find.byKey(const ValueKey('formula-editor-math-inset')),
      );
      expect(
        (editorMathInset.padding as EdgeInsets).bottom,
        closeTo(expectedHeight, 0.01),
      );

      Padding systemInset() => tester.widget<Padding>(
        find.byKey(const ValueKey('formula-editor-system-inset')),
      );
      expect((systemInset().padding as EdgeInsets).bottom, 8);
      expect(
        find.byKey(const ValueKey('formula-editor-scrollable-layout')),
        findsOneWidget,
      );

      final settledOverlayTop = tester.getTopLeft(overlay).dy;
      harnessKey.currentState!.dismissNativeIme();
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect((systemInset().padding as EdgeInsets).bottom, 8);
        expect(tester.getTopLeft(overlay).dy, closeTo(settledOverlayTop, 0.01));
      }

      // The same ownership/inset rule applies on a phone-sized Android
      // viewport, including while a departing software keyboard still reports
      // a non-zero view inset.
      tester.view.physicalSize = const Size(360, 640);
      harnessKey.currentState!.showNativeIme(260);
      await tester.pump(const Duration(milliseconds: 400));
      final phoneHeight = effectiveMathKeyboardHeight(
        const Size(360, 640),
        320,
      );
      expect(tester.getSize(overlay).height, closeTo(phoneHeight, 0.01));
      expect((systemInset().padding as EdgeInsets).bottom, 8);
      expect(
        (tester
                    .widget<AnimatedPadding>(
                      find.byKey(const ValueKey('formula-editor-math-inset')),
                    )
                    .padding
                as EdgeInsets)
            .bottom,
        closeTo(phoneHeight, 0.01),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'physical letters numbers and operators edit the active structured formula',
    (tester) async {
      final container = ProviderContainer();
      final controller = MathFieldEditingController();
      final focusNode = FocusNode(debugLabel: 'hardware-math-test');
      addTearDown(container.dispose);
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: MathKeyboardField(
                controller: controller,
                focusNode: focusNode,
                retainMathSessionOnFocusLoss: true,
                builder: (context, fieldFocusNode, isMathActive) => MathField(
                  controller: controller,
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
      container
          .read(mathKeyboardControllerProvider.notifier)
          .showMathKeyboardFor(controller, focusNode);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pump();

      expect(
        controller.currentEditingValue(placeholderWhenEmpty: false),
        'a7+b',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(
        controller.currentEditingValue(placeholderWhenEmpty: false),
        'a7+',
      );
      expect(tester.takeException(), isNull);

      // Remove the global hardware handler before disposing its controller.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

class _WindowInsetHarness extends StatefulWidget {
  const _WindowInsetHarness({super.key});

  @override
  State<_WindowInsetHarness> createState() => _WindowInsetHarnessState();
}

class _WindowInsetHarnessState extends State<_WindowInsetHarness> {
  double _nativeImeInset = 180;

  void dismissNativeIme() => setState(() => _nativeImeInset = 0);

  void showNativeIme(double height) => setState(() => _nativeImeInset = height);

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(viewInsets: EdgeInsets.only(bottom: _nativeImeInset)),
      child: const Scaffold(
        body: FormulaEditorSheet(
          initial: MathExpression(
            id: 'windowed-flicker-regression',
            latex: 'x+1',
            plainText: 'x plus 1',
          ),
          autoOpenMathKeyboard: true,
        ),
      ),
    );
  }
}
