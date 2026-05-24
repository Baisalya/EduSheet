import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../data/repositories/math_engine.dart';

class CalculatorDisplay extends StatelessWidget {
  final String equation;
  final String result;
  final bool isShift;
  final bool isAlpha;
  final bool isHyp;
  final AngleUnit angleUnit;

  const CalculatorDisplay({
    super.key,
    required this.equation,
    required this.result,
    required this.isShift,
    required this.isAlpha,
    required this.angleUnit,
    this.isHyp = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final engine = MathEngine();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              _StatusChip(
                label: angleUnit == AngleUnit.degrees ? 'DEG' : 'RAD',
                isActive: true,
              ),
              if (isShift) const _StatusChip(label: 'SHIFT', isActive: true),
              if (isAlpha) const _StatusChip(label: 'ALPHA', isActive: true),
              if (isHyp) const _StatusChip(label: 'HYP', isActive: true),
              const Spacer(),
              Text(
                'Scientific',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Math.tex(
                  engine.toLaTeX(equation.isEmpty ? ' ' : equation),
                  textStyle: TextStyle(
                    fontSize: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isActive;

  const _StatusChip({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 22,
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary.withAlpha(28)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
