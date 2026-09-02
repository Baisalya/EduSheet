import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/question_option_layout.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/safe_math_expression.dart';
import 'package:edusheet/features/paper_composer/application/question_rich_text_codec.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_rich_text_preview.dart';
import 'package:flutter/material.dart';

class QuestionCard extends StatelessWidget {
  static const _codec = QuestionRichTextCodec();
  final Question question;
  final int number;
  final String? numberLabel;
  final int? reorderIndex;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onSaveToBank;

  const QuestionCard({
    super.key,
    required this.question,
    required this.number,
    this.numberLabel,
    this.reorderIndex,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onSaveToBank,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unplacedMath = _codec.unplacedMathExpressions(question);
    final isWordBlock = question.isWordContentBlock;
    final fallbackPlain = question.plainTextAccessibility.trim();
    final decodedPlain = _codec.accessibleText(_codec.decodeQuestion(question));
    final plain = decodedPlain.isNotEmpty ? decodedPlain : fallbackPlain;
    final hasDiagram =
        plain.contains('[diagram]') || question.text.contains('"geometry"');
    final showRichPreview =
        !isWordBlock &&
        (question.text.trimLeft().startsWith('[{') ||
            question.mathExpressions.isNotEmpty ||
            hasDiagram);
    final blockKind = question.wordContentBlockKind;

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
        onTap: isWordBlock ? null : onEdit,
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
                child: isWordBlock
                    ? Icon(switch (blockKind) {
                        'table' => Icons.grid_on_outlined,
                        'image' => Icons.image_outlined,
                        _ => Icons.notes_rounded,
                      }, size: 19)
                    : Text(
                        numberLabel ?? '$number',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showRichPreview)
                      QuestionRichTextPreview(
                        key: ValueKey(
                          'smart-question-rich-preview-${question.id}',
                        ),
                        question: question,
                        maxHeight: 120,
                      )
                    else
                      Text(
                        plain.isEmpty
                            ? (isWordBlock
                                  ? 'Free Word content'
                                  : 'Untitled question')
                            : plain,
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
                        if (isWordBlock)
                          const _MetaChip(
                            label: 'Word content',
                            icon: Icons.article_outlined,
                          )
                        else ...[
                          _MetaChip(label: question.type.label),
                          _MetaChip(label: '${_marks(question.marks)} marks'),
                          if (question.isOptional)
                            const _MetaChip(label: 'Optional'),
                        ],
                        if (question.options.isNotEmpty &&
                            QuestionOptionLayoutCodec.fromQuestion(question) !=
                                QuestionOptionLayout.vertical)
                          _MetaChip(
                            label:
                                '${QuestionOptionLayoutCodec.fromQuestion(question).label} options',
                            icon: Icons.view_module_outlined,
                          ),
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
                    if (isWordBlock) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Free-form content from Word Mode • switch to Word Mode to edit',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
              if (reorderIndex != null)
                ReorderableDragStartListener(
                  index: reorderIndex!,
                  child: const Tooltip(
                    message: 'Drag to reorder',
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Icon(Icons.drag_indicator_rounded),
                    ),
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
                itemBuilder: (context) => [
                  if (!isWordBlock)
                    const PopupMenuItem(
                      value: _QuestionMenuAction.edit,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: _QuestionMenuAction.duplicate,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.copy_rounded),
                      title: Text('Duplicate'),
                    ),
                  ),
                  if (!isWordBlock)
                    const PopupMenuItem(
                      value: _QuestionMenuAction.saveToBank,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.bookmark_add_outlined),
                        title: Text('Save to Question Bank'),
                      ),
                    ),
                  const PopupMenuItem(
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
