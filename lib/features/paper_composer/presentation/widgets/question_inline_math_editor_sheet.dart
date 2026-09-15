import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/safe_math_expression.dart';
import 'package:edusheet/features/editor/domain/models/question_math_content.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';

class QuestionInlineMathEditorSheet extends StatefulWidget {
  final String title;
  final String fallbackText;
  final QuestionMathInlineDocument? initialDocument;

  const QuestionInlineMathEditorSheet({
    super.key,
    required this.title,
    required this.fallbackText,
    this.initialDocument,
  });

  static Future<QuestionMathInlineDocument?> show(
    BuildContext context, {
    required String title,
    required String fallbackText,
    QuestionMathInlineDocument? initialDocument,
  }) {
    return showAdaptiveModalBottomSheet<QuestionMathInlineDocument>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: QuestionInlineMathEditorSheet(
          title: title,
          fallbackText: fallbackText,
          initialDocument: initialDocument,
        ),
      ),
    );
  }

  @override
  State<QuestionInlineMathEditorSheet> createState() =>
      _QuestionInlineMathEditorSheetState();
}

class _QuestionInlineMathEditorSheetState
    extends State<QuestionInlineMathEditorSheet> {
  late List<_EditablePart> _parts;

  @override
  void initState() {
    super.initState();
    final document = widget.initialDocument;
    if (document != null && document.fallbackText == widget.fallbackText) {
      _parts = document.parts.map(_EditablePart.fromPart).toList();
    } else {
      _parts = [_EditablePart.text(widget.fallbackText)];
    }
    if (_parts.isEmpty) _parts.add(_EditablePart.text(''));
  }

  @override
  void dispose() {
    for (final part in _parts) {
      part.dispose();
    }
    super.dispose();
  }

  Future<void> _addFormula({int? afterIndex}) async {
    final expression = await FormulaEditorSheet.show(
      context,
      autoOpenMathKeyboard: true,
    );
    if (expression == null || !mounted) return;
    final part = _EditablePart.math(
      expression.copyWith(display: MathExpressionDisplay.inline),
    );
    setState(() {
      final index = afterIndex == null
          ? _parts.length
          : (afterIndex + 1).clamp(0, _parts.length).toInt();
      _parts.insert(index, part);
      if (index == _parts.length - 1 ||
          _parts[index + 1].kind != QuestionMathInlinePartKind.text) {
        _parts.insert(index + 1, _EditablePart.text(''));
      }
    });
  }

  Future<void> _editFormula(int index) async {
    final current = _parts[index].expression;
    if (current == null) return;
    final expression = await FormulaEditorSheet.show(
      context,
      initial: current,
      autoOpenMathKeyboard: true,
    );
    if (expression == null || !mounted) return;
    setState(() {
      _parts[index].expression = expression.copyWith(
        display: MathExpressionDisplay.inline,
      );
    });
  }

  void _addText() => setState(() => _parts.add(_EditablePart.text('')));

  void _remove(int index) {
    final removed = _parts.removeAt(index);
    removed.dispose();
    if (_parts.isEmpty) _parts.add(_EditablePart.text(''));
    setState(() {});
  }

  void _move(int index, int delta) {
    final next = index + delta;
    if (next < 0 || next >= _parts.length) return;
    setState(() {
      final part = _parts.removeAt(index);
      _parts.insert(next, part);
    });
  }

  QuestionMathInlineDocument _document() {
    return QuestionMathInlineDocument(
      parts: _parts.map((part) => part.toPart()).toList(),
    ).normalized().trimOuterWhitespace();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_document()),
            child: const Text('Done'),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + keyboardInset),
        children: [
          Text(
            'Build this field as ordered text + formula parts. EduSheet keeps a readable plain-text fallback for older files and PDF/Word export.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final entry in _parts.asMap().entries)
            _PartCard(
              index: entry.key,
              part: entry.value,
              canMoveUp: entry.key > 0,
              canMoveDown: entry.key < _parts.length - 1,
              onMoveUp: () => _move(entry.key, -1),
              onMoveDown: () => _move(entry.key, 1),
              onRemove: () => _remove(entry.key),
              onEditFormula: () => _editFormula(entry.key),
              onAddFormulaAfter: () => _addFormula(afterIndex: entry.key),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _addText,
                icon: const Icon(Icons.text_fields_rounded),
                label: const Text('Add text'),
              ),
              FilledButton.tonalIcon(
                onPressed: _addFormula,
                icon: const Icon(Icons.functions_rounded),
                label: const Text('Add formula'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Readable fallback',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          SelectableText(_document().fallbackText),
        ],
      ),
    );
  }
}

class _PartCard extends StatelessWidget {
  final int index;
  final _EditablePart part;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;
  final VoidCallback onEditFormula;
  final VoidCallback onAddFormulaAfter;

  const _PartCard({
    required this.index,
    required this.part,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    required this.onEditFormula,
    required this.onAddFormulaAfter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  part.kind == QuestionMathInlinePartKind.text
                      ? 'Text part ${index + 1}'
                      : 'Formula part ${index + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Move up',
                  onPressed: canMoveUp ? onMoveUp : null,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                ),
                IconButton(
                  tooltip: 'Move down',
                  onPressed: canMoveDown ? onMoveDown : null,
                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                ),
                IconButton(
                  tooltip: 'Remove part',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
            if (part.kind == QuestionMathInlinePartKind.text) ...[
              TextField(
                controller: part.controller,
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Text before or after the formula',
                  isDense: true,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onAddFormulaAfter,
                  icon: const Icon(Icons.functions_rounded, size: 17),
                  label: const Text('Formula after this'),
                ),
              ),
            ] else ...[
              if (part.expression != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SafeMathExpression(expression: part.expression!),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onEditFormula,
                  icon: const Icon(Icons.edit_rounded, size: 17),
                  label: const Text('Edit formula'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditablePart {
  final QuestionMathInlinePartKind kind;
  final TextEditingController? controller;
  MathExpression? expression;

  _EditablePart.text(String text)
    : kind = QuestionMathInlinePartKind.text,
      controller = TextEditingController(text: text),
      expression = null;

  _EditablePart.math(this.expression)
    : kind = QuestionMathInlinePartKind.math,
      controller = null;

  factory _EditablePart.fromPart(QuestionMathInlinePart part) {
    return switch (part.kind) {
      QuestionMathInlinePartKind.text => _EditablePart.text(part.text),
      QuestionMathInlinePartKind.math => _EditablePart.math(part.expression),
    };
  }

  QuestionMathInlinePart toPart() {
    return switch (kind) {
      QuestionMathInlinePartKind.text => QuestionMathInlinePart.text(
        controller?.text ?? '',
      ),
      QuestionMathInlinePartKind.math =>
        expression == null
            ? const QuestionMathInlinePart.text('')
            : QuestionMathInlinePart.math(expression!),
    };
  }

  void dispose() => controller?.dispose();
}
