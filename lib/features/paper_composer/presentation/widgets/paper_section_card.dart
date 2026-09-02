import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/paper_structure_service.dart';
import 'package:edusheet/features/editor/services/question_numbering_service.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_card.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';

class PaperSectionCard extends StatelessWidget {
  final PaperSection section;
  final int sectionNumber;
  final QuestionNumberStyle paperNumberingStyle;
  final List<String> customQuestionNumberLabels;
  final VoidCallback onAddQuestion;
  final VoidCallback onAddFromBank;
  final ValueChanged<Question> onEditQuestion;
  final ValueChanged<Question> onDuplicateQuestion;
  final ValueChanged<Question> onDeleteQuestion;
  final ValueChanged<Question> onSaveQuestionToBank;
  final Key Function(Question question)? questionKeyFor;
  final VoidCallback onRename;
  final VoidCallback onEditInstruction;
  final VoidCallback? onEditStructure;
  final ReorderCallback? onReorderQuestions;
  final int? sectionReorderIndex;
  final VoidCallback onDuplicateSection;
  final VoidCallback onDeleteSection;

  const PaperSectionCard({
    super.key,
    required this.section,
    required this.sectionNumber,
    this.paperNumberingStyle = QuestionNumberStyle.number,
    this.customQuestionNumberLabels = const [],
    required this.onAddQuestion,
    required this.onAddFromBank,
    required this.onEditQuestion,
    required this.onDuplicateQuestion,
    required this.onDeleteQuestion,
    required this.onSaveQuestionToBank,
    this.questionKeyFor,
    required this.onRename,
    required this.onEditInstruction,
    this.onEditStructure,
    this.onReorderQuestions,
    this.sectionReorderIndex,
    required this.onDuplicateSection,
    required this.onDeleteSection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberingStyle = section.numberingStyle ?? paperNumberingStyle;
    final assessmentQuestionCount =
        PaperStructureService.assessmentQuestionCount(section);
    final totalMarks = section.totalMarks;
    final answerAny =
        section.requiredCount != null &&
        section.requiredCount! > 0 &&
        section.requiredCount! <
            section.questions.where((question) => !question.isOptional).length;

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
                        '$assessmentQuestionCount question${assessmentQuestionCount == 1 ? '' : 's'} · ${_marks(totalMarks)} ${totalMarks == 1 ? 'mark' : 'marks'}',
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
                      if (section.questions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _SectionMetaChip(
                              icon: Icons.format_list_numbered_rounded,
                              label: QuestionNumberingService.displayName(
                                numberingStyle,
                              ),
                            ),
                            if (answerAny)
                              _SectionMetaChip(
                                icon: Icons.rule_rounded,
                                label: 'Answer any ${section.requiredCount}',
                              ),
                            if (section.defaultMarks != null)
                              _SectionMetaChip(
                                icon: Icons.auto_awesome_outlined,
                                label:
                                    '${_marks(section.defaultMarks!)} default marks',
                              ),
                            if (section.answerSpaceLines > 0)
                              _SectionMetaChip(
                                icon: Icons.horizontal_rule_rounded,
                                label:
                                    '${section.answerSpaceLines} answer lines',
                              ),
                            if (section.pageBreakBefore)
                              const _SectionMetaChip(
                                icon: Icons.insert_page_break_outlined,
                                label: 'New page',
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (sectionReorderIndex != null)
                  ReorderableDragStartListener(
                    index: sectionReorderIndex!,
                    child: const Tooltip(
                      message: 'Drag section to reorder',
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 10,
                        ),
                        child: Icon(Icons.drag_indicator_rounded),
                      ),
                    ),
                  ),
                PopupMenuButton<_SectionAction>(
                  tooltip: 'Section actions',
                  onSelected: (value) {
                    switch (value) {
                      case _SectionAction.format:
                        onEditStructure?.call();
                        break;
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
                  itemBuilder: (context) => [
                    if (onEditStructure != null)
                      const PopupMenuItem(
                        value: _SectionAction.format,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.tune_rounded),
                          title: Text('Format section'),
                          subtitle: Text(
                            'Answer rule, numbering, defaults and answer space',
                          ),
                        ),
                      ),
                    const PopupMenuItem(
                      value: _SectionAction.rename,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.drive_file_rename_outline_rounded),
                        title: Text('Rename section'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: _SectionAction.instruction,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.notes_rounded),
                        title: Text('Section instruction'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: _SectionAction.duplicate,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.copy_rounded),
                        title: Text('Duplicate section'),
                      ),
                    ),
                    const PopupMenuItem(
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
                ? _EmptySection(
                    onAddQuestion: onAddQuestion,
                    onAddFromBank: onAddFromBank,
                  )
                : ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: section.questions.length,
                    onReorderItem: (oldIndex, newIndex) {
                      final callback = onReorderQuestions;
                      if (callback == null) return;
                      // Keep the existing editor/provider reorder contract
                      // stable while using Flutter's non-deprecated callback.
                      final legacyNewIndex = newIndex > oldIndex
                          ? newIndex + 1
                          : newIndex;
                      callback(oldIndex, legacyNewIndex);
                    },
                    itemBuilder: (context, index) {
                      final question = section.questions[index];
                      final ordinal =
                          PaperStructureService.numberedQuestionOrdinal(
                            section,
                            index,
                          );
                      final label = question.isWordContentBlock
                          ? ''
                          : QuestionNumberingService.label(
                              ordinal,
                              numberingStyle,
                              customLabels: customQuestionNumberLabels,
                            );
                      return QuestionCard(
                        key:
                            questionKeyFor?.call(question) ??
                            ValueKey(question.id),
                        question: question,
                        number: ordinal,
                        numberLabel: label,
                        reorderIndex: onReorderQuestions == null ? null : index,
                        onEdit: () => onEditQuestion(question),
                        onDuplicate: () => onDuplicateQuestion(question),
                        onDelete: () => onDeleteQuestion(question),
                        onSaveToBank: () => onSaveQuestionToBank(question),
                      );
                    },
                  ),
          ),
          if (section.questions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 520) {
                    return OutlinedButton.icon(
                      onPressed: () => _showCompactAddMenu(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add question'),
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onAddQuestion,
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text('New question'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onAddFromBank,
                          icon: const Icon(Icons.inventory_2_outlined),
                          label: const Text('Question Bank'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showCompactAddMenu(BuildContext context) async {
    final action = await showAdaptiveModalBottomSheet<_AddQuestionAction>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('New question'),
              subtitle: const Text(
                'Write a question with Math, Geometry or scan text.',
              ),
              onTap: () =>
                  Navigator.pop(context, _AddQuestionAction.newQuestion),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('From Question Bank'),
              subtitle: const Text('Choose one or several reusable questions.'),
              onTap: () => Navigator.pop(context, _AddQuestionAction.bank),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case _AddQuestionAction.newQuestion:
        onAddQuestion();
        break;
      case _AddQuestionAction.bank:
        onAddFromBank();
        break;
      case null:
        break;
    }
  }

  static String _marks(double marks) {
    return marks == marks.roundToDouble()
        ? marks.toInt().toString()
        : marks.toStringAsFixed(1);
  }
}

enum _SectionAction { format, rename, instruction, duplicate, delete }

class _SectionMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionMetaChip({required this.icon, required this.label});

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
          Icon(icon, size: 13),
          const SizedBox(width: 4),
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

class _EmptySection extends StatelessWidget {
  final VoidCallback onAddQuestion;
  final VoidCallback onAddFromBank;

  const _EmptySection({
    required this.onAddQuestion,
    required this.onAddFromBank,
  });

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
            'How do you want to start?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Write a fresh question or reuse questions you already trust.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onAddQuestion,
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Write question'),
              ),
              OutlinedButton.icon(
                onPressed: onAddFromBank,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Choose from bank'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _AddQuestionAction { newQuestion, bank }
