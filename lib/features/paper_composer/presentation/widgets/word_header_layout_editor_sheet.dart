import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_header_layout_canvas.dart';
import 'package:edusheet/features/pdf/application/paper_header_layout_factory.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';

/// Header-only free-placement editor.
///
/// The body remains flow based and safe for long papers. Header elements can be
/// dragged, resized and aligned because that area is finite and is already
/// represented by [CustomLayout] in the export architecture.
class WordHeaderLayoutEditorSheet extends StatefulWidget {
  final Paper paper;
  final PaperTemplate template;

  const WordHeaderLayoutEditorSheet({
    super.key,
    required this.paper,
    required this.template,
  });

  static Future<CustomLayout?> show(
    BuildContext context, {
    required Paper paper,
    required PaperTemplate template,
  }) {
    return showAdaptiveModalBottomSheet<CustomLayout>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.96,
        child: WordHeaderLayoutEditorSheet(paper: paper, template: template),
      ),
    );
  }

  @override
  State<WordHeaderLayoutEditorSheet> createState() =>
      _WordHeaderLayoutEditorSheetState();
}

class _WordHeaderLayoutEditorSheetState
    extends State<WordHeaderLayoutEditorSheet> {
  static const _grid = 6.0;

  late CustomLayout _base;
  late List<TemplateElement> _elements;
  late double _canvasHeight;
  bool _snap = true;
  String? _selectedId;
  Offset? _dragStartGlobal;
  double? _dragStartX;
  double? _dragStartY;

  @override
  void initState() {
    super.initState();
    _base = PaperHeaderLayoutFactory.resolveForPaper(
      widget.template,
      widget.paper,
    );
    _elements = [..._base.elements];
    _canvasHeight = _base.canvasHeight;
  }

  TemplateElement? get _selected {
    final id = _selectedId;
    if (id == null) {
      return null;
    }
    for (final element in _elements) {
      if (element.id == id) {
        return element;
      }
    }
    return null;
  }

  double _snapValue(double value) {
    if (!_snap) {
      return value;
    }
    return (value / _grid).roundToDouble() * _grid;
  }

  String _newElementId(String prefix) {
    var index = _elements.length + 1;
    while (_elements.any((element) => element.id == '$prefix-$index')) {
      index++;
    }
    return '$prefix-$index';
  }

  void _replace(TemplateElement element) {
    final index = _elements.indexWhere((item) => item.id == element.id);
    if (index < 0) {
      return;
    }
    setState(() => _elements[index] = element);
  }

  void _startDrag(TemplateElement element, Offset globalPosition) {
    setState(() {
      _selectedId = element.id;
      _dragStartGlobal = globalPosition;
      _dragStartX = element.x;
      _dragStartY = element.y;
    });
  }

  void _drag(TemplateElement element, Offset globalPosition, double scale) {
    final start = _dragStartGlobal;
    final startX = _dragStartX;
    final startY = _dragStartY;
    if (start == null || startX == null || startY == null || scale <= 0) {
      return;
    }
    final delta = (globalPosition - start) / scale;
    final maxX = (CustomLayout.designWidth - (element.width ?? 24))
        .clamp(0, CustomLayout.designWidth)
        .toDouble();
    final maxY = (_canvasHeight - (element.height ?? 14))
        .clamp(0, _canvasHeight)
        .toDouble();
    final x = _snapValue((startX + delta.dx).clamp(0, maxX).toDouble());
    final y = _snapValue((startY + delta.dy).clamp(0, maxY).toDouble());
    _replace(element.copyWith(x: x, y: y));
  }

  void _endDrag() {
    _dragStartGlobal = null;
    _dragStartX = null;
    _dragStartY = null;
  }

  void _align(String alignment) {
    final element = _selected;
    if (element == null) {
      return;
    }
    final width = element.width ?? 100;
    final x = switch (alignment) {
      'left' => 0.0,
      'center' => (CustomLayout.designWidth - width) / 2,
      'right' => CustomLayout.designWidth - width,
      _ => element.x,
    };
    final properties = Map<String, dynamic>.from(element.properties)
      ..['alignment'] = alignment;
    _replace(
      element.copyWith(
        x: _snapValue(x.clamp(0, CustomLayout.designWidth).toDouble()),
        properties: properties,
      ),
    );
  }

  void _addText() {
    final element = TemplateElement(
      id: _newElementId('custom-text'),
      type: ElementType.staticText,
      x: 0,
      y: _snapValue((_canvasHeight - 28).clamp(0, _canvasHeight).toDouble()),
      width: CustomLayout.designWidth,
      height: 22,
      content: 'Additional header text',
      properties: const {'fontSize': 10.5, 'alignment': 'center'},
    );
    setState(() {
      _elements.add(element);
      _selectedId = element.id;
    });
  }

  void _addLine() {
    final element = TemplateElement(
      id: _newElementId('custom-line'),
      type: ElementType.horizontalLine,
      x: 0,
      y: _snapValue((_canvasHeight - 10).clamp(0, _canvasHeight).toDouble()),
      width: CustomLayout.designWidth,
      properties: {
        'color': widget.template.primaryColor.toInt(),
        'thickness': 1.0,
      },
    );
    setState(() {
      _elements.add(element);
      _selectedId = element.id;
    });
  }

  void _addLogo() {
    final element = TemplateElement(
      id: _newElementId('custom-logo'),
      type: ElementType.logo,
      x: 0,
      y: 0,
      width: 48,
      height: 48,
    );
    setState(() {
      _elements.add(element);
      _selectedId = element.id;
    });
  }

  void _deleteSelected() {
    final selected = _selected;
    if (selected == null) {
      return;
    }
    if (selected.type == ElementType.schoolName ||
        selected.type == ElementType.paperTitle ||
        selected.type == ElementType.headerFieldsBlock ||
        selected.type == ElementType.maxMarks) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Core paper fields stay in the header. Move or resize them instead.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _elements.removeWhere((element) => element.id == selected.id);
      _selectedId = null;
    });
  }

  void _reset() {
    setState(() {
      _elements = [..._base.elements];
      _canvasHeight = _base.canvasHeight;
      _selectedId = null;
    });
  }

  void _save() {
    Navigator.pop(
      context,
      CustomLayout(
        elements: List.unmodifiable(_elements),
        canvasHeight: _canvasHeight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 10, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Arrange header',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Drag header elements. Snap keeps print alignment clean; the question body remains flow-safe.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 920;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 7,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: _buildCanvasPanel(context),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 330,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                        child: _buildProperties(context),
                      ),
                    ),
                  ],
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCanvasPanel(context),
                    const SizedBox(height: 18),
                    _buildProperties(context),
                  ],
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset'),
                ),
                const Spacer(),
                FilledButton.icon(
                  key: const Key('header-layout-save'),
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Use this layout'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCanvasPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              selected: _snap,
              onSelected: (value) => setState(() => _snap = value),
              avatar: const Icon(Icons.grid_4x4_rounded, size: 18),
              label: const Text('Snap 6 pt'),
            ),
            OutlinedButton.icon(
              onPressed: _addText,
              icon: const Icon(Icons.text_fields_rounded),
              label: const Text('Text'),
            ),
            OutlinedButton.icon(
              onPressed: _addLine,
              icon: const Icon(Icons.horizontal_rule_rounded),
              label: const Text('Line'),
            ),
            OutlinedButton.icon(
              onPressed: _addLogo,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Logo slot'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Center(
            child: _HeaderDesignerCanvas(
              paper: widget.paper,
              template: widget.template,
              elements: _elements,
              canvasHeight: _canvasHeight,
              selectedId: _selectedId,
              snapGrid: _snap ? _grid : null,
              onSelect: (id) => setState(() => _selectedId = id),
              onDragStart: _startDrag,
              onDragUpdate: _drag,
              onDragEnd: _endDrag,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProperties(BuildContext context) {
    final selected = _selected;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Header canvas',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _SliderRow(
          label: 'Header height',
          value: _canvasHeight,
          min: 90,
          max: 300,
          onChanged: (value) => setState(
            () => _canvasHeight = _snapValue(value).clamp(90, 300).toDouble(),
          ),
        ),
        const SizedBox(height: 18),
        if (selected == null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Select an element on the page to change its position, width, alignment or typography.',
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  _elementLabel(selected.type),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Delete element',
                onPressed: _deleteSelected,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SliderRow(
            label: 'X',
            value: selected.x,
            min: 0,
            max: (CustomLayout.designWidth - (selected.width ?? 24))
                .clamp(0, CustomLayout.designWidth)
                .toDouble(),
            onChanged: (value) =>
                _replace(selected.copyWith(x: _snapValue(value))),
          ),
          _SliderRow(
            label: 'Y',
            value: selected.y,
            min: 0,
            max: (_canvasHeight - (selected.height ?? 14))
                .clamp(0, _canvasHeight)
                .toDouble(),
            onChanged: (value) =>
                _replace(selected.copyWith(y: _snapValue(value))),
          ),
          _SliderRow(
            label: 'Width',
            value: (selected.width ?? 100)
                .clamp(24, CustomLayout.designWidth)
                .toDouble(),
            min: 24,
            max: (CustomLayout.designWidth - selected.x)
                .clamp(24, CustomLayout.designWidth)
                .toDouble(),
            onChanged: (value) => _replace(
              selected.copyWith(
                width: _snapValue(
                  value,
                ).clamp(24, CustomLayout.designWidth - selected.x).toDouble(),
              ),
            ),
          ),
          if (selected.type == ElementType.logo ||
              selected.type == ElementType.rectangular ||
              selected.type == ElementType.headerFieldsBlock)
            _SliderRow(
              label: 'Height',
              value: (selected.height ?? 48).clamp(16, 180).toDouble(),
              min: 16,
              max: 180,
              onChanged: (value) => _replace(
                selected.copyWith(
                  height: _snapValue(value).clamp(16, 180).toDouble(),
                ),
              ),
            ),
          if (_supportsText(selected.type)) ...[
            const SizedBox(height: 10),
            Text('Alignment', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'left',
                  icon: Icon(Icons.format_align_left_rounded),
                ),
                ButtonSegment(
                  value: 'center',
                  icon: Icon(Icons.format_align_center_rounded),
                ),
                ButtonSegment(
                  value: 'right',
                  icon: Icon(Icons.format_align_right_rounded),
                ),
              ],
              selected: {
                selected.properties['alignment']?.toString() ?? 'left',
              },
              onSelectionChanged: (selection) => _align(selection.first),
            ),
            const SizedBox(height: 10),
            _SliderRow(
              label: 'Font size',
              value:
                  ((selected.properties['fontSize'] as num?)?.toDouble() ?? 12)
                      .clamp(8, 30)
                      .toDouble(),
              min: 8,
              max: 30,
              onChanged: (value) {
                final properties = Map<String, dynamic>.from(
                  selected.properties,
                )..['fontSize'] = value;
                _replace(selected.copyWith(properties: properties));
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bold'),
              value: selected.properties['bold'] == true,
              onChanged: (value) {
                final properties = Map<String, dynamic>.from(
                  selected.properties,
                )..['bold'] = value;
                _replace(selected.copyWith(properties: properties));
              },
            ),
          ],
          if (selected.type == ElementType.staticText) ...[
            const SizedBox(height: 8),
            TextFormField(
              initialValue: selected.content,
              decoration: const InputDecoration(labelText: 'Text'),
              onChanged: (value) => _replace(selected.copyWith(content: value)),
            ),
          ],
        ],
      ],
    );
  }

  static bool _supportsText(ElementType type) =>
      type == ElementType.schoolName ||
      type == ElementType.paperTitle ||
      type == ElementType.maxMarks ||
      type == ElementType.headerFieldsBlock ||
      type == ElementType.staticText ||
      type == ElementType.rectangular;

  static String _elementLabel(ElementType type) => switch (type) {
    ElementType.schoolName => 'School / institution',
    ElementType.paperTitle => 'Paper title',
    ElementType.logo => 'Logo',
    ElementType.maxMarks => 'Maximum marks',
    ElementType.headerFieldsBlock => 'Metadata fields',
    ElementType.staticText => 'Text box',
    ElementType.horizontalLine => 'Horizontal line',
    ElementType.rectangular => 'Box',
  };
}

class _HeaderDesignerCanvas extends StatelessWidget {
  final Paper paper;
  final PaperTemplate template;
  final List<TemplateElement> elements;
  final double canvasHeight;
  final String? selectedId;
  final double? snapGrid;
  final ValueChanged<String> onSelect;
  final void Function(TemplateElement element, Offset globalPosition)
  onDragStart;
  final void Function(
    TemplateElement element,
    Offset globalPosition,
    double scale,
  )
  onDragUpdate;
  final VoidCallback onDragEnd;

  const _HeaderDesignerCanvas({
    required this.paper,
    required this.template,
    required this.elements,
    required this.canvasHeight,
    required this.selectedId,
    required this.snapGrid,
    required this.onSelect,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : CustomLayout.designWidth;
        final scale = (available / CustomLayout.designWidth)
            .clamp(0.45, 1.15)
            .toDouble();
        return SizedBox(
          width: CustomLayout.designWidth * scale,
          height: canvasHeight * scale,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: CustomLayout.designWidth,
              height: canvasHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black26),
                      ),
                      child: snapGrid == null
                          ? null
                          : CustomPaint(
                              painter: _HeaderGridPainter(spacing: snapGrid!),
                            ),
                    ),
                  ),
                  for (final element in elements)
                    Positioned(
                      left: element.x,
                      top: element.y,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(element.id),
                        onPanStart: (details) =>
                            onDragStart(element, details.globalPosition),
                        onPanUpdate: (details) => onDragUpdate(
                          element,
                          details.globalPosition,
                          scale,
                        ),
                        onPanEnd: (_) => onDragEnd(),
                        child: Container(
                          constraints: BoxConstraints(
                            minWidth: element.type == ElementType.horizontalLine
                                ? (element.width ?? 100)
                                : 16,
                            minHeight:
                                element.type == ElementType.horizontalLine
                                ? 12
                                : 16,
                          ),
                          decoration: element.id == selectedId
                              ? BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    width: 1.2,
                                  ),
                                )
                              : null,
                          child: element.type == ElementType.horizontalLine
                              ? Center(
                                  child: PaperHeaderElementView(
                                    element: element,
                                    paper: paper,
                                    template: template,
                                  ),
                                )
                              : PaperHeaderElementView(
                                  element: element,
                                  paper: paper,
                                  template: template,
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderGridPainter extends CustomPainter {
  final double spacing;

  const _HeaderGridPainter({required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeaderGridPainter oldDelegate) =>
      oldDelegate.spacing != spacing;
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(min, max).toDouble();
    return Row(
      children: [
        SizedBox(width: 82, child: Text(label)),
        Expanded(
          child: Slider(
            value: safeValue,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 46,
          child: Text(safeValue.toStringAsFixed(0), textAlign: TextAlign.right),
        ),
      ],
    );
  }
}
