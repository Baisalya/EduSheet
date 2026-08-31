import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_view.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_keyboard/math_keyboard.dart';

void main() {
  testWidgets('existing formula opens visual editor before advanced source', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: _FormulaEditorTestApp(
          expression: MathExpression(
            id: 'existing',
            latex: r'\sqrt{1223^{1}}',
            plainText: 'square root of 1223 to the power 1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit math formula'), findsOneWidget);
    expect(find.byType(MathField), findsOneWidget);
    expect(find.text('Formula source'), findsNothing);
    expect(find.text('Readable description *'), findsNothing);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('Save formula'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('formula-placement-help')),
      findsOneWidget,
    );
    expect(
      find.text(
        'In sentence keeps the formula exactly where the question cursor was placed.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Tap the formula to choose where math should be typed.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();

    expect(find.text('Formula source'), findsOneWidget);
    expect(find.text('Accessibility description (optional)'), findsOneWidget);
  });

  testWidgets('formula placement helper follows the teacher selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: _FormulaEditorTestApp(
          expression: MathExpression(
            id: 'placement',
            latex: r'x=1',
            plainText: 'x equals 1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'In sentence keeps the formula exactly where the question cursor was placed.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Own line'));
    await tester.pump();

    expect(
      find.text(
        'Own line is best for a standalone equation or derivation step.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'teacher Build panel inserts a structure without pushing another route',
    (tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: _FormulaEditorTestApp(
            expression: MathExpression(
              id: 'build-session',
              latex: r'x+1',
              plainText: 'x plus 1',
            ),
            autoOpenMathKeyboard: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(const ValueKey('math-build-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey('math-structure-browser')),
        findsOneWidget,
      );
      expect(find.text('Build math faster'), findsOneWidget);
      expect(find.text('Fraction'), findsOneWidget);

      final keyboardContext = tester.element(find.byType(MathKeyboardView));
      expect(Navigator.of(keyboardContext).canPop(), isFalse);

      await tester.tap(find.text('Fraction'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey('math-structure-browser')),
        findsNothing,
      );
      expect(find.text('Next box'), findsOneWidget);
      _expectFormulaMathSession(tester, isVisible: true);

      final context = tester.element(find.byType(FormulaEditorSheet));
      final container = ProviderScope.containerOf(context, listen: false);
      expect(
        container.read(mathKeyboardControllerProvider).recentSymbols,
        contains(r'\frac{}{}'),
      );
    },
  );

  testWidgets('key actions stay local instead of opening a long-press modal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: _FormulaEditorTestApp(
          expression: MathExpression(
            id: 'actions-session',
            latex: r'x',
            plainText: 'x',
          ),
          autoOpenMathKeyboard: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final actionableKeys = find.byWidgetPredicate(
      (widget) =>
          widget is MathKey &&
          widget.symbol?.tex == r'\frac{}{}' &&
          widget.onLongPress != null,
    );
    expect(actionableKeys, findsWidgets);

    await tester.longPress(actionableKeys.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Key actions'), findsOneWidget);
    expect(find.text('Add to favourites'), findsOneWidget);

    await tester.tap(find.text('Add to favourites'));
    await tester.pump();
    expect(find.text('Remove from favourites'), findsOneWidget);

    final keyboardContext = tester.element(find.byType(MathKeyboardView));
    expect(Navigator.of(keyboardContext).canPop(), isFalse);
    _expectFormulaMathSession(tester, isVisible: true);

    await tester.tap(find.text('Back to keys'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Key actions'), findsNothing);
    _expectFormulaMathSession(tester, isVisible: true);
  });

  testWidgets(
    'teacher can switch to text keyboard and reopen math without losing formula ownership',
    (tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: _FormulaEditorTestApp(
            expression: MathExpression(
              id: 'reopen-session',
              latex: r'x+1',
              plainText: 'x plus 1',
            ),
            autoOpenMathKeyboard: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      _expectFormulaMathSession(tester, isVisible: true);
      await tester.tap(find.text('Text'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final context = tester.element(find.byType(FormulaEditorSheet));
      final container = ProviderScope.containerOf(context, listen: false);
      final systemState = container.read(mathKeyboardControllerProvider);
      expect(systemState.isVisible, isFalse);
      expect(systemState.type, KeyboardType.system);
      expect(systemState.activeController, isA<MathFieldEditingController>());
      expect(systemState.activeFocusNode, isNotNull);

      await tester.tap(find.byTooltip('Math Keyboard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      _expectFormulaMathSession(tester, isVisible: true);
      expect(
        find.text(
          'Typing here — the next math key goes at the visible formula cursor.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'formula math keyboard stays active through its local category panel',
    (tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: _FormulaEditorTestApp(
            expression: MathExpression(
              id: 'session',
              latex: r'x+1',
              plainText: 'x plus 1',
            ),
            autoOpenMathKeyboard: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      _expectFormulaMathSession(tester, isVisible: true);
      expect(
        find.text(
          'Typing here — the next math key goes at the visible formula cursor.',
        ),
        findsOneWidget,
      );
      expect(find.text('Next box'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);

      await tester.tap(find.text('MORE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('More math & science keys'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('math-category-browser')),
        findsOneWidget,
      );
      final keyboardContext = tester.element(find.byType(MathKeyboardView));
      expect(Navigator.of(keyboardContext).canPop(), isFalse);
      _expectFormulaMathSession(tester, isVisible: true);

      await tester.ensureVisible(find.text('TRIG'));
      await tester.tap(find.text('TRIG'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('More math & science keys'), findsNothing);
      _expectFormulaMathSession(tester, isVisible: true);

      await tester.ensureVisible(find.text('Advanced'));
      await tester.tap(find.text('Advanced'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.pump();

      // Moving to a real editor outside the custom keyboard is still a genuine
      // focus change and must release the visual math-keyboard session.
      _expectFormulaMathSession(tester, isVisible: false);
    },
  );

  testWidgets('formula editor disposal defers keyboard-owner cleanup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harnessKey = GlobalKey<_FormulaDisposeHarnessState>();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MathKeyboardWrapper(child: child!),
          home: _FormulaDisposeHarness(key: harnessKey),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final context = tester.element(find.byType(FormulaEditorSheet));
    final container = ProviderScope.containerOf(context, listen: false);
    expect(container.read(mathKeyboardControllerProvider).isVisible, isTrue);

    harnessKey.currentState!.removeEditor();
    await tester.pump();
    await tester.pump();

    final state = container.read(mathKeyboardControllerProvider);
    expect(state.isVisible, isFalse);
    expect(state.activeController, isNull);
    expect(state.activeFocusNode, isNull);
    expect(tester.takeException(), isNull);
  });
}

void _expectFormulaMathSession(WidgetTester tester, {required bool isVisible}) {
  final context = tester.element(find.byType(FormulaEditorSheet));
  final container = ProviderScope.containerOf(context, listen: false);
  final state = container.read(mathKeyboardControllerProvider);

  expect(state.isVisible, isVisible);
  if (isVisible) {
    expect(state.type, KeyboardType.math);
    expect(state.activeController, isA<MathFieldEditingController>());
    expect(state.activeFocusNode, isNotNull);
  } else {
    expect(state.activeController, isNull);
    expect(state.activeFocusNode, isNull);
  }
}

class _FormulaEditorTestApp extends StatelessWidget {
  const _FormulaEditorTestApp({
    required this.expression,
    this.autoOpenMathKeyboard = false,
  });

  final MathExpression expression;
  final bool autoOpenMathKeyboard;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => MathKeyboardWrapper(child: child!),
      home: Scaffold(
        body: FormulaEditorSheet(
          initial: expression,
          autoOpenMathKeyboard: autoOpenMathKeyboard,
        ),
      ),
    );
  }
}

class _FormulaDisposeHarness extends StatefulWidget {
  const _FormulaDisposeHarness({super.key});

  @override
  State<_FormulaDisposeHarness> createState() => _FormulaDisposeHarnessState();
}

class _FormulaDisposeHarnessState extends State<_FormulaDisposeHarness> {
  bool _showEditor = true;

  void removeEditor() => setState(() => _showEditor = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showEditor
          ? const FormulaEditorSheet(
              initial: MathExpression(
                id: 'dispose-session',
                latex: 'x',
                plainText: 'x',
              ),
              autoOpenMathKeyboard: true,
            )
          : const Center(child: Text('Editor removed')),
    );
  }
}
