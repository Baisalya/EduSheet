import 'package:flutter/material.dart';

import 'package:edusheet/features/math_keyboard/domain/catalog/math_symbol_catalog.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_symbol.dart';

class MathSymbolSearchSheet extends StatefulWidget {
  final String Function(MathCategory category) categoryLabel;
  final ValueChanged<MathSymbol> onSelected;

  const MathSymbolSearchSheet({
    super.key,
    required this.categoryLabel,
    required this.onSelected,
  });

  @override
  State<MathSymbolSearchSheet> createState() => _MathSymbolSearchSheetState();
}

class _MathSymbolSearchSheetState extends State<MathSymbolSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  MathCategory? _category;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final symbols = MathSymbolCatalog.search(_query, category: _category);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find a symbol or formula',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Try: angle, triangle, fraction, wavelength…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear_rounded),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: const Text('ALL'),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                  ),
                  for (final category in MathCategory.values)
                    if (category != MathCategory.recent &&
                        category != MathCategory.favorites &&
                        category != MathCategory.format)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(widget.categoryLabel(category)),
                          selected: _category == category,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${symbols.length} results',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: symbols.isEmpty
                  ? const Center(child: Text('No matching symbol found'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth > 700
                            ? 5
                            : constraints.maxWidth > 460
                                ? 4
                                : 3;
                        return GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.45,
                          ),
                          itemCount: symbols.length,
                          itemBuilder: (context, index) {
                            final symbol = symbols[index];
                            return Material(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => widget.onSelected(symbol),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        symbol.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.categoryLabel(symbol.category),
                                        style:
                                            theme.textTheme.labelSmall?.copyWith(
                                          fontSize: 9,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
