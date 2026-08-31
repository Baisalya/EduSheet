import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edusheet/features/math_keyboard/domain/catalog/math_symbol_catalog.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_symbol.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_smart_palette.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_provider.dart';

class MathSymbolSearchSheet extends ConsumerStatefulWidget {
  final String Function(MathCategory category) categoryLabel;
  final ValueChanged<MathSymbol> onSelected;

  const MathSymbolSearchSheet({
    super.key,
    required this.categoryLabel,
    required this.onSelected,
  });

  @override
  ConsumerState<MathSymbolSearchSheet> createState() =>
      _MathSymbolSearchSheetState();
}

class _MathSymbolSearchSheetState extends ConsumerState<MathSymbolSearchSheet> {
  static const _popularQueries = <String>[
    'Fraction',
    'Square root',
    'Power',
    'Angle',
    'Integral',
    'Vector',
    'Mean',
    'Greek',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  MathCategory? _category;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyQuery(String value) {
    _searchController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() => _query = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favorites = ref.watch(favoriteSymbolsProvider);
    final favoriteIds = favorites.map((symbol) => symbol.id).toSet();
    final symbols = _query.trim().isEmpty
        ? MathSmartPalette.forCategory(_category ?? MathCategory.basic)
        : MathSymbolCatalog.search(_query, category: _category, limit: 80);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final largeText = textScale >= 1.5;
          final useScrollableLayout =
              largeText &&
              (constraints.maxWidth < 520 || constraints.maxHeight < 680);
          final chipRowHeight = largeText ? 58.0 : 38.0;
          final columns = constraints.maxWidth >= 720 ? 2 : 1;

          final controls = <Widget>[
            Text(
              'Find math quickly',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Search the way a teacher thinks — “fraction”, “angle”, “wavelength”, “standard deviation”…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'What do you want to add?',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () => _applyQuery(''),
                        icon: const Icon(Icons.clear_rounded),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (_query.trim().isEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: chipRowHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _popularQueries.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final query = _popularQueries[index];
                    return ActionChip(
                      avatar: const Icon(Icons.bolt_rounded, size: 15),
                      label: Text(query),
                      onPressed: () => _applyQuery(query),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: chipRowHeight,
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  _query.trim().isEmpty
                      ? '${symbols.length} useful starting points'
                      : '${symbols.length} results',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Tap a result to insert',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ];

          Widget buildResults({required bool shrinkWrap}) {
            if (symbols.isEmpty) {
              final empty = _SearchEmptyState(query: _query);
              return shrinkWrap
                  ? SizedBox(height: largeText ? 220 : 160, child: empty)
                  : empty;
            }

            return GridView.builder(
              shrinkWrap: shrinkWrap,
              physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: columns == 1 ? 4.0 : 3.4,
                mainAxisExtent: largeText ? 132 : null,
              ),
              itemCount: symbols.length,
              itemBuilder: (context, index) {
                final symbol = symbols[index];
                final isFavorite = favoriteIds.contains(symbol.id);
                return _SearchResultCard(
                  symbol: symbol,
                  categoryLabel: widget.categoryLabel(symbol.category),
                  isFavorite: isFavorite,
                  onFavorite: () => ref
                      .read(favoriteSymbolsProvider.notifier)
                      .toggleFavorite(symbol),
                  onSelected: () => widget.onSelected(symbol),
                );
              },
            );
          }

          if (useScrollableLayout) {
            return ListView(
              key: const ValueKey('math-search-scrollable-layout'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [...controls, buildResults(shrinkWrap: true)],
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...controls,
                Expanded(child: buildResults(shrinkWrap: false)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.symbol,
    required this.categoryLabel,
    required this.isFavorite,
    required this.onFavorite,
    required this.onSelected,
  });

  final MathSymbol symbol;
  final String categoryLabel;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final humanLabel = symbol.accessibilityLabel.trim();
    final showHumanLabel =
        humanLabel.isNotEmpty &&
        humanLabel.toLowerCase() != symbol.label.toLowerCase();

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  symbol.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showHumanLabel ? humanLabel : categoryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          categoryLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (symbol.isStructural)
                          _MiniBadge(
                            icon: Icons.account_tree_outlined,
                            label: 'Structure',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isFavorite
                    ? 'Remove from favourites'
                    : 'Add to favourites',
                visualDensity: VisualDensity.compact,
                onPressed: onFavorite,
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFavorite ? theme.colorScheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 34,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'No matching math found',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              query.trim().isEmpty
                  ? 'Try a topic such as algebra or geometry.'
                  : 'Try a simpler teacher term, for example “root”, “angle”, “mean” or “vector”.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
