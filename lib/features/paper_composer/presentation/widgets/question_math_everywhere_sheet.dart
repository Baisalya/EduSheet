import 'package:edusheet/features/paper_composer/application/question_math_surface_service.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_inline_math_editor_sheet.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';

class QuestionMathEverywhereSheet extends StatefulWidget {
  final QuestionDraft initialDraft;

  const QuestionMathEverywhereSheet({super.key, required this.initialDraft});

  static Future<QuestionDraft?> show(
    BuildContext context, {
    required QuestionDraft initialDraft,
  }) {
    return showAdaptiveModalBottomSheet<QuestionDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: QuestionMathEverywhereSheet(initialDraft: initialDraft),
      ),
    );
  }

  @override
  State<QuestionMathEverywhereSheet> createState() =>
      _QuestionMathEverywhereSheetState();
}

class _QuestionMathEverywhereSheetState
    extends State<QuestionMathEverywhereSheet> {
  static const _service = QuestionMathSurfaceService();
  late QuestionDraft _draft;

  @override
  void initState() {
    super.initState();
    final current = _service.currentSurfaceText(widget.initialDraft);
    _draft = widget.initialDraft.copyWith(
      mathContent: widget.initialDraft.mathContent.retainMatching(current),
    );
  }

  Future<void> _edit(QuestionMathSurfaceDescriptor descriptor) async {
    final active = _draft.mathContent.documentFor(
      descriptor.key,
      currentFallback: descriptor.fallbackText,
    );
    final document = await QuestionInlineMathEditorSheet.show(
      context,
      title: descriptor.label,
      fallbackText: descriptor.fallbackText,
      initialDocument: active,
    );
    if (document == null || !mounted) return;
    setState(() {
      _draft = _service.applyDocument(_draft, descriptor.key, document);
    });
  }

  void _removeMath(QuestionMathSurfaceDescriptor descriptor) {
    setState(() {
      _draft = _service.removeDocument(_draft, descriptor.key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final descriptors = _service.descriptorsForDraft(_draft);
    final grouped = <String, List<QuestionMathSurfaceDescriptor>>{};
    for (final descriptor in descriptors) {
      grouped.putIfAbsent(descriptor.group, () => []).add(descriptor);
    }
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Math everywhere'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_draft),
            child: const Text('Done'),
          ),
        ],
      ),
      body: descriptors.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Add options, a stimulus, table, word bank, image caption, or question details first. Their text fields will appear here.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Text(
                  'Use structured formulas inside fields that historically store only text. EduSheet keeps each field’s readable string as the compatibility fallback, while the richer math sequence is stored in namespaced question metadata.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.functions_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '${_draft.mathContent.structuredSurfaceCount} structured math field${_draft.mathContent.structuredSurfaceCount == 1 ? '' : 's'}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final group in grouped.entries) ...[
                  Text(
                    group.key,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final descriptor in group.value)
                    _SurfaceTile(
                      descriptor: descriptor,
                      hasMath:
                          _draft.mathContent.documentFor(
                            descriptor.key,
                            currentFallback: descriptor.fallbackText,
                          ) !=
                          null,
                      onEdit: () => _edit(descriptor),
                      onRemoveMath: () => _removeMath(descriptor),
                    ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
    );
  }
}

class _SurfaceTile extends StatelessWidget {
  final QuestionMathSurfaceDescriptor descriptor;
  final bool hasMath;
  final VoidCallback onEdit;
  final VoidCallback onRemoveMath;

  const _SurfaceTile({
    required this.descriptor,
    required this.hasMath,
    required this.onEdit,
    required this.onRemoveMath,
  });

  @override
  Widget build(BuildContext context) {
    final preview = descriptor.fallbackText.trim().isEmpty
        ? 'Empty field'
        : descriptor.fallbackText.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      child: ListTile(
        onTap: onEdit,
        leading: Icon(
          hasMath ? Icons.functions_rounded : Icons.text_fields_rounded,
        ),
        title: Text(descriptor.label),
        subtitle: Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasMath)
              IconButton(
                tooltip: 'Use plain text only',
                onPressed: onRemoveMath,
                icon: const Icon(Icons.format_clear_rounded),
              ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
