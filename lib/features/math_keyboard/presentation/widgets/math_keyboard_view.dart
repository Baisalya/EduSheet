import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_keyboard/math_keyboard.dart';
import '../../domain/models/math_symbol.dart';
import '../providers/math_keyboard_provider.dart';
import 'math_key.dart';

class MathKeyboardView extends ConsumerWidget {
  final MathFieldEditingController controller;

  const MathKeyboardView({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCategory = ref.watch(mathKeyboardStateProvider);
    final favorites = ref.watch(favoriteSymbolsProvider);

    final filteredSymbols = mathSymbols.where((s) => s.category == currentCategory).toList();

    return Container(
      height: 350,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Category Switcher
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: MathCategory.values.map((category) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(category.name.toUpperCase()),
                    selected: currentCategory == category,
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
          
          // Favorites Bar
          if (favorites.isNotEmpty)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final symbol = favorites[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text(symbol.label),
                      onPressed: () => controller.addLeaf(symbol.tex),
                    ),
                  );
                },
              ),
            ),

          const Divider(),

          // Symbol Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.5,
              ),
              itemCount: filteredSymbols.length,
              itemBuilder: (context, index) {
                final symbol = filteredSymbols[index];
                return MathKey(
                  symbol: symbol,
                  onTap: () => controller.addLeaf(symbol.tex),
                  onLongPress: () {
                    ref.read(favoriteSymbolsProvider.notifier).toggleFavorite(symbol);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${symbol.label} toggled in favorites'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => controller.clear(),
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.errorContainer,
                      foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => controller.goBack(deleteMode: true),
                    icon: const Icon(Icons.backspace_outlined),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
