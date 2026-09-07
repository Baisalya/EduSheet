import 'package:flutter/material.dart';

import '../../domain/models/calculator_editing_value.dart';
import '../../domain/models/calculator_mode.dart';
import 'calculator_expression_editor.dart';

class CalculatorDisplay extends StatelessWidget {
  final CalculatorEditingValue editingValue;
  final String result;
  final String? previewResult;
  final String? errorMessage;
  final bool isShift;
  final bool isHyp;
  final AngleUnit angleUnit;
  final FocusNode expressionFocusNode;
  final ValueChanged<CalculatorSelection> onSelectionChanged;
  final bool compact;

  const CalculatorDisplay({
    super.key,
    required this.editingValue,
    required this.result,
    this.previewResult,
    required this.isShift,
    required this.isHyp,
    required this.angleUnit,
    required this.expressionFocusNode,
    required this.onSelectionChanged,
    this.compact = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final equation = editingValue.text;

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
        padding: compact
            ? const EdgeInsets.fromLTRB(12, 9, 12, 10)
            : const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
            SizedBox(height: compact ? 5 : 8),
            SizedBox(
              height: compact ? 38 : 44,
              width: double.infinity,
              child: CalculatorExpressionEditor(
                value: editingValue,
                focusNode: expressionFocusNode,
                onSelectionChanged: onSelectionChanged,
                compact: compact,
              ),
            ),
            SizedBox(height: compact ? 3 : 6),
            SizedBox(
              height: compact ? 24 : 30,
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
                            fontSize: compact ? 18 : 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                ),
              ),
            ),
            SizedBox(height: compact ? 0 : 2),
            SizedBox(
              height: compact ? 40 : 48,
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
                      fontSize: compact ? 34 : 40,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            if (errorMessage != null) ...[
              SizedBox(height: compact ? 2 : 4),
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
