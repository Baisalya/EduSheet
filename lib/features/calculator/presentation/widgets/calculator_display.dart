import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../domain/models/calculator_mode.dart';
import '../../domain/services/calculator_expression_formatter.dart';

class CalculatorDisplay extends StatelessWidget {
  final String equation;
  final String result;
  final String? previewResult;
  final String? errorMessage;
  final bool isShift;
  final bool isHyp;
  final AngleUnit angleUnit;

  const CalculatorDisplay({
    super.key,
    required this.equation,
    required this.result,
    this.previewResult,
    required this.isShift,
    required this.isHyp,
    required this.angleUnit,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const formatter = CalculatorExpressionFormatter();
    final latex = formatter.toLatex(equation);

    return Semantics(
      container: true,
      label: 'Calculator display',
      value: equation.isEmpty
          ? result
          : previewResult == null
          ? '$equation, committed result $result'
          : '$equation, live preview $previewResult, committed result $result',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              width: double.infinity,
              child: Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Math.tex(
                    latex,
                    textStyle: TextStyle(
                      fontSize: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              width: double.infinity,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: previewResult == null
                      ? const SizedBox.shrink()
                      : Text(
                          '≈ $previewResult',
                          key: const ValueKey('calculator-live-preview'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(
                              148,
                            ),
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    result,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    style: TextStyle(
                      color: errorMessage == null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.error,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                errorMessage!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
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
        ),
      ),
    );
  }
}
