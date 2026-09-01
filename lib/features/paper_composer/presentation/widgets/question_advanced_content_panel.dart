import 'dart:io';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/application/question_advanced_structure_service.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class QuestionAdvancedContentPanel extends StatelessWidget {
  final QuestionDraft draft;
  final VoidCallback onEditStimulus;
  final VoidCallback onRemoveStimulus;
  final VoidCallback onEditWordBank;
  final VoidCallback onRemoveWordBank;
  final VoidCallback onEditTable;
  final VoidCallback onRemoveTable;
  final VoidCallback onAddImage;
  final ValueChanged<QuestionAttachment> onEditImage;
  final ValueChanged<QuestionAttachment> onRemoveImage;
  final VoidCallback onAddSubQuestion;
  final ValueChanged<int> onEditSubQuestion;
  final ValueChanged<int> onRemoveSubQuestion;
  final VoidCallback onAddInternalChoice;
  final ValueChanged<int> onEditInternalChoice;
  final ValueChanged<int> onRemoveInternalChoice;
  final VoidCallback onEditAnswerSpace;
  final VoidCallback onRemoveAnswerSpace;

  const QuestionAdvancedContentPanel({
    super.key,
    required this.draft,
    required this.onEditStimulus,
    required this.onRemoveStimulus,
    required this.onEditWordBank,
    required this.onRemoveWordBank,
    required this.onEditTable,
    required this.onRemoveTable,
    required this.onAddImage,
    required this.onEditImage,
    required this.onRemoveImage,
    required this.onAddSubQuestion,
    required this.onEditSubQuestion,
    required this.onRemoveSubQuestion,
    required this.onAddInternalChoice,
    required this.onEditInternalChoice,
    required this.onRemoveInternalChoice,
    required this.onEditAnswerSpace,
    required this.onRemoveAnswerSpace,
  });

  bool get _hasAnything =>
      draft.advancedContent.hasAny ||
      draft.tableData != null ||
      draft.attachments.isNotEmpty ||
      draft.subQuestions.isNotEmpty ||
      draft.internalChoices.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasAnything) return const SizedBox.shrink();
    final advanced = draft.advancedContent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Paper blocks',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            Text(
              'Editable',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (advanced.hasStimulus)
          _AdvancedBlockCard(
            icon: Icons.menu_book_outlined,
            title: advanced.stimulus!.kind.label,
            subtitle: advanced.stimulus!.title.trim().isNotEmpty
                ? advanced.stimulus!.title.trim()
                : _compact(advanced.stimulus!.text),
            onEdit: onEditStimulus,
            onRemove: onRemoveStimulus,
            child: Text(
              advanced.stimulus!.text,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (advanced.hasWordBank)
          _AdvancedBlockCard(
            icon: Icons.view_module_outlined,
            title: 'Word bank',
            subtitle: '${advanced.wordBank.length} items',
            onEdit: onEditWordBank,
            onRemove: onRemoveWordBank,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: advanced.wordBank
                  .map(
                    (item) => Chip(
                      label: Text(item),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ),
        if (draft.tableData != null)
          _AdvancedBlockCard(
            icon: Icons.table_chart_outlined,
            title: 'Table / data',
            subtitle: _tableSummary(draft.tableData!),
            onEdit: onEditTable,
            onRemove: onRemoveTable,
            child: _TableMiniPreview(table: draft.tableData!),
          ),
        if (draft.attachments.isNotEmpty)
          _AdvancedBlockCard(
            icon: Icons.image_outlined,
            title: 'Images',
            subtitle: '${draft.attachments.length} attached',
            onEdit: onAddImage,
            editLabel: 'Add',
            onRemove: null,
            child: Column(
              children: [
                for (final attachment in draft.attachments)
                  _ImageAttachmentRow(
                    attachment: attachment,
                    onEdit: () => onEditImage(attachment),
                    onRemove: () => onRemoveImage(attachment),
                  ),
              ],
            ),
          ),
        if (draft.subQuestions.isNotEmpty)
          _AdvancedBlockCard(
            icon: Icons.account_tree_outlined,
            title: 'Question parts',
            subtitle: '${draft.subQuestions.length} structured parts',
            onEdit: onAddSubQuestion,
            editLabel: 'Add',
            onRemove: null,
            child: Column(
              children: [
                for (final entry in draft.subQuestions.asMap().entries)
                  _NestedQuestionRow(
                    label: QuestionAdvancedStructureService.partLabel(
                      entry.key,
                    ),
                    question: entry.value,
                    onEdit: () => onEditSubQuestion(entry.key),
                    onRemove: () => onRemoveSubQuestion(entry.key),
                  ),
              ],
            ),
          ),
        if (draft.internalChoices.isNotEmpty)
          _AdvancedBlockCard(
            icon: Icons.compare_arrows_rounded,
            title: 'Internal OR choice',
            subtitle:
                QuestionAdvancedStructureService.internalChoiceMarksSummary(
                  draft.internalChoices,
                ),
            warning:
                QuestionAdvancedStructureService.internalChoiceMarksBalanced(
                  draft.internalChoices,
                )
                ? null
                : 'Alternatives have different marks.',
            onEdit: onAddInternalChoice,
            editLabel: 'Add',
            onRemove: null,
            child: Column(
              children: [
                for (final entry in draft.internalChoices.asMap().entries) ...[
                  if (entry.key > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'OR',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  _NestedQuestionRow(
                    label: '${entry.key + 1}',
                    question: entry.value,
                    onEdit: () => onEditInternalChoice(entry.key),
                    onRemove: () => onRemoveInternalChoice(entry.key),
                  ),
                ],
              ],
            ),
          ),
        if (advanced.hasAnswerSpace)
          _AdvancedBlockCard(
            icon: Icons.border_bottom_rounded,
            title: 'Answer space',
            subtitle:
                '${advanced.answerSpace.style.label} · ${advanced.answerSpace.lines} lines',
            onEdit: onEditAnswerSpace,
            onRemove: onRemoveAnswerSpace,
            child: _AnswerSpaceMiniPreview(
              style: advanced.answerSpace.style.name,
              lines: advanced.answerSpace.lines,
            ),
          ),
      ],
    );
  }

  String _compact(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact.length <= 90 ? compact : '${compact.substring(0, 87)}…';
  }

  String _tableSummary(QuestionTable table) {
    final columns = table.headers.isNotEmpty
        ? table.headers.length
        : (table.rows.isEmpty ? 0 : table.rows.first.length);
    return '${table.rows.length} rows × $columns columns';
  }
}

class _AdvancedBlockCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? warning;
  final Widget child;
  final VoidCallback? onEdit;
  final String editLabel;
  final VoidCallback? onRemove;

  const _AdvancedBlockCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.warning,
    this.onEdit,
    this.editLabel = 'Edit',
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 21),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onEdit != null)
                  TextButton(onPressed: onEdit, child: Text(editLabel)),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove $title',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            if (warning != null) ...[
              const SizedBox(height: 6),
              Text(
                warning!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _TableMiniPreview extends StatelessWidget {
  final QuestionTable table;

  const _TableMiniPreview({required this.table});

  @override
  Widget build(BuildContext context) {
    final rows = <TableRow>[];
    if (table.headers.isNotEmpty) {
      rows.add(
        TableRow(
          children: table.headers
              .map((cell) => _TableCell(text: cell, bold: true))
              .toList(),
        ),
      );
    }
    for (final row in table.rows.take(3)) {
      rows.add(
        TableRow(children: row.map((cell) => _TableCell(text: cell)).toList()),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 520,
        child: Table(
          border: TableBorder.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          children: rows,
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool bold;

  const _TableCell({required this.text, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
        ),
      ),
    );
  }
}

class _ImageAttachmentRow extends StatelessWidget {
  final QuestionAttachment attachment;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ImageAttachmentRow({
    required this.attachment,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(attachment.path);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: file.existsSync()
            ? Image.file(
                file,
                width: 52,
                height: 46,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 52,
                  height: 46,
                  child: Icon(Icons.broken_image_outlined),
                ),
              )
            : const SizedBox(
                width: 52,
                height: 46,
                child: Icon(Icons.broken_image_outlined),
              ),
      ),
      title: Text(
        attachment.caption.trim().isNotEmpty
            ? attachment.caption.trim()
            : p.basename(attachment.path),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        attachment.alternativeText.trim().isEmpty
            ? 'No accessibility description'
            : attachment.alternativeText.trim(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 0,
        children: [
          IconButton(
            tooltip: 'Edit image',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Remove image',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _NestedQuestionRow extends StatelessWidget {
  final String label;
  final Question question;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _NestedQuestionRow({
    required this.label,
    required this.question,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final text = question.plainTextAccessibility.trim();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 36,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      title: Text(
        text.isEmpty ? 'Math / diagram question part' : text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('${_marks(question.marks)} marks'),
      trailing: Wrap(
        spacing: 0,
        children: [
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  String _marks(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

class _AnswerSpaceMiniPreview extends StatelessWidget {
  final String style;
  final int lines;

  const _AnswerSpaceMiniPreview({required this.style, required this.lines});

  @override
  Widget build(BuildContext context) {
    final shown = lines.clamp(1, 4).toInt();
    if (style == 'box' || style == 'graph') {
      return Container(
        height: shown * 18.0,
        decoration: BoxDecoration(border: Border.all(color: Colors.black26)),
        alignment: Alignment.center,
        child: style == 'graph'
            ? const Text('Graph grid', style: TextStyle(fontSize: 11))
            : null,
      );
    }
    if (style == 'ruled') {
      return Column(
        children: [
          for (var index = 0; index < shown; index++)
            Container(
              height: 18,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black26)),
              ),
            ),
        ],
      );
    }
    return SizedBox(height: shown * 18);
  }
}
