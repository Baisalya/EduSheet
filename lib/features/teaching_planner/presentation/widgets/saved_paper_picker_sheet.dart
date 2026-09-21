import 'package:flutter/material.dart';

import '../../../editor/domain/models/paper_model.dart';
import '../../../../shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import '../design/teaching_planner_design_system.dart';
import 'teaching_planner_shared_components.dart';

class SavedPaperPickerSheet extends StatefulWidget {
  const SavedPaperPickerSheet({super.key, required this.papers});

  final List<Paper> papers;

  static Future<Paper?> show(
    BuildContext context, {
    required List<Paper> papers,
  }) {
    return showAdaptiveModalBottomSheet<Paper>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.78,
        child: SavedPaperPickerSheet(papers: papers),
      ),
    );
  }

  @override
  State<SavedPaperPickerSheet> createState() => _SavedPaperPickerSheetState();
}

class _SavedPaperPickerSheetState extends State<SavedPaperPickerSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _query.trim().toLowerCase();
    final papers =
        widget.papers
            .where((paper) {
              if (normalized.isEmpty) return true;
              final haystack = <String>[
                paper.title,
                paper.schoolName,
                ...paper.headerFields.map(
                  (field) => '${field.label} ${field.value}',
                ),
              ].join(' ').toLowerCase();
              return haystack.contains(normalized);
            })
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TeachingPlannerSectionHeader(
            title: 'Choose a saved paper',
            subtitle:
                'Select a paper you already made in EduSheet. The original paper stays in Saved Papers.',
            icon: Icons.description_outlined,
          ),
          const SizedBox(height: TeachingPlannerDesign.space12),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Search papers',
              hintText: 'Paper title, class or subject',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: TeachingPlannerDesign.space12),
          Expanded(
            child: papers.isEmpty
                ? Center(
                    child: Text(
                      widget.papers.isEmpty
                          ? 'No saved papers yet. Create a new paper first.'
                          : 'No papers match your search.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: papers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final paper = papers[index];
                      final className = _headerValue(paper, 'Class');
                      final subject = _headerValue(paper, 'Subject');
                      final details = <String>[
                        if (className.isNotEmpty) className,
                        if (subject.isNotEmpty) subject,
                        '${paper.totalMarks.toStringAsFixed(0)} marks',
                      ];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.description_outlined),
                          ),
                          title: Text(
                            paper.title.trim().isEmpty
                                ? 'Untitled Paper'
                                : paper.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            details.join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.add_link_rounded),
                          onTap: () => Navigator.of(context).pop(paper),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _headerValue(Paper paper, String label) {
    final target = label.toLowerCase();
    for (final field in paper.headerFields) {
      if (field.label.trim().toLowerCase() == target) {
        return field.value.trim();
      }
    }
    return '';
  }
}
