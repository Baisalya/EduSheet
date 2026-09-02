import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';

class WordShapePickerSheet extends StatelessWidget {
  const WordShapePickerSheet({super.key});

  static Future<WordShapeKind?> show(BuildContext context) {
    return showAdaptiveModalBottomSheet<WordShapeKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => const WordShapePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Insert shape',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Shapes are separate from Geometry and stay editable in Word Mode.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.sizeOf(context).width < 520 ? 2 : 4,
              childAspectRatio: 2.4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final kind in WordShapeKind.values)
                  OutlinedButton.icon(
                    key: ValueKey('word-shape-kind-${kind.name}'),
                    onPressed: () => Navigator.pop(context, kind),
                    icon: Icon(_icon(kind), size: 18),
                    label: Text(kind.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(WordShapeKind kind) => switch (kind) {
    WordShapeKind.rectangle => Icons.crop_square_rounded,
    WordShapeKind.roundedRectangle => Icons.crop_16_9_rounded,
    WordShapeKind.ellipse => Icons.circle_outlined,
    WordShapeKind.line => Icons.horizontal_rule_rounded,
    WordShapeKind.arrow => Icons.arrow_right_alt_rounded,
    WordShapeKind.doubleArrow => Icons.compare_arrows_rounded,
    WordShapeKind.textBox => Icons.text_fields_rounded,
    WordShapeKind.callout => Icons.chat_bubble_outline_rounded,
  };
}
