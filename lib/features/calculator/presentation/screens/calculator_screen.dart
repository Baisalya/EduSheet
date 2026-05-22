import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edusheet/features/calculator/presentation/providers/calculator_provider.dart';
import 'package:edusheet/features/calculator/presentation/widgets/calculator_button.dart';
import 'package:edusheet/features/calculator/presentation/widgets/calculator_display.dart';
import 'package:edusheet/features/calculator/presentation/widgets/formula_catalog_sheet.dart';

class CalculatorScreen extends ConsumerWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calculatorProvider);
    final notifier = ref.read(calculatorProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF3B4A5A), // Casio Blue-Grey Body
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              // 2-Line LCD Display
              CalculatorDisplay(
                equation: state.equation,
                result: state.result,
                isShift: state.isShift,
                isAlpha: state.isAlpha,
                isHyp: state.isHyp,
              ),
              const SizedBox(height: 12),
              
              // Top Control Section (Shift, Alpha, Replay, Mode, On)
              _buildTopControls(state, notifier),
              
              const SizedBox(height: 16),
              
              // Middle Scientific Grid (Pill Shape)
              Expanded(
                flex: 2,
                child: _ScientificKeypad(notifier: notifier, isHyp: state.isHyp),
              ),
              
              const SizedBox(height: 12),
              
              // Bottom Number Pad (Rect Shape)
              Expanded(
                flex: 3,
                child: _MainKeypad(notifier: notifier),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          const Text(
            'EduSheet',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'nx-298',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withAlpha(150),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.science),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const FormulaCatalogSheet(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTopControls(CalculatorState state, CalculatorNotifier notifier) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left Column: Shift & Alpha
        SizedBox(
          width: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CalculatorButton(
                label: 'SHIFT',
                shape: CalculatorButtonShape.round,
                bgColor: Colors.orange[300]!, // Distinct Shift color
                textColor: Colors.black,
                isActive: state.isShift,
                onTap: () => notifier.toggleShift(),
              ),
              const SizedBox(height: 8),
              CalculatorButton(
                label: 'ALPHA',
                shape: CalculatorButtonShape.round,
                bgColor: Colors.pink[200]!, // Distinct Alpha color
                textColor: Colors.black,
                isActive: state.isAlpha,
                onTap: () => notifier.toggleAlpha(),
              ),
            ],
          ),
        ),
        
        // Center: REPLAY D-PAD
        const _ReplayPad(),
        
        // Right Column: Mode & On
        SizedBox(
          width: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CalculatorButton(
                label: 'MODE',
                secondaryLabel: 'CLR',
                shape: CalculatorButtonShape.round,
                bgColor: Colors.grey[400]!,
                textColor: Colors.black,
                onTap: () {},
              ),
              const SizedBox(height: 8),
              CalculatorButton(
                label: 'ON',
                shape: CalculatorButtonShape.round,
                bgColor: Colors.grey[400]!,
                textColor: Colors.black,
                onTap: () => notifier.clear(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScientificKeypad extends StatelessWidget {
  final CalculatorNotifier notifier;
  final bool isHyp;

  const _ScientificKeypad({required this.notifier, required this.isHyp});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row([
          _btn('x⁻¹', sec: 'x!', tap: () => notifier.addToken('!')),
          _btn('nCr', sec: 'nPr', tap: () => notifier.addToken('C')),
          _btn('Pol(', sec: 'Rec(', tap: () => notifier.addToken('Pol(')),
          _btn('x³', sec: '∛', tap: () => notifier.addToken('^3')),
        ]),
        _row([
          _btn('ab/c', sec: 'd/c', tap: () => notifier.addToken('/')),
          _btn('√', sec: '∛', tap: () => notifier.addToken('sqrt(')),
          _btn('x²', sec: 'x³', tap: () => notifier.addToken('^2')),
          _btn('^', sec: 'ˣ√', tap: () => notifier.addToken('^')),
          _btn('log', sec: '10ˣ', tap: () => notifier.addToken('log(')),
          _btn('ln', sec: 'eˣ', tap: () => notifier.addToken('ln(')),
        ]),
        _row([
          _btn('(-)', sec: 'A', alpha: 'A', tap: () => notifier.addToken('-')),
          _btn('.,,,', sec: 'B', alpha: 'B', tap: () {}),
          _btn('hyp', sec: 'C', alpha: 'C', active: isHyp, tap: () => notifier.toggleHyp()),
          _btn('sin', sec: 'sin⁻¹', alpha: 'D', tap: () => notifier.addToken('sin(')),
          _btn('cos', sec: 'cos⁻¹', alpha: 'E', tap: () => notifier.addToken('cos(')),
          _btn('tan', sec: 'tan⁻¹', alpha: 'F', tap: () => notifier.addToken('tan(')),
        ]),
        _row([
          _btn('RCL', sec: 'STO', tap: () {}),
          _btn('ENG', sec: '←', tap: () {}),
          _btn('(', sec: 'X', alpha: 'X', tap: () => notifier.addToken('(')),
          _btn(')', sec: 'Y', alpha: 'Y', tap: () => notifier.addToken(')')),
          _btn(',', sec: ';', alpha: 'M', tap: () => notifier.addToken(',')),
          _btn('M+', sec: 'M-', tap: () {}),
        ]),
      ],
    );
  }

  Widget _row(List<Widget> children) => Expanded(child: Row(children: children));

  Widget _btn(String label, {String? sec, String? alpha, VoidCallback? tap, bool active = false}) {
    return Expanded(
      child: CalculatorButton(
        label: label,
        secondaryLabel: sec,
        alphaLabel: alpha,
        shape: CalculatorButtonShape.pill,
        isActive: active,
        onTap: tap ?? () {},
      ),
    );
  }
}

class _MainKeypad extends StatelessWidget {
  final CalculatorNotifier notifier;

  const _MainKeypad({required this.notifier});

  @override
  Widget build(BuildContext context) {
    const delColor = Color(0xFFC0392B);
    return Column(
      children: [
        _row([
          _btn('7', tap: () => notifier.addToken('7')),
          _btn('8', tap: () => notifier.addToken('8')),
          _btn('9', tap: () => notifier.addToken('9')),
          _btn('DEL', sec: 'INS', bg: delColor, tap: () => notifier.delete()),
          _btn('AC', sec: 'OFF', bg: delColor, tap: () => notifier.clear()),
        ]),
        _row([
          _btn('4', tap: () => notifier.addToken('4')),
          _btn('5', tap: () => notifier.addToken('5')),
          _btn('6', tap: () => notifier.addToken('6')),
          _btn('×', tap: () => notifier.addToken('×')),
          _btn('÷', tap: () => notifier.addToken('÷')),
        ]),
        _row([
          _btn('1', tap: () => notifier.addToken('1')),
          _btn('2', tap: () => notifier.addToken('2')),
          _btn('3', tap: () => notifier.addToken('3')),
          _btn('+', tap: () => notifier.addToken('+')),
          _btn('-', tap: () => notifier.addToken('-')),
        ]),
        _row([
          _btn('0', tap: () => notifier.addToken('0')),
          _btn('.', sec: 'Ran#', tap: () => notifier.addToken('.')),
          _btn('EXP', sec: 'π', tap: () => notifier.addToken('π')),
          _btn('Ans', sec: 'DRG>', tap: () => notifier.calculate()),
          _btn('=', tap: () => notifier.calculate()),
        ]),
      ],
    );
  }

  Widget _row(List<Widget> children) => Expanded(child: Row(children: children));

  Widget _btn(String label, {String? sec, Color? bg, VoidCallback? tap}) {
    return Expanded(
      child: CalculatorButton(
        label: label,
        secondaryLabel: sec,
        bgColor: bg ?? const Color(0xFF3E3E3E),
        onTap: tap ?? () {},
      ),
    );
  }
}

class _ReplayPad extends ConsumerWidget {
  const _ReplayPad();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(calculatorProvider.notifier);
    
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.grey[400],
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withAlpha(100),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
        gradient: RadialGradient(
          colors: [
            Colors.grey[300]!,
            Colors.grey[500]!,
          ],
        ),
      ),
      child: Stack(
        children: [
          const Center(
            child: Text(
              'REPLAY',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _DpadButton(
            alignment: Alignment.topCenter,
            icon: Icons.arrow_drop_up,
            onTap: () => notifier.scrollHistory(-1),
          ),
          _DpadButton(
            alignment: Alignment.bottomCenter,
            icon: Icons.arrow_drop_down,
            onTap: () => notifier.scrollHistory(1),
          ),
          _DpadButton(
            alignment: Alignment.centerLeft,
            icon: Icons.arrow_left,
            onTap: () {}, // Cursor logic handled in provider
          ),
          _DpadButton(
            alignment: Alignment.centerRight,
            icon: Icons.arrow_right,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _DpadButton extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final VoidCallback onTap;

  const _DpadButton({
    required this.alignment,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IconButton(
        icon: Icon(icon, color: Colors.black87, size: 28),
        onPressed: onTap,
        splashRadius: 24,
      ),
    );
  }
}
