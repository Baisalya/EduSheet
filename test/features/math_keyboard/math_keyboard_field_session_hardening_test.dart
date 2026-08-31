import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'active math session survives FocusNode replacement during rebuild',
    (tester) async {
      final container = ProviderContainer();
      final firstController = TextEditingController(text: 'x');
      final secondController = TextEditingController(text: 'y');
      final firstFocus = FocusNode();
      final secondFocus = FocusNode();
      final externalFocus = FocusNode();
      final harnessKey = GlobalKey<_SessionHarnessState>();
      addTearDown(() {
        firstController.dispose();
        secondController.dispose();
        firstFocus.dispose();
        secondFocus.dispose();
        externalFocus.dispose();
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: _SessionHarness(
                key: harnessKey,
                firstController: firstController,
                secondController: secondController,
                firstFocus: firstFocus,
                secondFocus: secondFocus,
                externalFocus: externalFocus,
              ),
            ),
          ),
        ),
      );

      firstFocus.requestFocus();
      await tester.pump();
      container
          .read(mathKeyboardControllerProvider.notifier)
          .showMathKeyboardFor(firstController, firstFocus);
      await tester.pump();

      harnessKey.currentState!.replaceFocusNode();
      await tester.pump();
      await tester.pump();

      final state = container.read(mathKeyboardControllerProvider);
      expect(state.isVisible, isTrue);
      expect(state.type, KeyboardType.math);
      expect(identical(state.activeController, firstController), isTrue);
      expect(identical(state.activeFocusNode, secondFocus), isTrue);
      expect(secondFocus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'active math session transfers to replacement editor controller',
    (tester) async {
      final container = ProviderContainer();
      final firstController = TextEditingController(text: 'x');
      final secondController = TextEditingController(text: 'y');
      final focusNode = FocusNode();
      final unusedFocus = FocusNode();
      final externalFocus = FocusNode();
      final harnessKey = GlobalKey<_SessionHarnessState>();
      addTearDown(() {
        firstController.dispose();
        secondController.dispose();
        focusNode.dispose();
        unusedFocus.dispose();
        externalFocus.dispose();
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: _SessionHarness(
                key: harnessKey,
                firstController: firstController,
                secondController: secondController,
                firstFocus: focusNode,
                secondFocus: unusedFocus,
                externalFocus: externalFocus,
              ),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      container
          .read(mathKeyboardControllerProvider.notifier)
          .showMathKeyboardFor(firstController, focusNode);
      await tester.pump();

      harnessKey.currentState!.replaceController();
      await tester.pump();

      final state = container.read(mathKeyboardControllerProvider);
      expect(state.isVisible, isTrue);
      expect(state.type, KeyboardType.math);
      expect(identical(state.activeController, secondController), isTrue);
      expect(identical(state.activeFocusNode, focusNode), isTrue);
      expect(focusNode.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('moving to an external text field releases the math session', (
    tester,
  ) async {
    final container = ProviderContainer();
    final controller = TextEditingController(text: 'x');
    final secondController = TextEditingController(text: 'y');
    final focusNode = FocusNode();
    final unusedFocus = FocusNode();
    final externalFocus = FocusNode();
    final harnessKey = GlobalKey<_SessionHarnessState>();
    addTearDown(() {
      controller.dispose();
      secondController.dispose();
      focusNode.dispose();
      unusedFocus.dispose();
      externalFocus.dispose();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: _SessionHarness(
              key: harnessKey,
              firstController: controller,
              secondController: secondController,
              firstFocus: focusNode,
              secondFocus: unusedFocus,
              externalFocus: externalFocus,
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

    externalFocus.requestFocus();
    await tester.pump();
    await tester.pump();

    final state = container.read(mathKeyboardControllerProvider);
    expect(state.isVisible, isFalse);
    expect(state.activeController, isNull);
    expect(state.activeFocusNode, isNull);
    expect(externalFocus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _SessionHarness extends StatefulWidget {
  const _SessionHarness({
    super.key,
    required this.firstController,
    required this.secondController,
    required this.firstFocus,
    required this.secondFocus,
    required this.externalFocus,
  });

  final TextEditingController firstController;
  final TextEditingController secondController;
  final FocusNode firstFocus;
  final FocusNode secondFocus;
  final FocusNode externalFocus;

  @override
  State<_SessionHarness> createState() => _SessionHarnessState();
}

class _SessionHarnessState extends State<_SessionHarness> {
  bool _useSecondFocus = false;
  bool _useSecondController = false;

  void replaceFocusNode() => setState(() => _useSecondFocus = true);

  void replaceController() => setState(() => _useSecondController = true);

  @override
  Widget build(BuildContext context) {
    final controller = _useSecondController
        ? widget.secondController
        : widget.firstController;
    final focusNode = _useSecondFocus ? widget.secondFocus : widget.firstFocus;

    return Column(
      children: [
        MathKeyboardField(
          controller: controller,
          focusNode: focusNode,
          builder: (context, fieldFocusNode, isMathActive) => TextField(
            key: const ValueKey('math-session-editor'),
            controller: controller,
            focusNode: fieldFocusNode,
          ),
        ),
        TextField(
          key: const ValueKey('external-editor'),
          focusNode: widget.externalFocus,
        ),
      ],
    );
  }
}
