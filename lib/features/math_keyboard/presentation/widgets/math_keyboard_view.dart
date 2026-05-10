import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          // Drag Handle & Tab Bar
          _buildHeader(context, state, controller),

          // Symbol Grid
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildSymbolGrid(context, state, controller),
            ),
          ),

          // Action Bar
          const _ActionBar(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, MathKeyboardStateData state, MathKeyboardController controller) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: MathCategory.values.map((category) {
              final isSelected = state.currentCategory == category;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(
                    category.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) controller.setCategory(category);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildSymbolGrid(BuildContext context, MathKeyboardStateData state, MathKeyboardController controller) {
    final symbols = mathSymbols.where((s) => s.category == state.currentCategory).toList();
    final isTablet = MediaQuery.of(context).size.width > 600 || state.isTabletLayout;
    final theme = Theme.of(context);
    
    // High density for BASIC category
    final int crossAxisCount;
    if (state.currentCategory == MathCategory.basic) {
      crossAxisCount = isTablet ? 12 : 8; // Denser grid for basic
    } else {
      crossAxisCount = isTablet ? 12 : 6;
    }
    
    return GridView.builder(
      key: ValueKey(state.currentCategory),
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: symbols.length,
      itemBuilder: (context, index) {
        final symbol = symbols[index];
        final isPowerActive = symbol.label == 'xⁿ' && state.isPowerMode;
        
        return MathKey(
          symbol: symbol,
          color: isPowerActive ? theme.colorScheme.primaryContainer : null,
          textColor: isPowerActive ? theme.colorScheme.onPrimaryContainer : null,
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

class _ActionBar extends ConsumerWidget {
  const _ActionBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(mathKeyboardControllerProvider.notifier);
    final state = ref.watch(mathKeyboardControllerProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          _ActionButton(
            label: 'ABC',
            onPressed: () => controller.showSystemKeyboard(),
            color: theme.colorScheme.secondaryContainer,
            textColor: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.tablet_android,
            onPressed: () => controller.toggleTabletLayout(),
            color: state.isTabletLayout ? theme.colorScheme.primaryContainer : null,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.space_bar,
            onPressed: () => controller.insertText(' '),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.backspace_outlined,
            onPressed: () => controller.deleteBackward(),
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

  const _ActionButton({
    this.icon,
    this.label,
    required this.onPressed,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: SizedBox(
        height: 44,
        child: Material(
          color: color ?? theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: label != null 
                ? Text(label!, style: TextStyle(fontWeight: FontWeight.bold, color: textColor))
                : Icon(icon, size: 20, color: textColor),
            ),
          ),
        ),
      ),
    );
  }
}
