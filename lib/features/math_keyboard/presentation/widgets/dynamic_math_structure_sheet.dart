import 'package:flutter/material.dart';

import '../../../editor/domain/models/math_expression.dart';
import '../../domain/models/math_dynamic_structure.dart';
import '../../domain/services/math_dynamic_structure_codec.dart';
import 'safe_math_expression.dart';

class DynamicMathStructureSheet extends StatefulWidget {
  final MathDynamicStructureKind initialKind;

  const DynamicMathStructureSheet({super.key, required this.initialKind});

  @override
  State<DynamicMathStructureSheet> createState() =>
      _DynamicMathStructureSheetState();
}

class _DynamicMathStructureSheetState extends State<DynamicMathStructureSheet> {
  late MathDynamicStructureKind _kind;
  int _rows = 3;
  int _columns = 3;
  int _augmentedSplitAfter = 2;
  String _relation = '=';

  static const _relations = <String, String>{
    '=': '=',
    r'\leq': '≤',
    r'\geq': '≥',
    r'\Rightarrow': '⇒',
  };

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    if (_kind == MathDynamicStructureKind.augmentedMatrix) {
      _columns = 3;
      _augmentedSplitAfter = 2;
    }
  }

  MathDynamicStructureSpec get _spec => MathDynamicStructureSpec(
    kind: _kind,
    rows: _rows,
    columns: switch (_kind) {
      MathDynamicStructureKind.matrix => _columns,
      MathDynamicStructureKind.augmentedMatrix => _columns,
      MathDynamicStructureKind.determinant => _rows,
      _ => 1,
    },
    augmentedSplitAfter: _kind == MathDynamicStructureKind.augmentedMatrix
        ? _augmentedSplitAfter
        : null,
    relation: _relation,
  );

  bool get _showsColumns =>
      _kind == MathDynamicStructureKind.matrix ||
      _kind == MathDynamicStructureKind.augmentedMatrix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = _spec;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Dynamic math structure',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose the shape and size. EduSheet creates real editable boxes instead of another fixed template.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: MathDynamicStructureKind.values
                  .map(
                    (kind) => ChoiceChip(
                      label: Text(_kindLabel(kind)),
                      selected: _kind == kind,
                      onSelected: (_) => _selectKind(kind),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 14),
            _CounterRow(
              label: _rowLabel(_kind),
              value: _rows,
              onDecrease: _rows > MathDynamicStructureLimits.minRows
                  ? () => setState(() => _rows--)
                  : null,
              onIncrease: _rows < MathDynamicStructureLimits.maxRows
                  ? () => setState(() => _rows++)
                  : null,
            ),
            if (_showsColumns) ...[
              const SizedBox(height: 8),
              _CounterRow(
                label: 'Columns',
                value: _columns,
                onDecrease: _columns > _minimumColumns
                    ? () => setState(() {
                        _columns--;
                        if (_kind == MathDynamicStructureKind.augmentedMatrix) {
                          _augmentedSplitAfter = _augmentedSplitAfter
                              .clamp(1, _columns - 1)
                              .toInt();
                        }
                      })
                    : null,
                onIncrease:
                    _columns < MathDynamicStructureLimits.maxColumns &&
                        _rows * (_columns + 1) <=
                            MathDynamicStructureLimits.maxSlots
                    ? () => setState(() => _columns++)
                    : null,
              ),
            ],
            if (_kind == MathDynamicStructureKind.augmentedMatrix) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _augmentedSplitAfter,
                decoration: const InputDecoration(
                  labelText: 'Divider after column',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(
                  _columns - 1,
                  (index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text('Column ${index + 1}'),
                  ),
                ),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _augmentedSplitAfter = value);
                },
              ),
            ],
            if (_kind == MathDynamicStructureKind.alignedDerivation) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _relation,
                decoration: const InputDecoration(
                  labelText: 'Relation between columns',
                  border: OutlineInputBorder(),
                ),
                items: _relations.entries
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _relation = value);
                },
              ),
            ],
            const SizedBox(height: 14),
            _buildPreview(context, spec),
            if (!spec.isValid) ...[
              const SizedBox(height: 8),
              Text(
                spec.validationMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('insert-dynamic-math-structure'),
              onPressed: spec.isValid
                  ? () => Navigator.of(context).pop(spec)
                  : null,
              icon: const Icon(Icons.add_box_outlined),
              label: Text('Insert ${_kindLabel(_kind)}'),
            ),
          ],
        ),
      ),
    );
  }

  int get _minimumColumns =>
      _kind == MathDynamicStructureKind.augmentedMatrix ? 2 : 1;

  Widget _buildPreview(BuildContext context, MathDynamicStructureSpec spec) {
    if (!spec.isValid) return const SizedBox.shrink();
    final previewValues = List<String>.filled(spec.slotCount, r'\Box');
    final instance = MathDynamicStructureInstance(
      spec: spec,
      values: previewValues,
    );
    final document = const MathDynamicStructureCodec().compile(instance);
    final expression = MathExpression(
      id: 'dynamic-structure-preview',
      latex: document.tex,
      plainText: document.plainText,
      display: MathExpressionDisplay.block,
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SafeMathExpression(expression: expression),
      ),
    );
  }

  void _selectKind(MathDynamicStructureKind kind) {
    setState(() {
      _kind = kind;
      if (kind == MathDynamicStructureKind.augmentedMatrix && _columns < 2) {
        _columns = 3;
      }
      if (kind == MathDynamicStructureKind.augmentedMatrix) {
        _augmentedSplitAfter = _augmentedSplitAfter
            .clamp(1, _columns - 1)
            .toInt();
      }
    });
  }

  String _kindLabel(MathDynamicStructureKind kind) => switch (kind) {
    MathDynamicStructureKind.matrix => 'Matrix',
    MathDynamicStructureKind.determinant => 'Determinant',
    MathDynamicStructureKind.augmentedMatrix => 'Augmented matrix',
    MathDynamicStructureKind.piecewise => 'Piecewise',
    MathDynamicStructureKind.equationSystem => 'Equation system',
    MathDynamicStructureKind.alignedDerivation => 'Aligned work',
  };

  String _rowLabel(MathDynamicStructureKind kind) => switch (kind) {
    MathDynamicStructureKind.determinant => 'Order',
    MathDynamicStructureKind.piecewise => 'Cases',
    MathDynamicStructureKind.equationSystem => 'Equations',
    MathDynamicStructureKind.alignedDerivation => 'Steps',
    _ => 'Rows',
  };
}

class _CounterRow extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  const _CounterRow({
    required this.label,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Decrease $label',
              onPressed: onDecrease,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 34,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              tooltip: 'Increase $label',
              onPressed: onIncrease,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}
