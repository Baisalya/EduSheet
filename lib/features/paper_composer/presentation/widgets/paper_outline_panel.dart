import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:flutter/material.dart';

class PaperOutlinePanel extends StatelessWidget {
  final Paper paper;
  final ValueChanged<String> onSelectSection;
  final void Function(String sectionId, String questionId) onSelectQuestion;
  final VoidCallback onAddSection;

  const PaperOutlinePanel({
    super.key,
    required this.paper,
    required this.onSelectSection,
    required this.onSelectQuestion,
    required this.onAddSection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 10, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'OUTLINE',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Add section',
                  visualDensity: VisualDensity.compact,
                  onPressed: onAddSection,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: paper.sections.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'Add a section to start writing questions.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                    itemCount: paper.sections.length,
                    itemBuilder: (context, sectionIndex) {
                      final section = paper.sections[sectionIndex];
                      return _OutlineSection(
                        section: section,
                        sectionNumber: sectionIndex + 1,
                        onSelectSection: () => onSelectSection(section.id),
                        onSelectQuestion: (questionId) =>
                            onSelectQuestion(section.id, questionId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _OutlineSection extends StatelessWidget {
  final PaperSection section;
  final int sectionNumber;
  final VoidCallback onSelectSection;
  final ValueChanged<String> onSelectQuestion;

  const _OutlineSection({
    required this.section,
    required this.sectionNumber,
    required this.onSelectSection,
    required this.onSelectQuestion,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.only(left: 14, bottom: 6),
        leading: const Icon(Icons.folder_outlined, size: 20),
        title: Text(
          section.title.trim().isEmpty
              ? 'Section $sectionNumber'
              : section.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        subtitle: Text(
          '${section.questions.length} question${section.questions.length == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        onExpansionChanged: (expanded) {
          if (expanded) onSelectSection();
        },
        children: [
          for (final entry in section.questions.asMap().entries)
            ListTile(
              dense: true,
              minTileHeight: 36,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: SizedBox(
                width: 20,
                child: Text(
                  '${entry.key + 1}.',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              title: Text(
                entry.value.plainTextAccessibility.trim().isEmpty
                    ? 'Untitled question'
                    : entry.value.plainTextAccessibility.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => onSelectQuestion(entry.value.id),
            ),
        ],
      ),
    );
  }
}
