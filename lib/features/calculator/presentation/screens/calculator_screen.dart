import 'package:edusheet/features/calculator/data/repositories/math_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edusheet/features/calculator/presentation/providers/calculator_provider.dart';
import 'package:edusheet/features/calculator/presentation/widgets/calculator_button.dart';
import 'package:edusheet/features/calculator/presentation/widgets/calculator_display.dart';
import 'package:edusheet/features/calculator/presentation/widgets/calculator_history_drawer.dart';
import 'package:edusheet/features/calculator/presentation/widgets/formula_catalog_sheet.dart';

class CalculatorScreen extends ConsumerWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calculatorProvider);
    final notifier = ref.read(calculatorProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scientific Calculator',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => _showHistory(context),
          ),
          IconButton(
            tooltip: 'Science formulas',
            icon: const Icon(Icons.science_rounded),
            onPressed: () => _showFormulaCatalog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(
            children: [
              CalculatorDisplay(
                equation: state.equation,
                result: state.result,
                isShift: state.isShift,
                isAlpha: state.isAlpha,
                isHyp: state.isHyp,
                angleUnit: state.angleUnit,
              ),
              const SizedBox(height: 10),
              _ModeStrip(state: state, notifier: notifier),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 520;
                    return Column(
                      children: [
                        Expanded(
                          flex: compact ? 5 : 4,
                          child: _ScientificKeypad(notifier: notifier),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          flex: 5,
                          child: _MainKeypad(notifier: notifier),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFormulaCatalog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FormulaCatalogSheet(),
    );
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FractionallySizedBox(
        heightFactor: 0.72,
        child: CalculatorHistoryDrawer(),
      ),
    );
  }
}

class _ModeStrip extends StatelessWidget {
  final CalculatorState state;
  final CalculatorNotifier notifier;

  const _ModeStrip({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          _ModeButton(
            label: 'SHIFT',
            selected: state.isShift,
            color: const Color(0xFFF59E0B),
            onTap: notifier.toggleShift,
          ),
          _ModeButton(
            label: 'HYP',
            selected: state.isHyp,
            color: const Color(0xFF7C3AED),
            onTap: notifier.toggleHyp,
          ),
          _ModeButton(
            label: state.angleUnit == AngleUnit.degrees ? 'DEG' : 'RAD',
            selected: state.angleUnit == AngleUnit.degrees,
            color: const Color(0xFF059669),
            onTap: notifier.toggleAngleUnit,
          ),
          Expanded(
            child: Container(
              height: double.infinity,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                state.isShift
                    ? 'inverse functions'
                    : state.isHyp
                    ? 'hyperbolic functions'
                    : 'ready',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
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
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: SizedBox(
        width: 72,
        height: double.infinity,
        child: Material(
          color: selected ? color : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
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
  final CalculatorNotifier notifier;

  const _ScientificKeypad({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final colors = _KeyColors(Theme.of(context));
    return Column(
      children: [
        _row([
          _btn(
            'sin',
            sec: 'sin⁻¹',
            bg: colors.function,
            tap: () => notifier.addToken('sin('),
          ),
          _btn(
            'cos',
            sec: 'cos⁻¹',
            bg: colors.function,
            tap: () => notifier.addToken('cos('),
          ),
          _btn(
            'tan',
            sec: 'tan⁻¹',
            bg: colors.function,
            tap: () => notifier.addToken('tan('),
          ),
          _btn(
            'log',
            sec: '10ˣ',
            bg: colors.function,
            tap: () => notifier.addToken('log('),
          ),
          _btn(
            'ln',
            sec: 'eˣ',
            bg: colors.function,
            tap: () => notifier.addToken('ln('),
          ),
        ]),
        _row([
          _btn(
            '√x',
            sec: '∛x',
            bg: colors.function,
            tap: () => notifier.addToken('sqrt('),
          ),
          _btn(
            'x²',
            sec: 'x³',
            bg: colors.function,
            tap: () => notifier.addToken('^2'),
          ),
          _btn(
            'xʸ',
            sec: 'x⁻¹',
            bg: colors.function,
            tap: () => notifier.addToken('^'),
          ),
          _btn(
            'nCr',
            sec: 'nPr',
            bg: colors.function,
            tap: () => notifier.addToken('C'),
          ),
          _btn('x!', bg: colors.function, tap: () => notifier.addToken('!')),
        ]),
        _row([
          _btn('π', bg: colors.constant, tap: () => notifier.addToken('π')),
          _btn('e', bg: colors.constant, tap: () => notifier.addToken('e')),
          _btn('Ans', bg: colors.constant, tap: () => notifier.addToken('Ans')),
          _btn('(', bg: colors.neutral, tap: () => notifier.addToken('(')),
          _btn(')', bg: colors.neutral, tap: () => notifier.addToken(')')),
        ]),
      ],
    );
  }

  Widget _row(List<Widget> children) =>
      Expanded(child: Row(children: children));

  Widget _btn(
    String label, {
    String? sec,
    required Color bg,
    required VoidCallback tap,
  }) {
    return Expanded(
      child: CalculatorButton(
        label: label,
        secondaryLabel: sec,
        bgColor: bg,
        labelSize: 15,
        onTap: tap,
      ),
    );
  }
}

class _MainKeypad extends StatelessWidget {
  final CalculatorNotifier notifier;

  const _MainKeypad({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final colors = _KeyColors(Theme.of(context));
    return Column(
      children: [
        _row([
          _btn('7', bg: colors.number, tap: () => notifier.addToken('7')),
          _btn('8', bg: colors.number, tap: () => notifier.addToken('8')),
          _btn('9', bg: colors.number, tap: () => notifier.addToken('9')),
          _btn(
            'DEL',
            bg: colors.danger,
            fg: Colors.white,
            tap: notifier.delete,
          ),
          _btn('AC', bg: colors.danger, fg: Colors.white, tap: notifier.clear),
        ]),
        _row([
          _btn('4', bg: colors.number, tap: () => notifier.addToken('4')),
          _btn('5', bg: colors.number, tap: () => notifier.addToken('5')),
          _btn('6', bg: colors.number, tap: () => notifier.addToken('6')),
          _btn(
            '×',
            bg: colors.operator,
            fg: Colors.white,
            tap: () => notifier.addToken('×'),
          ),
          _btn(
            '÷',
            bg: colors.operator,
            fg: Colors.white,
            tap: () => notifier.addToken('÷'),
          ),
        ]),
        _row([
          _btn('1', bg: colors.number, tap: () => notifier.addToken('1')),
          _btn('2', bg: colors.number, tap: () => notifier.addToken('2')),
          _btn('3', bg: colors.number, tap: () => notifier.addToken('3')),
          _btn(
            '+',
            bg: colors.operator,
            fg: Colors.white,
            tap: () => notifier.addToken('+'),
          ),
          _btn(
            '-',
            bg: colors.operator,
            fg: Colors.white,
            tap: () => notifier.addToken('-'),
          ),
        ]),
        _row([
          _btn('0', bg: colors.number, tap: () => notifier.addToken('0')),
          _btn('.', bg: colors.number, tap: () => notifier.addToken('.')),
          _btn('EXP', bg: colors.neutral, tap: () => notifier.addToken('EXP')),
          _btn('±', bg: colors.neutral, tap: notifier.toggleSign),
          _btn(
            '=',
            bg: colors.equals,
            fg: Colors.white,
            tap: notifier.calculate,
          ),
        ]),
      ],
    );
  }

  Widget _row(List<Widget> children) =>
      Expanded(child: Row(children: children));

  Widget _btn(
    String label, {
    required Color bg,
    Color? fg,
    required VoidCallback tap,
  }) {
    return Expanded(
      child: CalculatorButton(
        label: label,
        bgColor: bg,
        textColor: fg ?? const Color(0xFF111827),
        labelSize: 18,
        onTap: tap,
      ),
    );
  }
}

class _KeyColors {
  final ThemeData theme;

  _KeyColors(this.theme);

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
