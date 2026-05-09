import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/math_symbol.dart';
import '../providers/math_keyboard_provider.dart';
import '../providers/math_keyboard_controller.dart';
import 'math_key.dart';

class MathKeyboardView extends ConsumerWidget {
  const MathKeyboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCategory = ref.watch(mathKeyboardStateProvider);
    final favorites = ref.watch(favoriteSymbolsProvider);
    final controller = ref.read(mathKeyboardControllerProvider.notifier);

    final filteredSymbols = mathSymbols.where((s) => s.category == currentCategory).toList();

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
          // Category Switcher
          Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: MathCategory.values.map((category) {
                final isSelected = currentCategory == category;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6),
                  child: FilterChip(
                    label: Text(
                      category.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(mathKeyboardStateProvider.notifier).setCategory(category);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Symbol Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.2,
              ),
              itemCount: filteredSymbols.length,
              itemBuilder: (context, index) {
                final symbol = filteredSymbols[index];
                return _MathSymbolKey(
                  symbol: symbol,
                  onTap: () => controller.insertText(symbol.tex),
                );
              },
            ),
          ),
          
          // Action Buttons (Bottom Bar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.keyboard_hide,
                  label: 'ABC',
                  onPressed: () => controller.showSystemKeyboard(),
                  color: Theme.of(context).colorScheme.primary,
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
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MathSymbolKey extends StatelessWidget {
  final MathSymbol symbol;
  final VoidCallback onTap;

  const _MathSymbolKey({required this.symbol, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            symbol.label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionButton({
    required this.icon,
    this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 44,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Theme.of(context).colorScheme.surface,
            foregroundColor: color != null ? Colors.white : Theme.of(context).colorScheme.onSurface,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 1,
          ),
          child: label != null 
            ? Text(label!, style: const TextStyle(fontWeight: FontWeight.bold))
            : Icon(icon, size: 20),
        ),
      ),
    );
  }
}

