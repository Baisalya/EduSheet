import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
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
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_symbol_search_sheet.dart';

class MathKeyboardView extends ConsumerWidget {
  const MathKeyboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                constraints.maxHeight < 330 || constraints.maxWidth < 360;

            return Column(
              children: [
                _buildHeader(context, state, controller, compact: compact),
                _buildQuickBar(context, state, controller, compact: compact),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: state.currentCategory == MathCategory.format
                        ? _buildQuillToolbar(context, state, ref)
                        : state.currentCategory == MathCategory.geometry
                        ? _buildGeometryKeyboardPanel(context, controller)
                        : _buildSymbolGrid(context, state, controller, ref),
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
  }) {
    final theme = Theme.of(context);
    final primary = <({String label, IconData icon, MathCategory category})>[
      (label: '123', icon: Icons.pin_outlined, category: MathCategory.basic),
      (
        label: compact ? 'ALG' : 'Algebra',
        icon: Icons.superscript_rounded,
        category: MathCategory.functions,
      ),
      (
        label: compact ? 'CALC' : 'Calculus',
        icon: Icons.functions_rounded,
        category: MathCategory.calculus,
      ),
      (
        label: compact ? 'SCI' : 'Science',
        icon: Icons.science_outlined,
        category: MathCategory.physics,
      ),
    ];
    final primaryCategories = primary.map((item) => item.category).toSet();
    final moreSelected = !primaryCategories.contains(state.currentCategory);

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
          Tooltip(
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
          IconButton(
            tooltip: 'Find symbol or formula',
            visualDensity: VisualDensity.compact,
            onPressed: () => _showSymbolSearch(context, controller),
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
                    showLabel: !compact,
                    onTap: () =>
                        _showCategoryPicker(context, state, controller),
                  );
                }

                final item = primary[index];
                return _CategoryPill(
                  icon: item.icon,
                  label: item.label,
                  selected: state.currentCategory == item.category,
                  showLabel: !compact || item.label == '123',
                  onTap: () => controller.setCategory(item.category),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryPicker(
    BuildContext context,
    MathKeyboardStateData state,
    MathKeyboardController controller,
  ) {
    const groups = <String, List<MathCategory>>{
      'MY KEYS': <MathCategory>[MathCategory.recent, MathCategory.favorites],
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

    showAdaptiveModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'More math & science keys',
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final group in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Text(
                  group.key,
                  style: Theme.of(sheetContext).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
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
                      onSelected: (_) {
                        controller.setCategory(category);
                        Navigator.pop(sheetContext);
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
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

  void _showSymbolSearch(
    BuildContext context,
    MathKeyboardController controller,
  ) {
    showAdaptiveModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
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
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 7),
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
              onTap: () => controller.insertSymbol(symbol),
            ),
          );
        },
      ),
    );
  }

  double _quickKeyWidth(String label, {required bool compact}) {
    if (label.length >= 7) return compact ? 70 : 78;
    if (label.length >= 4) return compact ? 56 : 62;
    return compact ? 46 : 50;
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

    showAdaptiveModalBottomSheet(
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
          onLongPress: () =>
              _showSymbolActions(context, ref, controller, symbol),
          onTap: () => controller.insertSymbol(symbol),
        );
      },
    );
  }

  void _showSymbolActions(
    BuildContext context,
    WidgetRef ref,
    MathKeyboardController controller,
    MathSymbol symbol,
  ) {
    final favorites = ref.read(favoriteSymbolsProvider);
    final isFavorite = favorites.any((item) => item.id == symbol.id);
    showAdaptiveModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.functions_rounded),
              title: Text(symbol.accessibilityLabel),
              subtitle: Text(symbol.tex),
            ),
            ListTile(
              minTileHeight: 52,
              leading: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              ),
              title: Text(
                isFavorite ? 'Remove from favourites' : 'Add to favourites',
              ),
              onTap: () {
                ref
                    .read(favoriteSymbolsProvider.notifier)
                    .toggleFavorite(symbol);
                Navigator.pop(context);
              },
            ),
            for (final alternative in symbol.variations ?? const <String>[])
              ListTile(
                minTileHeight: 52,
                leading: const Icon(Icons.subdirectory_arrow_right_rounded),
                title: Text(alternative),
                onTap: () {
                  controller.insertText(alternative);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  List<MathSymbol> _recentSymbols(MathKeyboardStateData state) {
    const defaults = <String>[
      r'\frac{}{}',
      r'\sqrt{}',
      r'^{2}',
      r'^{}',
      r'_{}',
      r'\times',
      r'\div',
      r'\leq',
      r'\geq',
      r'\angle',
      r'\pi',
      r'\theta',
    ];
    final source = state.recentSymbols.isEmpty ? defaults : state.recentSymbols;
    final result = <MathSymbol>[];
    for (final tex in source) {
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
