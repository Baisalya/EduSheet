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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Horizontal space, not keyboard height, decides whether teacher-facing
        // labels fit. A wide Windows keyboard can be vertically compact after
        // resizing and should still remain self-explanatory.
        final width = constraints.maxWidth;
        final showWideLabels = width >= 620;
        final showEssentialLabels = width >= 430;
        final showTextLabel = width >= 460;

        return Container(
          height: compact ? 52 : 60,
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
                icon: Icons.keyboard_rounded,
                label: showTextLabel ? 'Text' : null,
                tooltip: 'Switch to normal text keyboard',
                onPressed: controller.showSystemKeyboard,
                color: theme.colorScheme.secondaryContainer.withValues(
                  alpha: 0.75,
                ),
                textColor: theme.colorScheme.onSecondaryContainer,
                flex: showTextLabel ? 2 : 1,
              ),
              const SizedBox(width: 5),
              _ActionButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Move typing position left',
                onPressed: controller.moveCursorLeft,
              ),
              const SizedBox(width: 5),
              _ActionButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Move typing position right',
                onPressed: controller.moveCursorRight,
              ),
              const SizedBox(width: 5),
              _ActionButton(
                icon: Icons.space_bar_rounded,
                label: showWideLabels ? 'Space' : null,
                tooltip: 'Insert a space',
                onPressed: () => controller.insertText(' '),
                flex: 2,
              ),
              const SizedBox(width: 5),
              _ActionButton(
                icon: Icons.backspace_outlined,
                tooltip: 'Delete before typing position',
                onPressed: controller.deleteBackward,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(width: 5),
              _ActionButton(
                icon: Icons.keyboard_tab_rounded,
                label: showEssentialLabels ? 'Next box' : null,
                tooltip:
                    'Move to the next fraction, power, root, or formula box',
                onPressed: controller.nextField,
                color: theme.colorScheme.primary,
                textColor: theme.colorScheme.onPrimary,
                flex: showEssentialLabels ? 3 : 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;
  final int flex;

  const _ActionButton({
    required this.icon,
    this.label,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.textColor,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = textColor ?? theme.colorScheme.onSurfaceVariant;

    return Expanded(
      flex: flex,
      child: Semantics(
        button: true,
        label: label ?? tooltip,
        hint: label == null ? tooltip : null,
        onTap: onPressed,
        child: ExcludeSemantics(
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              height: 48,
              child: Material(
                color: color ?? theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                    child: label == null
                        ? Icon(icon, size: 22, color: foreground)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 19, color: foreground),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  label!,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: foreground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
