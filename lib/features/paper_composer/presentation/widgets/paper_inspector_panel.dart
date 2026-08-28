import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/application/paper_marks_resolver.dart';
import 'package:edusheet/features/pdf/application/paper_template_resolver.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaperInspectorPanel extends ConsumerWidget {
  final Paper paper;
  final VoidCallback onEditDetails;
  final VoidCallback onChooseStyle;
  final VoidCallback onPreview;
  final VoidCallback onExportPdf;
  final VoidCallback onExportWord;

  const PaperInspectorPanel({
    super.key,
    required this.paper,
    required this.onEditDetails,
    required this.onChooseStyle,
    required this.onPreview,
    required this.onExportPdf,
    required this.onExportWord,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final questionCount = paper.sections.fold<int>(
      0,
      (sum, section) => sum + section.questions.length,
    );
    final marks = PaperMarksResolver.summarize(paper);
    final template = PaperTemplateResolver.resolve(
      paper.templateId,
      ref.watch(templateProvider).all,
    );
    final headerComplete =
        paper.schoolName.trim().isNotEmpty &&
        paper.title.trim().isNotEmpty &&
        paper.title.trim() != 'New Paper' &&
        _fieldValue(paper, 'Subject').isNotEmpty &&
        _fieldValue(paper, 'Class').isNotEmpty;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'PAPER',
            style: theme.textTheme.labelMedium?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _Metric(label: 'Sections', value: '${paper.sections.length}'),
          _Metric(label: 'Questions', value: '$questionCount'),
          _Metric(
            label: 'Assigned marks',
            value: PaperMarksResolver.format(marks.assignedMarks),
          ),
          _Metric(
            label: 'Maximum marks',
            value: PaperMarksResolver.format(marks.effectiveMaximumMarks),
          ),
          const SizedBox(height: 12),
          _StatusLine(
            ok: headerComplete,
            text: headerComplete
                ? 'Header details ready'
                : 'Paper setup needs details',
          ),
          _StatusLine(
            ok: !marks.hasMismatch,
            text: marks.teacherMessage ?? 'Marks balanced',
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '${template.paperSize.name.toUpperCase()} · ${template.paperLayout == PaperLayout.standard ? 'Single column' : 'Two columns'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.assignment_outlined,
            title: 'Paper setup',
            subtitle: 'Institution, exam details and instructions',
            onTap: onEditDetails,
          ),
          _ActionTile(
            icon: Icons.style_outlined,
            title: 'Appearance',
            subtitle: 'Choose a professional print style',
            onTap: onChooseStyle,
          ),
          _ActionTile(
            icon: Icons.visibility_outlined,
            title: 'Preview',
            subtitle: 'Check layout and questions together',
            onTap: onPreview,
          ),
          _ActionTile(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Export PDF',
            subtitle: 'Create the print-ready paper',
            onTap: onExportPdf,
          ),
          _ActionTile(
            icon: Icons.description_outlined,
            title: 'Export Word (.docx)',
            subtitle: 'Create the editable teacher copy',
            onTap: onExportWord,
          ),
        ],
      ),
    );
  }

  static String _fieldValue(Paper paper, String label) {
    final target = label.toLowerCase();
    for (final field in paper.headerFields) {
      if (field.label.trim().toLowerCase() == target && !field.isPlaceholder) {
        return field.value.trim();
      }
    }
    return '';
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final bool ok;
  final String text;

  const _StatusLine({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            size: 17,
            color: ok ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
