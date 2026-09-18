import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/calculator_input_command.dart';
import '../../domain/models/calculator_mode.dart';
import '../layout/calculator_layout_spec.dart';
import '../providers/calculator_provider.dart';
import '../services/calculator_keyboard_mapper.dart';
import 'calculator_button.dart';
import 'calculator_display.dart';

class ScientificCalculator extends ConsumerStatefulWidget {
  const ScientificCalculator({super.key});

  @override
  ConsumerState<ScientificCalculator> createState() =>
      _ScientificCalculatorState();
}

class _ScientificCalculatorState extends ConsumerState<ScientificCalculator> {
  static const _keyboardMapper = CalculatorKeyboardMapper();

  late final FocusNode _keyboardFocus;
  late final FocusNode _expressionFocus;

  @override
  void initState() {
    super.initState();
    _keyboardFocus = FocusNode(debugLabel: 'scientific-calculator-keyboard');
    _expressionFocus = FocusNode(
      debugLabel: 'scientific-calculator-expression',
    );
  }

  @override
  void dispose() {
    _expressionFocus.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calculatorProvider);
    final controller = ref.read(calculatorProvider.notifier);

    return Focus(
      focusNode: _keyboardFocus,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (_) => _expressionFocus.requestFocus(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = CalculatorLayoutSpec.resolve(constraints);
            final padding = EdgeInsets.fromLTRB(
              layout.horizontalPadding,
              layout.topPadding,
              layout.horizontalPadding,
              layout.bottomPadding,
            );

            final display = CalculatorDisplay(
              editingValue: state.editingValue,
              result: state.result,
              previewResult: state.previewResult,
              errorMessage: state.errorMessage,
              isShift: state.isShift,
              isHyp: state.isHyp,
              angleUnit: state.angleUnit,
              expressionFocusNode: _expressionFocus,
              compact: layout.compactDisplay,
              onSelectionChanged: (selection) => controller.setSelection(
                selection.baseOffset,
                selection.extentOffset,
              ),
            );

            final modeStrip = _ModeStrip(
              state: state,
              controller: controller,
              layout: layout,
            );
            final keypad = _KeypadArea(
              state: state,
              controller: controller,
              layout: layout,
            );

            if (layout.scrollBody) {
              return SingleChildScrollView(
                key: ValueKey(layout.debugKey),
                padding: padding,
                physics: const ClampingScrollPhysics(),
                child: Column(
                  children: [
                    display,
                    SizedBox(height: layout.displayToModeGap),
                    modeStrip,
                    SizedBox(height: layout.modeToKeypadGap),
                    SizedBox(height: layout.scrollKeypadHeight, child: keypad),
                  ],
                ),
              );
            }

            return Padding(
              key: ValueKey(layout.debugKey),
              padding: padding,
              child: Column(
                children: [
                  display,
                  SizedBox(height: layout.displayToModeGap),
                  modeStrip,
                  SizedBox(height: layout.modeToKeypadGap),
                  Expanded(child: keypad),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;

    final keyboard = HardwareKeyboard.instance;
    final command = _keyboardMapper.map(
      key: event.logicalKey,
      character: event.character,
      shiftPressed: keyboard.isShiftPressed,
      controlPressed: keyboard.isControlPressed,
      metaPressed: keyboard.isMetaPressed,
    );
    if (command == null) return KeyEventResult.ignored;

    ref.read(calculatorProvider.notifier).dispatch(command);
    return KeyEventResult.handled;
  }
}

class _KeypadArea extends StatelessWidget {
  final CalculatorState state;
  final CalculatorController controller;
  final CalculatorLayoutSpec layout;

  const _KeypadArea({
    required this.state,
    required this.controller,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    if (layout.splitKeypad) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: _ScientificKeypad(
              state: state,
              controller: controller,
              density: layout.controlDensity,
            ),
          ),
          SizedBox(width: layout.keypadGap),
          Expanded(
            flex: 4,
            child: _MainKeypad(
              controller: controller,
              density: layout.controlDensity,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _ScientificKeypad(
            state: state,
            controller: controller,
            density: layout.controlDensity,
          ),
        ),
        SizedBox(height: layout.keypadGap),
        Expanded(
          flex: 4,
          child: _MainKeypad(
            controller: controller,
            density: layout.controlDensity,
          ),
        ),
      ],
    );
  }
}

class _ModeStrip extends StatelessWidget {
  final CalculatorState state;
  final CalculatorController controller;
  final CalculatorLayoutSpec layout;

  const _ModeStrip({
    required this.state,
    required this.controller,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: layout.modeStripHeight,
      child: Row(
        children: [
          _ModeButton(
            width: layout.modeButtonWidth,
            label: 'SHIFT',
            selected: state.isShift,
            activeColor: const Color(0xFFF59E0B),
            onTap: () =>
                controller.dispatch(CalculatorInputCommand.toggleShift),
          ),
          _ModeButton(
            width: layout.modeButtonWidth,
            label: 'HYP',
            selected: state.isHyp,
            activeColor: const Color(0xFF7C3AED),
            onTap: () => controller.dispatch(CalculatorInputCommand.toggleHyp),
          ),
          _ModeButton(
            width: layout.modeButtonWidth,
            label: state.angleUnit == AngleUnit.degrees ? 'DEG' : 'RAD',
            selected: state.angleUnit == AngleUnit.degrees,
            activeColor: const Color(0xFF059669),
            onTap: () =>
                controller.dispatch(CalculatorInputCommand.toggleAngleUnit),
          ),
          if (layout.showModeStatus)
            Expanded(
              child: Container(
                height: double.infinity,
                alignment: Alignment.centerRight,
                padding: EdgeInsets.symmetric(
                  horizontal:
                      layout.controlDensity == CalculatorControlDensity.dense
                      ? 8
                      : 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text(
                  state.isShift
                      ? 'Inverse functions active'
                      : state.isHyp
                      ? 'Hyperbolic functions active'
                      : 'Keyboard + touch ready',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize:
                        layout.controlDensity == CalculatorControlDensity.dense
                        ? 10
                        : 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final double width;
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ModeButton({
    required this.width,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: Material(
          color: selected ? activeColor : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(9),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScientificKeypad extends StatelessWidget {
  final CalculatorState state;
  final CalculatorController controller;
  final CalculatorControlDensity density;

  const _ScientificKeypad({
    required this.state,
    required this.controller,
    required this.density,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _KeyColors(Theme.of(context));
    return Column(
      children: [
        _row([
          _functionButton(
            state.isHyp ? 'sinh' : (state.isShift ? 'sin⁻¹' : 'sin'),
            secondary: state.isHyp || state.isShift ? null : 'sin⁻¹',
            background: colors.function,
            onTap: () => controller.dispatch(
              const CalculatorInputCommand.insertToken('sin('),
            ),
          ),
          _functionButton(
            state.isHyp ? 'cosh' : (state.isShift ? 'cos⁻¹' : 'cos'),
            secondary: state.isHyp || state.isShift ? null : 'cos⁻¹',
            background: colors.function,
            onTap: () => controller.dispatch(
              const CalculatorInputCommand.insertToken('cos('),
            ),
          ),
          _functionButton(
            state.isHyp ? 'tanh' : (state.isShift ? 'tan⁻¹' : 'tan'),
            secondary: state.isHyp || state.isShift ? null : 'tan⁻¹',
            background: colors.function,
            onTap: () => controller.dispatch(
              const CalculatorInputCommand.insertToken('tan('),
            ),
          ),
          _functionButton(
            state.isShift ? '10ˣ' : 'log',
            secondary: state.isShift ? null : '10ˣ',
            background: colors.function,
            onTap: () => controller.dispatch(
              const CalculatorInputCommand.insertToken('log('),
            ),
          ),
          _functionButton(
            state.isShift ? 'eˣ' : 'ln',
            secondary: state.isShift ? null : 'eˣ',
            background: colors.function,
            onTap: () => controller.dispatch(
              const CalculatorInputCommand.insertToken('ln('),
            ),
          ),
        ]),
        _row([
          _functionButton(
            state.isShift ? '∛x' : '√x',
            secondary: state.isShift ? null : '∛x',
            background: colors.function,
            onTap: () => controller.dispatch(
              const CalculatorInputCommand.insertToken('sqrt('),
            ),
          ),
          _functionButton(
            state.isShift ? 'x³' : 'x²',
            secondary: state.isShift ? null : 'x³',
            background: colors.function,
            onTap: () => controller.dispatch(
              const CalculatorInputCommand.insertToken('^2'),
            ),
          ),
          _functionButton(
            state.isShift ? 'x⁻¹' : 'xʸ',
            secondary: state.isShift ? null : 'x⁻¹',
            background: colors.function,
            onTap: () => controller.dispatch(
              const CalculatorInputCommand.insertToken('^'),
            ),
          ),
          _functionButton(
            state.isShift ? 'nPr' : 'nCr',
            secondary: state.isShift ? null : 'nPr',
            background: colors.function,
            onTap: () => controller.dispatch(
              const CalculatorInputCommand.insertToken('C'),
            ),
          ),
          _functionButton(
            'x!',
            background: colors.function,
            onTap: () => controller.dispatch(
              const CalculatorInputCommand.insertToken('!'),
            ),
          ),
        ]),
        _row([
          _functionButton(
            'π',
            background: colors.constant,
            onTap: () => controller.dispatch(
              const CalculatorInputCommand.insertToken('π'),
            ),
          ),
          _functionButton(
            'e',
            background: colors.constant,
            onTap: () => controller.dispatch(
              const CalculatorInputCommand.insertToken('e'),
            ),
          ),
          _functionButton(
            'Ans',
            background: colors.constant,
            onTap: () => controller.dispatch(
              const CalculatorInputCommand.insertToken('Ans'),
            ),
          ),
          _functionButton(
            '(',
            background: colors.neutral,
            onTap: () => controller.dispatch(
              const CalculatorInputCommand.insertToken('('),
            ),
          ),
          _functionButton(
            ')',
            background: colors.neutral,
            onTap: () => controller.dispatch(
              const CalculatorInputCommand.insertToken(')'),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _row(List<Widget> children) =>
      Expanded(child: Row(children: children));

  Widget _functionButton(
    String label, {
    String? secondary,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: CalculatorButton(
        label: label,
        secondaryLabel: secondary,
        bgColor: background,
        labelSize: 15,
        density: density,
        onTap: onTap,
      ),
    );
  }
}

class _MainKeypad extends StatelessWidget {
  final CalculatorController controller;
  final CalculatorControlDensity density;

  const _MainKeypad({required this.controller, required this.density});

  @override
  Widget build(BuildContext context) {
    final colors = _KeyColors(Theme.of(context));
    return Column(
      children: [
        _row([
          _button(
            '7',
            colors.number,
            () => controller.dispatch(
              const CalculatorInputCommand.insertToken('7'),
            ),
          ),
          _button(
            '8',
            colors.number,
            () => controller.dispatch(
              const CalculatorInputCommand.insertToken('8'),
            ),
          ),
          _button(
            '9',
            colors.number,
            () => controller.dispatch(
              const CalculatorInputCommand.insertToken('9'),
            ),
          ),
          _button(
            'DEL',
            colors.danger,
            () => controller.dispatch(CalculatorInputCommand.deleteBackward),
            foreground: Colors.white,
          ),
          _button(
            'AC',
            colors.danger,
            () => controller.dispatch(CalculatorInputCommand.clear),
            foreground: Colors.white,
          ),
        ]),
        _row([
          _button(
            '4',
            colors.number,
            () => controller.dispatch(
              const CalculatorInputCommand.insertToken('4'),
            ),
          ),
          _button(
            '5',
            colors.number,
            () => controller.dispatch(
              const CalculatorInputCommand.insertToken('5'),
            ),
          ),
          _button(
            '6',
            colors.number,
            () => controller.dispatch(
              const CalculatorInputCommand.insertToken('6'),
            ),
          ),
          _button(
            '×',
            colors.operator,
            () => controller.dispatch(
              const CalculatorInputCommand.insertToken('×'),
            ),
            foreground: Colors.white,
          ),
          _button(
            '÷',
            colors.operator,
            () => controller.dispatch(
              const CalculatorInputCommand.insertToken('÷'),
            ),
            foreground: Colors.white,
          ),
        ]),
        _row([
          _button(
            '1',
            colors.number,
            () => controller.dispatch(
              const CalculatorInputCommand.insertToken('1'),
            ),
          ),
          _button(
            '2',
            colors.number,
            () => controller.dispatch(
              const CalculatorInputCommand.insertToken('2'),
            ),
          ),
          _button(
            '3',
            colors.number,
            () => controller.dispatch(
              const CalculatorInputCommand.insertToken('3'),
            ),
          ),
          _button(
            '+',
            colors.operator,
            () => controller.dispatch(
              const CalculatorInputCommand.insertToken('+'),
            ),
            foreground: Colors.white,
          ),
          _button(
            '-',
            colors.operator,
            () => controller.dispatch(
              const CalculatorInputCommand.insertToken('-'),
            ),
            foreground: Colors.white,
          ),
        ]),
        _row([
          _button(
            '0',
            colors.number,
            () => controller.dispatch(
              const CalculatorInputCommand.insertToken('0'),
            ),
          ),
          _button(
            '.',
            colors.number,
            () => controller.dispatch(
              const CalculatorInputCommand.insertToken('.'),
            ),
          ),
          _button(
            'EXP',
            colors.neutral,
            () => controller.dispatch(
              const CalculatorInputCommand.insertToken('EXP'),
            ),
          ),
          _button(
            '±',
            colors.neutral,
            () => controller.dispatch(CalculatorInputCommand.toggleSign),
          ),
          _button(
            '=',
            colors.equals,
            () => controller.dispatch(CalculatorInputCommand.calculate),
            foreground: Colors.white,
          ),
        ]),
      ],
    );
  }

  Widget _row(List<Widget> children) =>
      Expanded(child: Row(children: children));

  Widget _button(
    String label,
    Color background,
    VoidCallback onTap, {
    Color? foreground,
  }) {
    return Expanded(
      child: CalculatorButton(
        label: label,
        bgColor: background,
        textColor: foreground,
        labelSize: 18,
        density: density,
        onTap: onTap,
      ),
    );
  }
}

class _KeyColors {
  final ThemeData theme;

  const _KeyColors(this.theme);

  Color get number => theme.colorScheme.surface;

  Color get neutral => theme.colorScheme.surfaceContainerHigh;

  Color get function => Color.alphaBlend(
    theme.colorScheme.tertiary.withValues(alpha: 0.10),
    theme.colorScheme.surfaceContainerLow,
  );

  Color get constant => Color.alphaBlend(
    theme.colorScheme.secondary.withValues(alpha: 0.10),
    theme.colorScheme.surfaceContainerLow,
  );

  Color get operator => theme.colorScheme.primary;
  Color get equals => const Color(0xFF059669);
  Color get danger => theme.colorScheme.error;
}
