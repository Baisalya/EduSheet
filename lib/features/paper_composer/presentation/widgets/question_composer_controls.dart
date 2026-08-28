import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_field.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';
import 'package:flutter/material.dart';

class QuestionTypeControl extends StatelessWidget {
  final QuestionType type;
  final VoidCallback onTap;

  const QuestionTypeControl({
    super.key,
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(type.composerIcon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Question type',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }
}

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
