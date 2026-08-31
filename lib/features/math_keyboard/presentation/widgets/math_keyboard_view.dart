import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:edusheet/features/geometry_builder/models/geometry_shape.dart';
import 'package:edusheet/features/geometry_builder/services/geometry_diagram_registry.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_builder_screen.dart';
import 'package:edusheet/features/math_keyboard/domain/catalog/math_symbol_catalog.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_symbol.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_smart_palette.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_provider.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_key.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_action_bar.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_modal_presenter.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_symbol_search_sheet.dart';

class MathKeyboardView extends ConsumerStatefulWidget {
  const MathKeyboardView({super.key});

  @override
  ConsumerState<MathKeyboardView> createState() => _MathKeyboardViewState();
}

enum _MathKeyboardLocalPanel {
  keys,
  categories,
  structures,
  symbolActions,
  shapes,
}

class _MathKeyboardViewState extends ConsumerState<MathKeyboardView> {
  _MathKeyboardLocalPanel _localPanel = _MathKeyboardLocalPanel.keys;
  MathSymbol? _actionSymbol;

  bool get _showingKeys => _localPanel == _MathKeyboardLocalPanel.keys;

  void _showLocalPanel(_MathKeyboardLocalPanel panel, {MathSymbol? symbol}) {
    setState(() {
      _localPanel = panel;
      _actionSymbol = symbol;
    });
  }

  void _showKeys(MathKeyboardController controller) {
    setState(() {
      _localPanel = _MathKeyboardLocalPanel.keys;
      _actionSymbol = null;
    });
    controller.restoreActiveMathFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mathKeyboardControllerProvider);
    final controller = ref.read(mathKeyboardControllerProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxHeight < 285 || constraints.maxWidth < 360;
            final showCategoryLabels = constraints.maxWidth >= 500;

            return Column(
              children: [
                _buildHeader(
                  context,
                  state,
                  controller,
                  compact: compact,
                  showCategoryLabels: showCategoryLabels,
                ),
                if (_showingKeys)
                  _buildQuickBar(context, state, controller, compact: compact),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: switch (_localPanel) {
                      _MathKeyboardLocalPanel.categories =>
                        _buildCategoryBrowser(context, state, controller),
                      _MathKeyboardLocalPanel.structures =>
                        _buildStructureBrowser(context, controller),
                      _MathKeyboardLocalPanel.symbolActions =>
                        _buildSymbolActionsPanel(
                          context,
                          ref,
                          controller,
                          _actionSymbol,
                        ),
                      _MathKeyboardLocalPanel.shapes => _buildShapeBrowser(
                        context,
                        controller,
                      ),
                      _MathKeyboardLocalPanel.keys =>
                        state.currentCategory == MathCategory.format
                            ? _buildQuillToolbar(context, state, ref)
                            : state.currentCategory == MathCategory.geometry
                            ? _buildGeometryKeyboardPanel(context, controller)
                            : _buildSymbolGrid(context, state, controller, ref),
                    },
                  ),
                ),
                MathKeyboardActionBar(compact: compact),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    MathKeyboardStateData state,
    MathKeyboardController controller, {
    required bool compact,
    required bool showCategoryLabels,
  }) {
    final theme = Theme.of(context);
    final primary = <({String label, IconData icon, MathCategory category})>[
      (
        label: showCategoryLabels ? 'Common' : '123',
        icon: Icons.pin_outlined,
        category: MathCategory.basic,
      ),
      (
        label: 'Algebra',
        icon: Icons.superscript_rounded,
        category: MathCategory.functions,
      ),
      (
        label: 'Calculus',
        icon: Icons.functions_rounded,
        category: MathCategory.calculus,
      ),
      (
        label: 'Science',
        icon: Icons.science_outlined,
        category: MathCategory.physics,
      ),
    ];
    final primaryCategories = primary.map((item) => item.category).toSet();
    final moreSelected =
        _localPanel == _MathKeyboardLocalPanel.categories ||
        (_showingKeys && !primaryCategories.contains(state.currentCategory));

    return Container(
      height: compact ? 46 : 50,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Semantics(
            label: 'Resize math keyboard',
            hint: 'Drag up or down, or use increase and decrease actions',
            value: '${state.height.round()} pixels',
            increasedValue:
                '${(state.height + 40).clamp(240.0, 520.0).round()} pixels',
            decreasedValue:
                '${(state.height - 40).clamp(240.0, 520.0).round()} pixels',
            onIncrease: () => controller.setHeight(state.height + 40),
            onDecrease: () => controller.setHeight(state.height - 40),
            child: ExcludeSemantics(
              child: Tooltip(
                message: 'Drag to resize keyboard',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) =>
                      controller.setHeight(state.height - details.delta.dy),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 10,
                    ),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 19,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Find symbol or formula',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              if (!_showingKeys) {
                setState(() {
                  _localPanel = _MathKeyboardLocalPanel.keys;
                  _actionSymbol = null;
                });
              }
              _showSymbolSearch(context, controller);
            },
            icon: const Icon(Icons.search_rounded, size: 20),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: primary.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 3),
              itemBuilder: (context, index) {
                if (index == primary.length) {
                  return _CategoryPill(
                    icon: moreSelected
                        ? _categoryIcon(state.currentCategory)
                        : Icons.grid_view_rounded,
                    label: moreSelected
                        ? _categoryLabel(state.currentCategory)
                        : 'MORE',
                    selected: moreSelected,
                    // Keep the category-picker entry discoverable even when
                    // the keyboard is vertically compact. Hiding this label
                    // based on height made a wide desktop keyboard show an
                    // unexplained grid icon and broke the local-panel flow.
                    showLabel: true,
                    onTap: () {
                      if (_localPanel == _MathKeyboardLocalPanel.categories) {
                        _showKeys(controller);
                      } else {
                        _showLocalPanel(_MathKeyboardLocalPanel.categories);
                      }
                    },
                  );
                }

                final item = primary[index];
                return _CategoryPill(
                  icon: item.icon,
                  label: item.label,
                  selected: state.currentCategory == item.category,
                  showLabel:
                      showCategoryLabels || item.category == MathCategory.basic,
                  onTap: () {
                    controller.setCategory(item.category);
                    _showKeys(controller);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBrowser(
    BuildContext context,
    MathKeyboardStateData state,
    MathKeyboardController controller,
  ) {
    const groups = <String, List<MathCategory>>{
      'MATHEMATICS': <MathCategory>[
        MathCategory.trig,
        MathCategory.geometry,
        MathCategory.statistics,
        MathCategory.matrices,
        MathCategory.sets,
      ],
      'SCIENCE': <MathCategory>[MathCategory.physics, MathCategory.chemistry],
      'SYMBOLS': <MathCategory>[
        MathCategory.greek,
        MathCategory.operators,
        MathCategory.brackets,
        MathCategory.arrows,
      ],
      'TOOLS': <MathCategory>[
        MathCategory.templates,
        MathCategory.format,
        MathCategory.misc,
      ],
    };
    final theme = Theme.of(context);
    final favorites = ref.watch(favoriteSymbolsProvider);

    void choose(MathCategory category) {
      controller.setCategory(category);
      _showKeys(controller);
    }

    return ListView(
      key: const ValueKey('math-category-browser'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'More math & science keys',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Choose a topic without leaving the formula keyboard.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _showKeys(controller),
              icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
              label: const Text('Back to keys'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MyKeysCard(
                icon: Icons.history_rounded,
                title: 'Recent',
                detail: '${state.recentSymbols.length} used',
                selected: state.currentCategory == MathCategory.recent,
                onTap: () => choose(MathCategory.recent),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MyKeysCard(
                icon: Icons.star_outline_rounded,
                title: 'Favourites',
                detail: '${favorites.length} saved',
                selected: state.currentCategory == MathCategory.favorites,
                onTap: () => choose(MathCategory.favorites),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final group in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(
              group.key,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in group.value)
                ChoiceChip(
                  avatar: Icon(_categoryIcon(category), size: 18),
                  label: Text(_categoryLabel(category)),
                  selected: state.currentCategory == category,
                  onSelected: (_) => choose(category),
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _categoryLabel(MathCategory category) {
    return switch (category) {
      MathCategory.recent => 'RECENT',
      MathCategory.favorites => 'FAVOURITES',
      MathCategory.basic => 'COMMON',
      MathCategory.functions => 'ALGEBRA',
      MathCategory.trig => 'TRIG',
      MathCategory.calculus => 'CALCULUS',
      MathCategory.geometry => 'GEOMETRY',
      MathCategory.physics => 'PHYSICS',
      MathCategory.chemistry => 'CHEMISTRY',
      MathCategory.statistics => 'STATS',
      MathCategory.matrices => 'MATRIX',
      MathCategory.greek => 'GREEK',
      MathCategory.operators => 'SIGNS',
      MathCategory.brackets => 'BRACKETS',
      MathCategory.arrows => 'ARROWS',
      MathCategory.sets => 'SETS',
      MathCategory.templates => 'FORMULAS',
      MathCategory.format => 'FORMAT',
      MathCategory.misc => 'EXTRA',
    };
  }

  IconData _categoryIcon(MathCategory category) {
    return switch (category) {
      MathCategory.recent => Icons.history_rounded,
      MathCategory.favorites => Icons.star_outline_rounded,
      MathCategory.basic => Icons.calculate_outlined,
      MathCategory.functions => Icons.superscript_rounded,
      MathCategory.trig => Icons.show_chart_rounded,
      MathCategory.calculus => Icons.functions_rounded,
      MathCategory.geometry => Icons.architecture_outlined,
      MathCategory.physics => Icons.science_outlined,
      MathCategory.chemistry => Icons.biotech_outlined,
      MathCategory.statistics => Icons.query_stats_rounded,
      MathCategory.matrices => Icons.grid_4x4_rounded,
      MathCategory.greek => Icons.language_rounded,
      MathCategory.operators => Icons.compare_arrows_rounded,
      MathCategory.brackets => Icons.data_array_rounded,
      MathCategory.arrows => Icons.arrow_forward_rounded,
      MathCategory.sets => Icons.join_inner_rounded,
      MathCategory.templates => Icons.auto_awesome_outlined,
      MathCategory.format => Icons.format_bold_rounded,
      MathCategory.misc => Icons.more_horiz_rounded,
    };
  }

  Future<void> _showSymbolSearch(
    BuildContext context,
    MathKeyboardController controller,
  ) async {
    await showMathKeyboardPanel<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: MathSymbolSearchSheet(
          categoryLabel: _categoryLabel,
          onSelected: (symbol) {
            controller.insertSymbol(symbol);
            Navigator.pop(context);
          },
        ),
      ),
    );
    controller.restoreActiveMathFocus();
  }

  Widget _buildQuickBar(
    BuildContext context,
    MathKeyboardStateData state,
    MathKeyboardController controller, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final symbols = MathSmartPalette.forCategory(state.currentCategory);

    return Container(
      height: compact ? 44 : 48,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.24,
        ),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 7, right: 5),
            child: Semantics(
              button: true,
              label: 'Build a math structure',
              hint:
                  'Fraction, root, power, subscript, integral, sum, or a ready formula',
              onTap: () => _showLocalPanel(_MathKeyboardLocalPanel.structures),
              child: ExcludeSemantics(
                child: Tooltip(
                  message:
                      'Build fraction, root, power, subscript or a ready formula',
                  child: Material(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      key: const ValueKey('math-build-button'),
                      borderRadius: BorderRadius.circular(9),
                      onTap: () =>
                          _showLocalPanel(_MathKeyboardLocalPanel.structures),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 7 : 9,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.account_tree_outlined,
                              size: 16,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Build',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w900,
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
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 7),
              itemCount: symbols.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final symbol = symbols[index];

                return SizedBox(
                  width: _quickKeyWidth(symbol.label, compact: compact),
                  child: MathKey(
                    symbol: symbol,
                    fontSize: compact ? 15 : 17,
                    color: theme.colorScheme.surface,
                    onLongPress: () => _showLocalPanel(
                      _MathKeyboardLocalPanel.symbolActions,
                      symbol: symbol,
                    ),
                    onTap: () => controller.insertSymbol(symbol),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double _quickKeyWidth(String label, {required bool compact}) {
    if (label.length >= 7) return compact ? 70 : 78;
    if (label.length >= 4) return compact ? 56 : 62;
    return compact ? 46 : 50;
  }

  Widget _buildStructureBrowser(
    BuildContext context,
    MathKeyboardController controller,
  ) {
    const structureSpecs = <({String source, String title, String hint})>[
      (
        source: r'\frac{}{}',
        title: 'Fraction',
        hint: 'Top box, then Next box for bottom',
      ),
      (
        source: r'\sqrt{}',
        title: 'Square root',
        hint: 'Type directly inside the root',
      ),
      (source: r'^{}', title: 'Power', hint: 'Add an exponent box'),
      (source: r'_{}', title: 'Subscript', hint: 'Add a lower index box'),
      (source: r'|{}|', title: 'Absolute value', hint: 'Type inside the bars'),
      (
        source: r'\int_{}^{}',
        title: 'Integral',
        hint: 'Lower limit, upper limit, then expression',
      ),
      (
        source: r'\sum_{}^{}',
        title: 'Summation',
        hint: 'Lower limit, upper limit, then expression',
      ),
    ];
    final theme = Theme.of(context);
    final structures = <({MathSymbol symbol, String title, String hint})>[];
    for (final spec in structureSpecs) {
      final symbol = MathSymbolCatalog.findByTex(spec.source);
      if (symbol != null) {
        structures.add((symbol: symbol, title: spec.title, hint: spec.hint));
      }
    }
    final templates = MathSymbolCatalog.forCategory(MathCategory.templates)
        .where((symbol) => symbol.kind == MathEntryKind.formulaTemplate)
        .take(8)
        .toList(growable: false);

    void insert(MathSymbol symbol) {
      controller.insertStructure(symbol);
      _showKeys(controller);
    }

    return ListView(
      key: const ValueKey('math-structure-browser'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final stackActions = constraints.maxWidth < 420 || textScale >= 1.5;
            final intro = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Build math faster',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Choose the shape first, type in its box, then use “Next box”.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
            final backButton = TextButton.icon(
              onPressed: () => _showKeys(controller),
              icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
              label: const Text('Back to keys'),
            );

            if (stackActions) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  intro,
                  const SizedBox(height: 4),
                  Align(alignment: Alignment.centerLeft, child: backButton),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: intro),
                const SizedBox(width: 8),
                backButton,
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          'BUILD FROM BOXES',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final columns = textScale >= 1.6 && constraints.maxWidth < 520
                ? 1
                : constraints.maxWidth >= 760
                ? 4
                : constraints.maxWidth >= 520
                ? 3
                : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent: _structureCardExtent(context),
              ),
              itemCount: structures.length,
              itemBuilder: (context, index) {
                final item = structures[index];
                return _StructureChoiceCard(
                  key: ValueKey('math-build-${item.symbol.id}'),
                  symbol: item.symbol,
                  title: item.title,
                  hint: item.hint,
                  onTap: () => insert(item.symbol),
                );
              },
            );
          },
        ),
        if (templates.isNotEmpty) ...[
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final stackActions =
                  constraints.maxWidth < 360 || textScale >= 1.75;
              final heading = Text(
                'READY FORMULAS',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
              final seeAll = TextButton(
                onPressed: () {
                  controller.setCategory(MathCategory.templates);
                  _showKeys(controller);
                },
                child: const Text('See all'),
              );

              if (stackActions) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    Align(alignment: Alignment.centerLeft, child: seeAll),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: heading),
                  seeAll,
                ],
              );
            },
          ),
          Text(
            'Insert a standard formula, then move through it with the visible formula cursor.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 7),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final columns = textScale >= 1.6 && constraints.maxWidth < 520
                  ? 1
                  : constraints.maxWidth >= 760
                  ? 4
                  : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  mainAxisExtent: _structureCardExtent(context),
                ),
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final symbol = templates[index];
                  return _StructureChoiceCard(
                    key: ValueKey('math-template-${symbol.id}'),
                    symbol: symbol,
                    title: symbol.accessibilityLabel,
                    hint: 'Ready formula',
                    onTap: () => insert(symbol),
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }

  double _structureCardExtent(BuildContext context) {
    final scaledLabelSize = MediaQuery.textScalerOf(context).scale(14);
    final scale = (scaledLabelSize / 14).clamp(1.0, 2.0);
    if (scale >= 1.75) return 120;
    if (scale >= 1.4) return 96;
    if (scale >= 1.15) return 84;
    return 74;
  }

  Widget _buildGeometryKeyboardPanel(
    BuildContext context,
    MathKeyboardController controller,
  ) {
    final theme = Theme.of(context);
    final notation = MathSymbolCatalog.forCategory(MathCategory.geometry);
    const quickShapes = <_GeometryKeyboardAction>[
      _GeometryKeyboardAction(
        'Triangle',
        Icons.change_history,
        GeometryShapeType.triangle,
      ),
      _GeometryKeyboardAction(
        'Right triangle',
        Icons.signal_cellular_4_bar,
        GeometryShapeType.rightTriangle,
      ),
      _GeometryKeyboardAction(
        'Rectangle',
        Icons.rectangle_outlined,
        GeometryShapeType.rectangle,
      ),
      _GeometryKeyboardAction(
        'Circle',
        Icons.circle_outlined,
        GeometryShapeType.circle,
      ),
      _GeometryKeyboardAction(
        'Axes',
        Icons.add,
        GeometryShapeType.coordinateAxes,
      ),
      _GeometryKeyboardAction(
        'Number line',
        Icons.linear_scale,
        GeometryShapeType.numberLine,
      ),
    ];

    return ListView(
      key: const ValueKey('geometry-teacher-panel'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      children: [
        Row(
          children: [
            Icon(
              Icons.edit_note_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Write geometry notation',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              'Tap to insert',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 8 : 5,
            mainAxisSpacing: 7,
            crossAxisSpacing: 7,
            childAspectRatio: 1.35,
          ),
          itemCount: notation.length,
          itemBuilder: (context, index) {
            final symbol = notation[index];
            return MathKey(
              symbol: symbol,
              fontSize: symbol.label.length > 5 ? 12 : 17,
              onTap: () => controller.insertSymbol(symbol),
            );
          },
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                Icons.architecture_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need a diagram?',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Choose a ready shape or open the full builder.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () => _openGeometryBuilder(context, controller),
                child: const Text('Builder'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: quickShapes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final action = quickShapes[index];
              return SizedBox(
                width: 96,
                child: MathKey(
                  label: action.label,
                  onTap: () => _openGeometryBuilder(
                    context,
                    controller,
                    initialShape: action.shape,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        action.icon,
                        size: 21,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        action.label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openGeometryBuilder(
    BuildContext context,
    MathKeyboardController controller, {
    GeometryShapeType? initialShape,
  }) async {
    controller.hideKeyboard();
    final diagram = await GeometryBuilderScreen.show(
      context,
      initialShape: initialShape,
    );
    if (diagram == null) return;
    GeometryDiagramRegistry.instance.save(diagram);
    controller.insertText(diagram.placeholderToken);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geometry placeholder inserted')),
      );
    }
  }

  void _toggleQuillAttribute(
    quill.QuillController controller,
    quill.Attribute attribute,
  ) {
    final current = controller.getSelectionStyle().attributes[attribute.key];
    final isActive = current?.value == attribute.value;
    controller.formatSelection(
      isActive ? quill.Attribute.clone(attribute, null) : attribute,
    );
  }

  Widget _buildQuillToolbar(
    BuildContext context,
    MathKeyboardStateData state,
    WidgetRef ref,
  ) {
    final activeEditor = state.activeController;
    if (activeEditor is! quill.QuillController) {
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
        'onTap': () => _showLocalPanel(_MathKeyboardLocalPanel.shapes),
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
            _toggleQuillAttribute(activeEditor, quill.Attribute.bold),
      },
      {
        'label': 'Italic',
        'icon': Icons.format_italic,
        'onTap': () =>
            _toggleQuillAttribute(activeEditor, quill.Attribute.italic),
      },
      {
        'label': 'Under',
        'icon': Icons.format_underlined,
        'onTap': () =>
            _toggleQuillAttribute(activeEditor, quill.Attribute.underline),
      },
      {
        'label': 'Strike',
        'icon': Icons.format_strikethrough,
        'onTap': () =>
            _toggleQuillAttribute(activeEditor, quill.Attribute.strikeThrough),
      },
      {
        'label': 'Bullet',
        'icon': Icons.format_list_bulleted,
        'onTap': () => _toggleQuillAttribute(activeEditor, quill.Attribute.ul),
      },
      {
        'label': 'Number',
        'icon': Icons.format_list_numbered,
        'onTap': () => _toggleQuillAttribute(activeEditor, quill.Attribute.ol),
      },
      {
        'label': 'Left',
        'icon': Icons.format_align_left,
        'onTap': () =>
            activeEditor.formatSelection(quill.Attribute.leftAlignment),
      },
      {
        'label': 'Center',
        'icon': Icons.format_align_center,
        'onTap': () =>
            activeEditor.formatSelection(quill.Attribute.centerAlignment),
      },
      {
        'label': 'Right',
        'icon': Icons.format_align_right,
        'onTap': () =>
            activeEditor.formatSelection(quill.Attribute.rightAlignment),
      },
      {
        'label': 'Justify',
        'icon': Icons.format_align_justify,
        'onTap': () =>
            activeEditor.formatSelection(quill.Attribute.justifyAlignment),
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
            label: action['label'] as String,
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

  Widget _buildShapeBrowser(
    BuildContext context,
    MathKeyboardController controller,
  ) {
    const shapes = <IconData>[
      Icons.circle,
      Icons.square,
      Icons.change_history,
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
    final theme = Theme.of(context);

    return ListView(
      key: const ValueKey('math-shape-browser'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Insert a shape',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Choose a shape without opening another popup.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _showKeys(controller),
              icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
              label: const Text('Back to keys'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: shapes.length,
          itemBuilder: (context, index) {
            final icon = shapes[index];
            void insertShape() {
              controller.addFloatingElement(
                FloatingElementType.shape,
                icon: icon,
              );
              _showKeys(controller);
            }

            return Semantics(
              excludeSemantics: true,
              button: true,
              label: 'Insert shape ${index + 1}',
              onTap: insertShape,
              child: Material(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: insertShape,
                  child: Icon(icon, color: theme.colorScheme.primary),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSymbolGrid(
    BuildContext context,
    MathKeyboardStateData state,
    MathKeyboardController controller,
    WidgetRef ref,
  ) {
    final favorites = ref.watch(favoriteSymbolsProvider);
    final symbols = state.currentCategory == MathCategory.recent
        ? _recentSymbols(state)
        : state.currentCategory == MathCategory.favorites
        ? favorites
        : MathSymbolCatalog.forCategory(state.currentCategory);
    final isTablet =
        MediaQuery.of(context).size.width > 600 || state.isTabletLayout;
    final theme = Theme.of(context);

    if (symbols.isEmpty &&
        (state.currentCategory == MathCategory.recent ||
            state.currentCategory == MathCategory.favorites)) {
      final isRecent = state.currentCategory == MathCategory.recent;
      return _KeyboardEmptyState(
        key: ValueKey('empty-${state.currentCategory.name}'),
        icon: isRecent ? Icons.history_rounded : Icons.star_outline_rounded,
        title: isRecent ? 'No recent math yet' : 'No favourites yet',
        message: isRecent
            ? 'Symbols and structures you use will appear here automatically.'
            : 'Press and hold/right-click a key, or use Search, to save the math you use often.',
        actionLabel: 'Browse math keys',
        onAction: () => _showLocalPanel(_MathKeyboardLocalPanel.categories),
      );
    }

    // Custom grid settings per category
    final int crossAxisCount;
    final double childAspectRatio;

    if (state.currentCategory == MathCategory.basic) {
      crossAxisCount = isTablet ? 10 : 5;
      childAspectRatio = 1.0;
    } else if (state.currentCategory == MathCategory.templates ||
        state.currentCategory == MathCategory.physics ||
        state.currentCategory == MathCategory.chemistry ||
        state.currentCategory == MathCategory.statistics) {
      crossAxisCount = isTablet ? 4 : 2;
      childAspectRatio = 2.45;
    } else {
      crossAxisCount = isTablet ? 10 : 5;
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
        final isPowerActive =
            symbol.inputBehavior == MathInputBehavior.powerMode &&
            state.isPowerMode;
        final isSubActive =
            symbol.inputBehavior == MathInputBehavior.subscriptMode &&
            state.isSubscriptMode;

        return MathKey(
          symbol: symbol,
          color: (isPowerActive || isSubActive)
              ? theme.colorScheme.primaryContainer
              : null,
          textColor: (isPowerActive || isSubActive)
              ? theme.colorScheme.onPrimaryContainer
              : null,
          onLongPress: () => _showLocalPanel(
            _MathKeyboardLocalPanel.symbolActions,
            symbol: symbol,
          ),
          onTap: () => controller.insertSymbol(symbol),
        );
      },
    );
  }

  Widget _buildSymbolActionsPanel(
    BuildContext context,
    WidgetRef ref,
    MathKeyboardController controller,
    MathSymbol? symbol,
  ) {
    if (symbol == null) {
      return _KeyboardEmptyState(
        key: const ValueKey('math-key-actions-empty'),
        icon: Icons.touch_app_outlined,
        title: 'No key selected',
        message: 'Return to the keyboard and choose a math key.',
        actionLabel: 'Back to keys',
        onAction: () => _showKeys(controller),
      );
    }

    final theme = Theme.of(context);
    final favorites = ref.watch(favoriteSymbolsProvider);
    final isFavorite = favorites.any((item) => item.id == symbol.id);
    final alternatives = symbol.variations ?? const <String>[];

    void insertSource(String source) {
      controller.insertText(source);
      _showKeys(controller);
    }

    return ListView(
      key: ValueKey('math-key-actions-${symbol.id}'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key actions',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    symbol.accessibilityLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _showKeys(controller),
              icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
              label: const Text('Back to keys'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SymbolActionCard(
          icon: Icons.add_circle_outline_rounded,
          title: 'Insert ${symbol.accessibilityLabel}',
          subtitle: symbol.isStructural
              ? 'Insert the structure and continue in its first box.'
              : 'Insert at the visible formula cursor.',
          onTap: () {
            controller.insertSymbol(symbol);
            _showKeys(controller);
          },
        ),
        const SizedBox(height: 8),
        _SymbolActionCard(
          icon: isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
          title: isFavorite ? 'Remove from favourites' : 'Add to favourites',
          subtitle: 'Keep frequently used math easy to reach.',
          onTap: () {
            ref.read(favoriteSymbolsProvider.notifier).toggleFavorite(symbol);
            controller.restoreActiveMathFocus();
          },
        ),
        if (alternatives.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'ALTERNATIVES',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 7),
          for (final alternative in alternatives) ...[
            Builder(
              builder: (context) {
                final matchingSymbol = MathSymbolCatalog.findByTex(alternative);
                final title = matchingSymbol?.accessibilityLabel ?? alternative;
                return _SymbolActionCard(
                  icon: Icons.subdirectory_arrow_right_rounded,
                  title: title,
                  subtitle: matchingSymbol == null
                      ? 'Alternative form'
                      : _categoryLabel(matchingSymbol.category),
                  onTap: () => insertSource(alternative),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 4),
        Text(
          'Tip: on Windows you can right-click a key; on touch, press and hold.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  List<MathSymbol> _recentSymbols(MathKeyboardStateData state) {
    final result = <MathSymbol>[];
    for (final tex in state.recentSymbols) {
      final match = MathSymbolCatalog.findByTex(tex);
      if (match != null) {
        result.add(match);
      } else if (tex.trim().isNotEmpty) {
        result.add(
          MathSymbol(
            id: 'recent:$tex',
            label: tex.length > 12 ? '${tex.substring(0, 11)}…' : tex,
            tex: tex,
            category: MathCategory.recent,
          ),
        );
      }
    }
    return result;
  }
}

class _KeyboardEmptyState extends StatelessWidget {
  const _KeyboardEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _MyKeysCard extends StatelessWidget {
  const _MyKeysCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StructureChoiceCard extends StatelessWidget {
  const _StructureChoiceCard({
    super.key,
    required this.symbol,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final MathSymbol symbol;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      excludeSemantics: true,
      button: true,
      label: 'Insert $title',
      hint: hint,
      onTap: onTap,
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: MathKey(symbol: symbol, onTap: () {}),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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

class _SymbolActionCard extends StatelessWidget {
  const _SymbolActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: label,
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: showLabel ? 9 : 10,
              vertical: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                if (showLabel) ...[
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GeometryKeyboardAction {
  final String label;
  final IconData icon;
  final GeometryShapeType? shape;

  const _GeometryKeyboardAction(this.label, this.icon, this.shape);
}
