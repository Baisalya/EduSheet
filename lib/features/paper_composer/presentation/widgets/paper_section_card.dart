import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_card.dart';
import 'package:flutter/material.dart';

class PaperSectionCard extends StatelessWidget {
  final PaperSection section;
  final int sectionNumber;
  final VoidCallback onAddQuestion;
  final ValueChanged<Question> onEditQuestion;
  final ValueChanged<Question> onDuplicateQuestion;
  final ValueChanged<Question> onDeleteQuestion;
  final Key Function(Question question)? questionKeyFor;
  final VoidCallback onRename;
  final VoidCallback onEditInstruction;
  final VoidCallback onDuplicateSection;
  final VoidCallback onDeleteSection;

  const PaperSectionCard({
    super.key,
    required this.section,
    required this.sectionNumber,
    required this.onAddQuestion,
    required this.onEditQuestion,
    required this.onDuplicateQuestion,
    required this.onDeleteQuestion,
    this.questionKeyFor,
    required this.onRename,
    required this.onEditInstruction,
    required this.onDuplicateSection,
    required this.onDeleteSection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title.trim().isEmpty
                            ? 'Section $sectionNumber'
                            : section.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${section.questions.length} question${section.questions.length == 1 ? '' : 's'} · ${_marks(section.totalMarks)} marks',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (section.instruction?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text(
                          section.instruction!.trim(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<_SectionAction>(
                  tooltip: 'Section actions',
                  onSelected: (value) {
                    switch (value) {
                      case _SectionAction.rename:
                        onRename();
                        break;
                      case _SectionAction.instruction:
                        onEditInstruction();
                        break;
                      case _SectionAction.duplicate:
                        onDuplicateSection();
                        break;
                      case _SectionAction.delete:
                        onDeleteSection();
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _SectionAction.rename,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.drive_file_rename_outline_rounded),
                        title: Text('Rename section'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _SectionAction.instruction,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.notes_rounded),
                        title: Text('Section instruction'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _SectionAction.duplicate,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.copy_rounded),
                        title: Text('Duplicate section'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _SectionAction.delete,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Delete section'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: section.questions.isEmpty
                ? _EmptySection(onAddQuestion: onAddQuestion)
                : Column(
                    children: [
                      for (final entry in section.questions.asMap().entries)
                        QuestionCard(
                          key: questionKeyFor?.call(entry.value) ?? ValueKey(entry.value.id),
                          question: entry.value,
                          number: entry.key + 1,
                          onEdit: () => onEditQuestion(entry.value),
                          onDuplicate: () => onDuplicateQuestion(entry.value),
                          onDelete: () => onDeleteQuestion(entry.value),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: OutlinedButton.icon(
              onPressed: onAddQuestion,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add question'),
            ),
          ),
        ],
      ),
    );
  }

  static String _marks(double marks) {
    return marks == marks.roundToDouble()
        ? marks.toInt().toString()
        : marks.toStringAsFixed(1);
  }
}

enum _SectionAction { rename, instruction, duplicate, delete }

class _EmptySection extends StatelessWidget {
  final VoidCallback onAddQuestion;

  const _EmptySection({required this.onAddQuestion});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 18),
      child: Column(
        children: [
          Icon(
            Icons.edit_note_rounded,
            size: 38,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          const Text(
            'Start with the first question',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Type normally, or insert mathematics and geometry when you need them.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAddQuestion,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Write question'),
          ),
        ],
      ),
    );
  }
}
