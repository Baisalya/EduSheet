import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:edusheet/features/geometry_builder/models/geometry_shape.dart';
import 'package:edusheet/features/geometry_builder/services/geometry_diagram_registry.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_builder_screen.dart';
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
                _buildQuickBar(context, controller, compact: compact),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: state.currentCategory == MathCategory.format
                        ? _buildQuillToolbar(context, state, ref)
                        : state.currentCategory == MathCategory.geometry
                        ? _buildGeometryKeyboardPanel(context, controller)
                        : _buildSymbolGrid(context, state, controller),
                  ),
                ),
                _ActionBar(compact: compact),
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
    const categories = <MathCategory>[
      MathCategory.recent,
      MathCategory.basic,
      MathCategory.functions,
      MathCategory.trig,
      MathCategory.calculus,
      MathCategory.geometry,
      MathCategory.physics,
      MathCategory.statistics,
      MathCategory.matrices,
      MathCategory.greek,
      MathCategory.operators,
      MathCategory.brackets,
      MathCategory.arrows,
      MathCategory.sets,
      MathCategory.templates,
      MathCategory.format,
      MathCategory.misc,
    ];

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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 19,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Search every symbol',
            visualDensity: VisualDensity.compact,
            onPressed: () => _showSymbolSearch(context, controller),
            icon: const Icon(Icons.search_rounded, size: 20),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 3),
              itemBuilder: (context, index) {
                final category = categories[index];
                return _CategoryPill(
                  icon: _categoryIcon(category),
                  label: _categoryLabel(category),
                  selected: state.currentCategory == category,
                  showLabel: !compact,
                  onTap: () => controller.setCategory(category),
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
      MathCategory.recent => 'RECENT',
      MathCategory.basic => 'COMMON',
      MathCategory.functions => 'ALGEBRA',
      MathCategory.trig => 'TRIG',
      MathCategory.calculus => 'CALCULUS',
      MathCategory.geometry => 'GEOMETRY',
      MathCategory.physics => 'PHYSICS',
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
      MathCategory.basic => Icons.calculate_outlined,
      MathCategory.functions => Icons.superscript_rounded,
      MathCategory.trig => Icons.show_chart_rounded,
      MathCategory.calculus => Icons.functions_rounded,
      MathCategory.geometry => Icons.architecture_outlined,
      MathCategory.physics => Icons.science_outlined,
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
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _SymbolSearchSheet(
          categoryLabel: _categoryLabel,
          onSelected: (symbol) {
            controller.insertText(symbol.tex);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Widget _buildQuickBar(
    BuildContext context,
    MathKeyboardController controller, {
    required bool compact,
  }) {
    const quickSymbols = [
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
      height: compact ? 42 : 46,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.24),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 7),
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

          return SizedBox(
            width: compact ? 39 : 42,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: MathKey(
                label: label,
                tex: tex,
                fontSize: compact ? 16 : 18,
                color: theme.colorScheme.surface,
                onTap: () => controller.insertText(tex),
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildGeometryKeyboardPanel(
    BuildContext context,
    MathKeyboardController controller,
  ) {
    final theme = Theme.of(context);
    final notation = mathSymbols
        .where((symbol) => symbol.category == MathCategory.geometry)
        .toList();
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
              onTap: () => controller.insertText(symbol.tex),
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
                        style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
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
    final symbols = state.currentCategory == MathCategory.recent
        ? _recentSymbols(state)
        : mathSymbols
              .where((symbol) => symbol.category == state.currentCategory)
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
    } else if (state.currentCategory == MathCategory.templates ||
        state.currentCategory == MathCategory.physics ||
        state.currentCategory == MathCategory.statistics) {
      crossAxisCount = isTablet ? 4 : 2;
      childAspectRatio = 2.45;
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
        final isPowerActive =
            (symbol.label == 'xⁿ' || symbol.label == 'eˣ') && state.isPowerMode;
        final isSubActive =
            (symbol.label == 'xᵢ' ||
                symbol.label == 'Σₙ' ||
                symbol.label == 'Πₙ' ||
                symbol.label == '∫ₐᵇ' ||
                symbol.label == 'logₐ') &&
            state.isSubscriptMode;

        return MathKey(
          symbol: symbol,
          color: (isPowerActive || isSubActive)
              ? theme.colorScheme.primaryContainer
              : null,
          textColor: (isPowerActive || isSubActive)
              ? theme.colorScheme.onPrimaryContainer
              : null,
          onTap: () {
            if (symbol.label == 'xⁿ' || symbol.label == 'eˣ') {
              if (!state.isPowerMode && symbol.label == 'eˣ') {
                controller.insertText('e');
              }
              controller.togglePowerMode();
            } else if (symbol.label == 'xᵢ' ||
                symbol.label == 'Σₙ' ||
                symbol.label == 'Πₙ' ||
                symbol.label == '∫ₐᵇ' ||
                symbol.label == 'logₐ') {
              // If it's a builder symbol like Σₙ, insert the main symbol first if needed
              if (!state.isSubscriptMode) {
                if (symbol.label == 'Σₙ') {
                  controller.insertText(r'\sum');
                } else if (symbol.label == 'Πₙ') {
                  controller.insertText(r'\prod');
                } else if (symbol.label == '∫ₐᵇ') {
                  controller.insertText(r'\int');
                } else if (symbol.label == 'logₐ') {
                  controller.insertText(r'\log');
                }
              }
              controller.toggleSubscriptMode();
            } else {
              controller.insertText(symbol.tex);
            }
          },
        );
      },
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
      final match = mathSymbols.where((symbol) => symbol.tex == tex);
      if (match.isNotEmpty) {
        result.add(match.first);
      } else if (tex.trim().isNotEmpty) {
        result.add(
          MathSymbol(
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

class _SymbolSearchSheet extends StatefulWidget {
  final String Function(MathCategory category) categoryLabel;
  final ValueChanged<MathSymbol> onSelected;

  const _SymbolSearchSheet({
    required this.categoryLabel,
    required this.onSelected,
  });

  @override
  State<_SymbolSearchSheet> createState() => _SymbolSearchSheetState();
}

class _SymbolSearchSheetState extends State<_SymbolSearchSheet> {
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
    final query = _query.trim().toLowerCase();
    final symbols = mathSymbols.where((symbol) {
      final matchesCategory =
          _category == null || symbol.category == _category;
      final matchesQuery = query.isEmpty ||
          symbol.label.toLowerCase().contains(query) ||
          symbol.tex.toLowerCase().contains(query) ||
          symbol.category.name.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

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
                hintText: 'Try: angle, triangle, fraction, sigma…',
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
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontSize: 9,
                                          color:
                                              theme.colorScheme.onSurfaceVariant,
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

class _ActionBar extends ConsumerWidget {
  final bool compact;

  const _ActionBar({required this.compact});

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
