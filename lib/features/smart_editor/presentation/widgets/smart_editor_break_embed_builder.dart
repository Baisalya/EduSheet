import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class SmartEditorBreakEmbedBuilder extends EmbedBuilder {
  static const keyName = 'smartBreak';

  @override
  String get key => keyName;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final type = embedContext.node.value.data?.toString() ?? 'page';
    final section = type == 'section';
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant,
              thickness: section ? 1 : 1.4,
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            section
                ? Icons.segment_rounded
                : Icons.insert_page_break_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            section ? 'Section break' : 'Page break',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant,
              thickness: section ? 1 : 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
