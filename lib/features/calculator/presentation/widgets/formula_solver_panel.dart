import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/calculator_input_command.dart';
import '../../domain/models/formula_model.dart';
import '../../domain/services/formula_solver.dart';
import '../providers/calculator_provider.dart';

class FormulaSolverPanel extends ConsumerStatefulWidget {
  final Formula formula;
  final VoidCallback onBack;

  const FormulaSolverPanel({
    super.key,
    required this.formula,
    required this.onBack,
  });

  @override
  ConsumerState<FormulaSolverPanel> createState() => _FormulaSolverPanelState();
}

class _FormulaSolverPanelState extends ConsumerState<FormulaSolverPanel> {
  late final Map<String, TextEditingController> _controllers;
  FormulaSolveResult? _solveResult;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final variable in widget.formula.variables)
        variable.symbol: TextEditingController(
          text: variable.defaultValue ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _solveResult;
    final calculationFailure = result?.calculation?.isFailure == true
        ? result!.calculation
        : null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    key: const ValueKey('formula-solver-back'),
                    tooltip: 'Back to formulas',
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.formula.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.formula.expression,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.formula.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.formula.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha(90),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calculate_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Calculate ${widget.formula.targetLabel} '
                        '(${widget.formula.targetSymbol})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (widget.formula.resultUnit.isNotEmpty)
                      Text(
                        widget.formula.resultUnit,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter values',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Use the units shown below for the displayed result unit. '
                'Calculator expressions such as 2+3 are accepted.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 560;
                  final width = twoColumns
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final variable in widget.formula.variables)
                        SizedBox(
                          width: width,
                          child: _FormulaVariableField(
                            variable: variable,
                            controller: _controllers[variable.symbol]!,
                            errorText: result?.fieldErrors[variable.symbol],
                            onChanged: _invalidateResult,
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (result?.configurationError != null) ...[
                const SizedBox(height: 12),
                _FormulaErrorCard(message: result!.configurationError!),
              ] else if (calculationFailure != null) ...[
                const SizedBox(height: 12),
                _FormulaErrorCard(
                  message:
                      calculationFailure.errorMessage ??
                      'Unable to evaluate this formula with the entered values.',
                ),
              ] else if (result?.isSuccess == true) ...[
                const SizedBox(height: 12),
                _FormulaResultCard(formula: widget.formula, result: result!),
              ],
            ],
          ),
        ),
        Material(
          color: theme.colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('formula-solver-calculate'),
                      onPressed: _calculate,
                      icon: const Icon(Icons.calculate_rounded),
                      label: const Text('Calculate'),
                    ),
                  ),
                  if (result?.isSuccess == true) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<_FormulaInsertAction>(
                      key: const ValueKey('formula-solver-insert-menu'),
                      tooltip: 'Use in calculator',
                      onSelected: _insertIntoCalculator,
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _FormulaInsertAction.result,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.output_rounded),
                            title: Text('Insert result'),
                            subtitle: Text('Insert the solved numeric value'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _FormulaInsertAction.expression,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.functions_rounded),
                            title: Text('Insert calculation'),
                            subtitle: Text(
                              'Insert the resolved numeric formula',
                            ),
                          ),
                        ),
                      ],
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.primary),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_to_photos_outlined,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Use',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _invalidateResult(String _) {
    if (_solveResult != null) {
      setState(() => _solveResult = null);
    }
  }

  void _calculate() {
    final calculatorState = ref.read(calculatorProvider);
    final solver = ref.read(formulaSolverProvider);
    final inputs = {
      for (final entry in _controllers.entries) entry.key: entry.value.text,
    };
    setState(() {
      _solveResult = solver.solve(
        widget.formula,
        inputs,
        angleUnit: calculatorState.angleUnit,
        ans: calculatorState.lastAnswer,
      );
    });
  }

  void _insertIntoCalculator(_FormulaInsertAction action) {
    final result = _solveResult;
    if (result == null || !result.isSuccess) return;

    final solver = ref.read(formulaSolverProvider);
    final expression = switch (action) {
      _FormulaInsertAction.result => solver.serializeResult(result),
      _FormulaInsertAction.expression => '(${result.resolvedExpression!})',
    };
    if (expression.isEmpty) return;

    ref
        .read(calculatorProvider.notifier)
        .dispatch(CalculatorInputCommand.insertFormula(expression));
    Navigator.pop(context);
  }
}

enum _FormulaInsertAction { result, expression }

class _FormulaVariableField extends StatelessWidget {
  final FormulaVariable variable;
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;

  const _FormulaVariableField({
    required this.variable,
    required this.controller,
    required this.errorText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final helperParts = <String>[];
    if (variable.description.isNotEmpty) helperParts.add(variable.description);
    if (variable.hasDefaultValue) {
      helperParts.add('Default: ${variable.defaultValue}');
    }

    return TextField(
      key: ValueKey('formula-input-${variable.symbol}'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: variable.label,
        prefixText: '${variable.symbol}  ',
        suffixText: variable.unit.isEmpty ? null : variable.unit,
        helperText: helperParts.isEmpty ? null : helperParts.join(' · '),
        errorText: errorText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _FormulaResultCard extends StatelessWidget {
  final Formula formula;
  final FormulaSolveResult result;

  const _FormulaResultCard({required this.formula, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitSuffix = formula.resultUnit.isEmpty
        ? ''
        : ' ${formula.resultUnit}';
    return Container(
      key: const ValueKey('formula-solver-result'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withAlpha(100),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.secondary.withAlpha(90)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: theme.colorScheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Result',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  '${formula.targetSymbol} = ${result.displayText}$unitSuffix',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormulaErrorCard extends StatelessWidget {
  final String message;

  const _FormulaErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('formula-solver-error'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
