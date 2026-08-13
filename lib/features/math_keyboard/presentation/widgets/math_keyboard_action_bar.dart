import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';

class MathKeyboardActionBar extends ConsumerWidget {
  final bool compact;

  const MathKeyboardActionBar({super.key, required this.compact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(mathKeyboardControllerProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      height: compact ? 52 : 58,
      padding: EdgeInsets.fromLTRB(7, 5, 7, compact ? 5 : 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          _ActionButton(
            label: 'ABC',
            onPressed: controller.showSystemKeyboard,
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.75),
            textColor: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 5),
          _ActionButton(
            icon: Icons.chevron_left_rounded,
            onPressed: controller.moveCursorLeft,
          ),
          const SizedBox(width: 5),
          _ActionButton(
            icon: Icons.chevron_right_rounded,
            onPressed: controller.moveCursorRight,
          ),
          const SizedBox(width: 5),
          _ActionButton(
            icon: Icons.space_bar_rounded,
            onPressed: () => controller.insertText(' '),
            flex: 3,
          ),
          const SizedBox(width: 5),
          _ActionButton(
            icon: Icons.backspace_outlined,
            onPressed: controller.deleteBackward,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(width: 5),
          _ActionButton(
            icon: Icons.keyboard_tab_rounded,
            onPressed: controller.nextField,
            color: theme.colorScheme.primary,
            textColor: theme.colorScheme.onPrimary,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;
  final int flex;

  const _ActionButton({
    this.icon,
    this.label,
    required this.onPressed,
    this.color,
    this.textColor,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      flex: flex,
      child: SizedBox(
        height: 48,
        child: Material(
          color: color ?? theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: label != null
                  ? Text(
                      label!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor ?? theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.1,
                      ),
                    )
                  : Icon(
                      icon,
                      size: 22,
                      color: textColor ?? theme.colorScheme.onSurfaceVariant,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
