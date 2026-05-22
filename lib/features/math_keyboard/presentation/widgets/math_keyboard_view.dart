import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:edusheet/features/math_keyboard/domain/models/math_symbol.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_key.dart';

class MathKeyboardView extends ConsumerWidget {
  const MathKeyboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mathKeyboardControllerProvider);
    final controller = ref.read(mathKeyboardControllerProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      height: state.height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Persistent Quick Bar (Numbers & Basic Operators)
          _buildQuickBar(context, controller),

          // Navigation Bar (Arrows & Next)
          _buildNavigationBar(context, controller),

          // Drag Handle & Tab Bar
          _buildHeader(context, state, controller),

          // Geometry Specific Toolbar
          if (state.currentCategory == MathCategory.geometry)
            _buildGeometryToolbar(context, state, controller),

          // Symbol Grid
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: state.currentCategory == MathCategory.format
                  ? _buildQuillToolbar(context, state, ref)
                  : _buildSymbolGrid(context, state, controller),
            ),
          ),

          // Action Bar
          const _ActionBar(),
        ],
      ),
    );
  }

  Widget _buildNavigationBar(
    BuildContext context,
    MathKeyboardController controller,
  ) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_left,
            onPressed: () => controller.moveCursorLeft(),
          ),
          const SizedBox(width: 8),
          _NavButton(
            icon: Icons.chevron_right,
            onPressed: () => controller.moveCursorRight(),
          ),
          const Spacer(),
          _NavButton(
            label: 'NEXT FIELD',
            icon: Icons.keyboard_tab,
            onPressed: () => controller.nextField(),
            width: 132,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    MathKeyboardStateData state,
    MathKeyboardController controller,
  ) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: theme.dividerColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: MathCategory.values.length,
              itemBuilder: (context, index) {
                final category = MathCategory.values[index];
                final isSelected = state.currentCategory == category;

                return GestureDetector(
                  onTap: () => controller.setCategory(category),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _categoryLabel(category),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(MathCategory category) {
    return switch (category) {
      MathCategory.basic => 'BASIC',
      MathCategory.functions => 'POWERS',
      MathCategory.trig => 'TRIG',
      MathCategory.calculus => 'CALCULUS',
      MathCategory.geometry => 'GEOMETRY',
      MathCategory.matrices => 'MATRIX',
      MathCategory.greek => 'GREEK',
      MathCategory.operators => 'SIGNS',
      MathCategory.brackets => 'BRACKETS',
      MathCategory.arrows => 'ARROWS',
      MathCategory.sets => 'SETS',
      MathCategory.templates => 'FORMULAS',
      MathCategory.format => 'FORMAT',
      MathCategory.misc => 'MORE',
    };
  }

  Widget _buildQuickBar(
    BuildContext context,
    MathKeyboardController controller,
  ) {
    final quickSymbols = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '0',
      '+',
      '-',
      '×',
      '÷',
      '=',
      'x²',
      '√',
      'a⁄b',
    ];
    final theme = Theme.of(context);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: quickSymbols.length,
        itemBuilder: (context, index) {
          final label = quickSymbols[index];
          final tex = switch (label) {
            '×' => r'\times',
            '÷' => r'\div',
            'x²' => r'^{2}',
            '√' => r'\sqrt{}',
            'a⁄b' => r'\frac{}{}',
            _ => label,
          };

          return Container(
            width: 44,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            child: MathKey(
              label: label,
              tex: tex,
              fontSize: 18,
              color: theme.colorScheme.surface,
              onTap: () => controller.insertText(tex),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGeometryToolbar(
    BuildContext context,
    MathKeyboardStateData state,
    MathKeyboardController controller,
  ) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text('Symbol Size:', style: theme.textTheme.labelSmall),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              onPressed: () =>
                  controller.setSymbolSize(state.symbolSizeLevel - 1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              // Tooltip removed to fix "No Overlay" error
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${state.symbolSizeLevel > 0 ? "+" : ""}${state.symbolSizeLevel}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 18),
              onPressed: () =>
                  controller.setSymbolSize(state.symbolSizeLevel + 1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              // Tooltip removed to fix "No Overlay" error
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () => controller.setSymbolSize(0),
              child: const Text('Reset', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuillToolbar(
    BuildContext context,
    MathKeyboardStateData state,
    WidgetRef ref,
  ) {
    if (state.activeController is! quill.QuillController) {
      return const Center(
        child: Text('Formatting only available for text editors'),
      );
    }

    final controller = ref.read(mathKeyboardControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Define formatting actions for the grid
    final actions = [
      {
        'label': 'Shapes',
        'icon': Icons.category_outlined,
        'onTap': () => _showShapePicker(context, controller),
      },
      {
        'label': 'Text Box',
        'icon': Icons.text_fields_outlined,
        'onTap': () =>
            controller.addFloatingElement(FloatingElementType.textBox),
      },
      {
        'label': 'Bold',
        'icon': Icons.format_bold,
        'onTap': () =>
            state.activeController.toggleAttribute(quill.Attribute.bold),
      },
      {
        'label': 'Italic',
        'icon': Icons.format_italic,
        'onTap': () =>
            state.activeController.toggleAttribute(quill.Attribute.italic),
      },
      {
        'label': 'Under',
        'icon': Icons.format_underlined,
        'onTap': () =>
            state.activeController.toggleAttribute(quill.Attribute.underline),
      },
      {
        'label': 'Strike',
        'icon': Icons.format_strikethrough,
        'onTap': () => state.activeController.toggleAttribute(
          quill.Attribute.strikeThrough,
        ),
      },
      {
        'label': 'Bullet',
        'icon': Icons.format_list_bulleted,
        'onTap': () =>
            state.activeController.toggleAttribute(quill.Attribute.ul),
      },
      {
        'label': 'Number',
        'icon': Icons.format_list_numbered,
        'onTap': () =>
            state.activeController.toggleAttribute(quill.Attribute.ol),
      },
      {
        'label': 'Left',
        'icon': Icons.format_align_left,
        'onTap': () => state.activeController.formatSelection(
          quill.Attribute.leftAlignment,
        ),
      },
      {
        'label': 'Center',
        'icon': Icons.format_align_center,
        'onTap': () => state.activeController.formatSelection(
          quill.Attribute.centerAlignment,
        ),
      },
      {
        'label': 'Right',
        'icon': Icons.format_align_right,
        'onTap': () => state.activeController.formatSelection(
          quill.Attribute.rightAlignment,
        ),
      },
      {
        'label': 'Justify',
        'icon': Icons.format_align_justify,
        'onTap': () => state.activeController.formatSelection(
          quill.Attribute.justifyAlignment,
        ),
      },
    ];

    return Container(
      color: theme.colorScheme.surface,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return MathKey(
            onTap: action['onTap'] as VoidCallback,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  action['icon'] as IconData,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 2),
                Text(
                  action['label'] as String,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showShapePicker(
    BuildContext context,
    MathKeyboardController controller,
  ) {
    final theme = Theme.of(context);
    final shapes = [
      Icons.circle,
      Icons.square,
      Icons.change_history, // Triangle
      Icons.pentagon,
      Icons.hexagon,
      Icons.star,
      Icons.arrow_forward,
      Icons.arrow_back,
      Icons.arrow_upward,
      Icons.arrow_downward,
      Icons.call_made,
      Icons.call_received,
      Icons.favorite,
      Icons.cloud,
      Icons.lightbulb,
      Icons.chat_bubble_outline,
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator:
          false, // Ensure it opens within the keyboard's Navigator
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Insert Shape',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: shapes.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () {
                      controller.addFloatingElement(
                        FloatingElementType.shape,
                        icon: shapes[index],
                      );
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        shapes[index],
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSymbolGrid(
    BuildContext context,
    MathKeyboardStateData state,
    MathKeyboardController controller,
  ) {
    final symbols = mathSymbols
        .where((s) => s.category == state.currentCategory)
        .toList();
    final isTablet =
        MediaQuery.of(context).size.width > 600 || state.isTabletLayout;
    final theme = Theme.of(context);

    // Custom grid settings per category
    final int crossAxisCount;
    final double childAspectRatio;

    if (state.currentCategory == MathCategory.basic) {
      crossAxisCount = isTablet ? 10 : 6;
      childAspectRatio = 1.0;
    } else if (state.currentCategory == MathCategory.templates) {
      crossAxisCount = isTablet ? 4 : 2; // Fewer columns for wide templates
      childAspectRatio = 2.5; // Wider keys for formulas
    } else {
      crossAxisCount = isTablet ? 10 : 6;
      childAspectRatio = 1.0;
    }

    return GridView.builder(
      key: ValueKey(state.currentCategory),
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: symbols.length,
      itemBuilder: (context, index) {
        final symbol = symbols[index];
        final isPowerActive = symbol.label == 'xⁿ' && state.isPowerMode;

        return MathKey(
          symbol: symbol,
          color: isPowerActive ? theme.colorScheme.primaryContainer : null,
          textColor: isPowerActive
              ? theme.colorScheme.onPrimaryContainer
              : null,
          onTap: () {
            if (symbol.label == 'xⁿ') {
              controller.togglePowerMode();
            } else {
              controller.insertText(symbol.tex);
            }
          },
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onPressed;
  final double width;
  final bool isPrimary;

  const _NavButton({
    required this.icon,
    this.label,
    required this.onPressed,
    this.width = 44,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 32,
      width: width,
      child: Material(
        color: isPrimary
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              if (label != null) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label!,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isPrimary
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(mathKeyboardControllerProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
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
            onPressed: () => controller.showSystemKeyboard(),
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
            textColor: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.space_bar,
            onPressed: () => controller.insertText(' '),
            flex: 2,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.backspace_outlined,
            onPressed: () => controller.deleteBackward(),
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.keyboard_return,
            onPressed: () => controller.insertText('\n'),
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
