import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/safe_math_expression.dart';
import 'package:edusheet/features/paper_composer/application/question_rich_text_codec.dart';
import 'package:flutter/material.dart';

class QuestionCard extends StatelessWidget {
  static const _codec = QuestionRichTextCodec();
  final Question question;
  final int number;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onSaveToBank;

  const QuestionCard({
    super.key,
    required this.question,
    required this.number,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onSaveToBank,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unplacedMath = _codec.unplacedMathExpressions(question);
    final plain = question.plainTextAccessibility.trim();
    final hasDiagram = plain.contains('[diagram]');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plain.isEmpty ? 'Untitled question' : plain,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _MetaChip(label: question.type.label),
                        _MetaChip(label: '${_marks(question.marks)} marks'),
                        if (question.isOptional)
                          const _MetaChip(label: 'Optional'),
                        if (question.mathExpressions.isNotEmpty)
                          _MetaChip(
                            label:
                                '${question.mathExpressions.length} formula${question.mathExpressions.length == 1 ? '' : 's'}',
                            icon: Icons.functions_rounded,
                          ),
                        if (hasDiagram)
                          const _MetaChip(
                            label: 'Diagram',
                            icon: Icons.category_outlined,
                          ),
                      ],
                    ),
                    if (unplacedMath.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: unplacedMath.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) => Container(
                            constraints: const BoxConstraints(minWidth: 56),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: SafeMathExpression(
                              expression: unplacedMath[index],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<_QuestionMenuAction>(
                tooltip: 'Question actions',
                onSelected: (value) {
                  switch (value) {
                    case _QuestionMenuAction.edit:
                      onEdit();
                      break;
                    case _QuestionMenuAction.duplicate:
                      onDuplicate();
                      break;
                    case _QuestionMenuAction.saveToBank:
                      onSaveToBank();
                      break;
                    case _QuestionMenuAction.delete:
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _QuestionMenuAction.edit,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _QuestionMenuAction.duplicate,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.copy_rounded),
                      title: Text('Duplicate'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _QuestionMenuAction.saveToBank,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.bookmark_add_outlined),
                      title: Text('Save to Question Bank'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _QuestionMenuAction.delete,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _marks(double marks) {
    return marks == marks.roundToDouble()
        ? marks.toInt().toString()
        : marks.toStringAsFixed(1);
  }
}

enum _QuestionMenuAction { edit, duplicate, saveToBank, delete }

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _MetaChip({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13), const SizedBox(width: 4)],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
