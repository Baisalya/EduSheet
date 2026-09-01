import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_field.dart';
import 'package:edusheet/features/paper_composer/application/question_insertion_anchor.dart';
import 'package:flutter/material.dart';

class QuestionMarksControl extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const QuestionMarksControl({
    super.key,
    required this.controller,
    required this.errorText,
    required this.onChanged,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Reduce marks',
          onPressed: onDecrease,
          icon: const Icon(Icons.remove_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: 'Marks',
              errorText: errorText,
              isDense: true,
            ),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Increase marks',
          onPressed: onIncrease,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class QuestionInsertAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const QuestionInsertAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilledButton.tonalIcon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class QuestionOptionEditor extends StatelessWidget {
  final int index;
  final QuestionOption option;
  final TextEditingController controller;
  final bool canRemove;
  final VoidCallback onToggleCorrect;
  final VoidCallback onRemove;

  const QuestionOptionEditor({
    super.key,
    required this.index,
    required this.option,
    required this.controller,
    required this.canRemove,
    required this.onToggleCorrect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            tooltip: option.isCorrect ? 'Marked correct' : 'Mark as correct',
            onPressed: onToggleCorrect,
            icon: Icon(
              option.isCorrect
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: option.isCorrect
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          Expanded(
            child: MathKeyboardField(
              controller: controller,
              builder: (context, focusNode, isMathActive) => TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: isMathActive
                    ? TextInputType.none
                    : TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'Option ${String.fromCharCode(65 + index)}',
                  isDense: true,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove option',
            onPressed: canRemove ? onRemove : null,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class ComposerErrorText extends StatelessWidget {
  final String message;

  const ComposerErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class QuestionInsertionStatus extends StatelessWidget {
  final QuestionInsertionAnchor anchor;
  final bool isFocused;
  final bool compact;
  final VoidCallback onTap;

  const QuestionInsertionStatus({
    super.key,
    required this.anchor,
    required this.isFocused,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = isFocused ? scheme.primary : scheme.onSurfaceVariant;
    final background = isFocused
        ? scheme.primaryContainer.withValues(alpha: 0.55)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final title = anchor.hasSelection
        ? '${anchor.length} selected · line ${anchor.lineNumber}'
        : '${isFocused ? 'Typing here' : 'Cursor saved'} · line ${anchor.lineNumber}, pos ${anchor.columnNumber}';

    return Tooltip(
      message: '${anchor.actionLabel}\n${anchor.contextLabel}',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          key: const ValueKey('question-insertion-status'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 11,
              vertical: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  anchor.hasSelection
                      ? Icons.select_all_rounded
                      : Icons.my_location_rounded,
                  size: 15,
                  color: foreground,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuestionMobileAuthoringToolbar extends StatelessWidget {
  final QuestionInsertionAnchor anchor;
  final bool formattingActive;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onReturnToCursor;
  final VoidCallback onAdd;
  final VoidCallback onMath;
  final VoidCallback onGeometry;
  final VoidCallback onFormat;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  const QuestionMobileAuthoringToolbar({
    super.key,
    required this.anchor,
    required this.formattingActive,
    required this.canUndo,
    required this.canRedo,
    required this.onReturnToCursor,
    required this.onAdd,
    required this.onMath,
    required this.onGeometry,
    required this.onFormat,
    required this.onUndo,
    required this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const ValueKey('question-sticky-insertion-anchor'),
          onTap: onReturnToCursor,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Row(
              children: [
                Icon(Icons.place_outlined, size: 15, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Question tools use: ${anchor.compactLocation}',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'Return',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 40,
          child: SingleChildScrollView(
            key: const ValueKey('question-mobile-authoring-tools'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuestionAuthoringTool(
                  icon: Icons.add_rounded,
                  label: 'Add',
                  onPressed: onAdd,
                  emphasized: true,
                ),
                _QuestionAuthoringTool(
                  icon: Icons.functions_rounded,
                  label: 'Math',
                  onPressed: onMath,
                ),
                _QuestionAuthoringTool(
                  icon: Icons.category_outlined,
                  label: 'Geometry',
                  onPressed: onGeometry,
                ),
                _QuestionAuthoringTool(
                  icon: Icons.format_bold_rounded,
                  label: 'Format',
                  onPressed: onFormat,
                  selected: formattingActive,
                ),
                _QuestionAuthoringTool(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  onPressed: canUndo ? onUndo : null,
                ),
                _QuestionAuthoringTool(
                  icon: Icons.redo_rounded,
                  label: 'Redo',
                  onPressed: canRedo ? onRedo : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionAuthoringTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool emphasized;
  final bool selected;

  const _QuestionAuthoringTool({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.emphasized = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = emphasized || selected
        ? FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: Icon(icon, size: 17),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 17),
            label: Text(label),
          );
    return Padding(padding: const EdgeInsets.only(right: 7), child: button);
  }
}
