import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../data/repositories/math_engine.dart';

class CalculatorDisplay extends StatelessWidget {
  final String equation;
  final String result;
  final bool isShift;
  final bool isAlpha;
  final bool isHyp;

  const CalculatorDisplay({
    super.key,
    required this.equation,
    required this.result,
    required this.isShift,
    required this.isAlpha,
    this.isHyp = false,
  });

  @override
  Widget build(BuildContext context) {
    final MathEngine engine = MathEngine();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFAEB89D), // Casio LCD Olive/Grey
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black.withAlpha(200), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Status Indicators (Small)
          Row(
            children: [
              if (isShift) _SmallIndicator(label: 'S'),
              if (isAlpha) _SmallIndicator(label: 'A'),
              if (isHyp) _SmallIndicator(label: 'HYP'),
              const Spacer(),
              _SmallIndicator(label: 'D', isActive: true),
              const SizedBox(width: 4),
              _SmallIndicator(label: 'Math', isActive: true),
            ],
          ),
          const SizedBox(height: 4),
          // Top Line (Expression)
          SizedBox(
            height: 40,
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Math.tex(
                engine.toLaTeX(equation.isEmpty ? ' ' : equation),
                textStyle: const TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          // Bottom Line (Result)
          const SizedBox(height: 8),
          Text(
            result,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              fontFamily: 'monospace',
              letterSpacing: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SmallIndicator extends StatelessWidget {
  final String label;
  final bool isActive;

  const _SmallIndicator({required this.label, this.isActive = true});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.bold,
        color: isActive ? Colors.black.withAlpha(180) : Colors.black.withAlpha(40),
      ),
    );
  }
}
