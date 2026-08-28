import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/calculator_mode.dart';
import '../providers/calculator_provider.dart';
import 'calculator_button.dart';
import 'calculator_display.dart';

class ScientificCalculator extends ConsumerStatefulWidget {
  const ScientificCalculator({super.key});

  @override
  ConsumerState<ScientificCalculator> createState() =>
      _ScientificCalculatorState();
}

class _ScientificCalculatorState extends ConsumerState<ScientificCalculator> {
  final FocusNode _keyboardFocus = FocusNode(
    debugLabel: 'scientific-calculator-keyboard',
  );

  @override
  void dispose() {
    _keyboardFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calculatorProvider);
    final controller = ref.read(calculatorProvider.notifier);

    return Focus(
      focusNode: _keyboardFocus,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _keyboardFocus.requestFocus,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final short = constraints.maxHeight < 650;
            final padding = constraints.maxWidth >= 1000 ? 20.0 : 12.0;

            if (short) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(padding, 6, padding, 12),
                child: Column(
                  children: [
                    CalculatorDisplay(
                      equation: state.equation,
                      result: state.result,
                      previewResult: state.previewResult,
                      errorMessage: state.errorMessage,
                      isShift: state.isShift,
                      isHyp: state.isHyp,
                      angleUnit: state.angleUnit,
                    ),
                    const SizedBox(height: 10),
                    _ModeStrip(state: state, controller: controller),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: wide ? 330 : 545,
                      child: _KeypadArea(
                        state: state,
                        controller: controller,
                        wide: wide,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(padding, 6, padding, 12),
              child: Column(
                children: [
                  CalculatorDisplay(
                    equation: state.equation,
                    result: state.result,
                    previewResult: state.previewResult,
                    errorMessage: state.errorMessage,
                    isShift: state.isShift,
                    isHyp: state.isHyp,
                    angleUnit: state.angleUnit,
                  ),
                  const SizedBox(height: 10),
                  _ModeStrip(state: state, controller: controller),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _KeypadArea(
                      state: state,
                      controller: controller,
                      wide: wide,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final controller = ref.read(calculatorProvider.notifier);
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      controller.calculate();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      controller.delete();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      controller.clear();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      controller.previousHistory();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      controller.nextHistory();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.numpadAdd) {
      controller.addToken('+');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.numpadSubtract) {
      controller.addToken('-');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.numpadMultiply) {
      controller.addToken('×');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.numpadDivide) {
      controller.addToken('÷');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.numpadDecimal) {
      controller.addToken('.');
      return KeyEventResult.handled;
    }

    final digit = _digitForKey(key);
    if (digit != null) {
      controller.addToken(digit);
      return KeyEventResult.handled;
    }

    final character = event.character;
    if (character == null || character.isEmpty) {
      return KeyEventResult.ignored;
    }

    if (RegExp(r'^[0-9]$').hasMatch(character)) {
      controller.addToken(character);
      return KeyEventResult.handled;
    }

    switch (character) {
      case '+':
      case '-':
      case '(':
      case ')':
      case '.':
      case '^':
        controller.addToken(character);
        return KeyEventResult.handled;
      case '*':
        controller.addToken('×');
        return KeyEventResult.handled;
      case '/':
        controller.addToken('÷');
        return KeyEventResult.handled;
      case '=':
        controller.calculate();
        return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  String? _digitForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      return '0';
    }
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      return '1';
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      return '2';
    }
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      return '3';
    }
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      return '4';
    }
    if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
      return '5';
    }
    if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
      return '6';
    }
    if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
      return '7';
    }
    if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
      return '8';
    }
    if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
      return '9';
    }
    return null;
  }
}

class _KeypadArea extends StatelessWidget {
  final CalculatorState state;
  final CalculatorController controller;
  final bool wide;

  const _KeypadArea({
    required this.state,
    required this.controller,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: _ScientificKeypad(state: state, controller: controller),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: _MainKeypad(controller: controller)),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _ScientificKeypad(state: state, controller: controller),
        ),
        const SizedBox(height: 6),
        Expanded(flex: 4, child: _MainKeypad(controller: controller)),
      ],
    );
  }
}

class _ModeStrip extends StatelessWidget {
  final CalculatorState state;
  final CalculatorController controller;

  const _ModeStrip({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final veryCompact = constraints.maxWidth < 390;
        final showStatus = constraints.maxWidth >= 430;
        final buttonWidth = veryCompact ? 62.0 : 72.0;

        return SizedBox(
          height: 44,
          child: Row(
            children: [
              _ModeButton(
                width: buttonWidth,
                label: 'SHIFT',
                selected: state.isShift,
                activeColor: const Color(0xFFF59E0B),
                onTap: controller.toggleShift,
              ),
              _ModeButton(
                width: buttonWidth,
                label: 'HYP',
                selected: state.isHyp,
                activeColor: const Color(0xFF7C3AED),
                onTap: controller.toggleHyp,
              ),
              _ModeButton(
                width: buttonWidth,
                label: state.angleUnit == AngleUnit.degrees ? 'DEG' : 'RAD',
                selected: state.angleUnit == AngleUnit.degrees,
                activeColor: const Color(0xFF059669),
                onTap: controller.toggleAngleUnit,
              ),
              if (showStatus)
                Expanded(
                  child: Container(
                    height: double.infinity,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
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
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
                  color: selected ? Colors.white : theme.colorScheme.onSurface,
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

  const _ScientificKeypad({required this.state, required this.controller});

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
            onTap: () => controller.addToken('sin('),
          ),
          _functionButton(
            state.isHyp ? 'cosh' : (state.isShift ? 'cos⁻¹' : 'cos'),
            secondary: state.isHyp || state.isShift ? null : 'cos⁻¹',
            background: colors.function,
            onTap: () => controller.addToken('cos('),
          ),
          _functionButton(
            state.isHyp ? 'tanh' : (state.isShift ? 'tan⁻¹' : 'tan'),
            secondary: state.isHyp || state.isShift ? null : 'tan⁻¹',
            background: colors.function,
            onTap: () => controller.addToken('tan('),
          ),
          _functionButton(
            state.isShift ? '10ˣ' : 'log',
            secondary: state.isShift ? null : '10ˣ',
            background: colors.function,
            onTap: () => controller.addToken('log('),
          ),
          _functionButton(
            state.isShift ? 'eˣ' : 'ln',
            secondary: state.isShift ? null : 'eˣ',
            background: colors.function,
            onTap: () => controller.addToken('ln('),
          ),
        ]),
        _row([
          _functionButton(
            state.isShift ? '∛x' : '√x',
            secondary: state.isShift ? null : '∛x',
            background: colors.function,
            onTap: () => controller.addToken('sqrt('),
          ),
          _functionButton(
            state.isShift ? 'x³' : 'x²',
            secondary: state.isShift ? null : 'x³',
            background: colors.function,
            onTap: () => controller.addToken('^2'),
          ),
          _functionButton(
            state.isShift ? 'x⁻¹' : 'xʸ',
            secondary: state.isShift ? null : 'x⁻¹',
            background: colors.function,
            onTap: () => controller.addToken('^'),
          ),
          _functionButton(
            state.isShift ? 'nPr' : 'nCr',
            secondary: state.isShift ? null : 'nPr',
            background: colors.function,
            onTap: () => controller.addToken('C'),
          ),
          _functionButton(
            'x!',
            background: colors.function,
            onTap: () => controller.addToken('!'),
          ),
        ]),
        _row([
          _functionButton(
            'π',
            background: colors.constant,
            onTap: () => controller.addToken('π'),
          ),
          _functionButton(
            'e',
            background: colors.constant,
            onTap: () => controller.addToken('e'),
          ),
          _functionButton(
            'Ans',
            background: colors.constant,
            onTap: () => controller.addToken('Ans'),
          ),
          _functionButton(
            '(',
            background: colors.neutral,
            onTap: () => controller.addToken('('),
          ),
          _functionButton(
            ')',
            background: colors.neutral,
            onTap: () => controller.addToken(')'),
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
        onTap: onTap,
      ),
    );
  }
}

class _MainKeypad extends StatelessWidget {
  final CalculatorController controller;

  const _MainKeypad({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = _KeyColors(Theme.of(context));
    return Column(
      children: [
        _row([
          _button('7', colors.number, () => controller.addToken('7')),
          _button('8', colors.number, () => controller.addToken('8')),
          _button('9', colors.number, () => controller.addToken('9')),
          _button(
            'DEL',
            colors.danger,
            controller.delete,
            foreground: Colors.white,
          ),
          _button(
            'AC',
            colors.danger,
            controller.clear,
            foreground: Colors.white,
          ),
        ]),
        _row([
          _button('4', colors.number, () => controller.addToken('4')),
          _button('5', colors.number, () => controller.addToken('5')),
          _button('6', colors.number, () => controller.addToken('6')),
          _button(
            '×',
            colors.operator,
            () => controller.addToken('×'),
            foreground: Colors.white,
          ),
          _button(
            '÷',
            colors.operator,
            () => controller.addToken('÷'),
            foreground: Colors.white,
          ),
        ]),
        _row([
          _button('1', colors.number, () => controller.addToken('1')),
          _button('2', colors.number, () => controller.addToken('2')),
          _button('3', colors.number, () => controller.addToken('3')),
          _button(
            '+',
            colors.operator,
            () => controller.addToken('+'),
            foreground: Colors.white,
          ),
          _button(
            '-',
            colors.operator,
            () => controller.addToken('-'),
            foreground: Colors.white,
          ),
        ]),
        _row([
          _button('0', colors.number, () => controller.addToken('0')),
          _button('.', colors.number, () => controller.addToken('.')),
          _button('EXP', colors.neutral, () => controller.addToken('EXP')),
          _button('±', colors.neutral, controller.toggleSign),
          _button(
            '=',
            colors.equals,
            controller.calculate,
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
        onTap: onTap,
      ),
    );
  }
}

class _KeyColors {
  final ThemeData theme;

  const _KeyColors(this.theme);

  Color get number => theme.brightness == Brightness.dark
      ? const Color(0xFF2F3338)
      : const Color(0xFFFFFFFF);

  Color get neutral => theme.brightness == Brightness.dark
      ? const Color(0xFF252A30)
      : const Color(0xFFE8EDF3);

  Color get function => theme.brightness == Brightness.dark
      ? const Color(0xFF1F3A3D)
      : const Color(0xFFE0F2F1);

  Color get constant => theme.brightness == Brightness.dark
      ? const Color(0xFF3B3422)
      : const Color(0xFFFFF3D6);

  Color get operator => const Color(0xFF2563EB);
  Color get equals => const Color(0xFF059669);
  Color get danger => const Color(0xFFDC2626);
}
