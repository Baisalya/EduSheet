import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:flutter/material.dart';

class PaperInspectorPanel extends StatelessWidget {
  final Paper paper;
  final VoidCallback onEditDetails;
  final VoidCallback onChooseStyle;
  final VoidCallback onPreview;
  final VoidCallback onPrintPreview;

  const PaperInspectorPanel({
    super.key,
    required this.paper,
    required this.onEditDetails,
    required this.onChooseStyle,
    required this.onPreview,
    required this.onPrintPreview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questionCount = paper.sections.fold<int>(
      0,
      (sum, section) => sum + section.questions.length,
    );

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
          _Metric(label: 'Current marks', value: _marks(paper.totalMarks)),
          if (paper.maximumMarks != null)
            _Metric(label: 'Maximum marks', value: _marks(paper.maximumMarks!)),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.tune_rounded,
            title: 'Paper details',
            subtitle: 'Title, school, instructions',
            onTap: onEditDetails,
          ),
          _ActionTile(
            icon: Icons.style_outlined,
            title: 'Paper style',
            subtitle: 'Printed layout only',
            onTap: onChooseStyle,
          ),
          _ActionTile(
            icon: Icons.visibility_outlined,
            title: 'Preview',
            subtitle: 'Read the paper before export',
            onTap: onPreview,
          ),
          _ActionTile(
            icon: Icons.picture_as_pdf_outlined,
            title: 'PDF / print preview',
            subtitle: 'Use the existing export renderer',
            onTap: onPrintPreview,
          ),
        ],
      ),
    );
  }

  static String _marks(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
