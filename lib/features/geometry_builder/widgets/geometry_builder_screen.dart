import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/geometry_controller.dart';
import '../models/geometry_diagram.dart';
import '../models/geometry_label.dart';
import '../models/geometry_mark.dart';
import '../models/geometry_shape.dart';
import 'export_panel.dart';
import 'geometry_canvas.dart';
import 'geometry_toolbar.dart';
import 'label_editor_sheet.dart';
import 'shape_picker.dart';

class GeometryBuilderScreen extends StatefulWidget {
  final GeometryDiagram? initialDiagram;
  final GeometryShapeType? initialShape;
  final double? maxHeight;

  const GeometryBuilderScreen({
    super.key,
    this.initialDiagram,
    this.initialShape,
    this.maxHeight,
  });

  static Future<GeometryDiagram?> show(
    BuildContext context, {
    GeometryDiagram? initialDiagram,
    GeometryShapeType? initialShape,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    final view = View.of(context);
    final fullHeight = view.physicalSize.height / view.devicePixelRatio;
    final sheetHeight = fullHeight * 0.92;

    return showGeneralDialog<GeometryDiagram>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: 1,
                child: GeometryBuilderScreen(
                  maxHeight: sheetHeight,
                  initialDiagram: initialDiagram,
                  initialShape: initialShape,
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<GeometryBuilderScreen> createState() => _GeometryBuilderScreenState();
}

class _GeometryBuilderScreenState extends State<GeometryBuilderScreen> {
  late final GeometryController _controller;
  final _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = GeometryController(initialDiagram: widget.initialDiagram);
    final initialShape = widget.initialShape;
    if (initialShape != null && widget.initialDiagram == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.loadTemplate(initialShape);
      });
    } else if (widget.initialDiagram == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.loadTemplate(GeometryShapeType.triangle);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaHeight = MediaQuery.sizeOf(context).height;
    final height = widget.maxHeight ?? mediaHeight * 0.9;
    final compact = height < 560;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SizedBox(
        height: height,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Geometry Builder'),
            toolbarHeight: compact ? 48 : kToolbarHeight,
            actions: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(_controller.diagram),
                  icon: const Icon(Icons.check),
                  label: const Text('Insert'),
                ),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final canvasHeight = (constraints.maxHeight * 0.36).clamp(
                compact ? 96.0 : 140.0,
                compact ? 160.0 : 238.0,
              );

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, compact ? 6 : 8, 12, 0),
                    child: SizedBox(
                      height: canvasHeight,
                      width: double.infinity,
                      child: GeometryCanvas(
                        controller: _controller,
                        repaintKey: _repaintKey,
                      ),
                    ),
                  ),
                  _ModeBar(controller: _controller, compact: compact),
                  Expanded(
                    child: _ModeBody(
                      controller: _controller,
                      repaintKey: _repaintKey,
                    ),
                  ),
                  GeometryToolbar(
                    controller: _controller,
                    onAddSideLabel: () =>
                        _showLabelEditor(GeometryLabelType.side),
                    onAddAngleLabel: () =>
                        _showLabelEditor(GeometryLabelType.angle),
                    onAddTextLabel: () =>
                        _showLabelEditor(GeometryLabelType.custom),
                    onAddRightAngle: () =>
                        _controller.addMark(GeometryMarkType.rightAngle),
                    onAddHeightLine: () =>
                        _controller.addMark(GeometryMarkType.dashedHeightLine),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showLabelEditor(GeometryLabelType type) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => LabelEditorSheet(
        type: type,
        onSubmitted: (text) => _controller.addLabel(type, text),
      ),
    );
  }
}

class _ModeBar extends StatelessWidget {
  final GeometryController controller;
  final bool compact;

  const _ModeBar({required this.controller, required this.compact});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return SizedBox(
          height: compact ? 42 : 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: compact ? 5 : 8,
            ),
            children: [
              _ModeChip(
                'Shapes',
                Icons.category_outlined,
                GeometryBuilderMode.shapes,
                controller,
              ),
              _ModeChip(
                'Draw',
                Icons.edit_outlined,
                GeometryBuilderMode.draw,
                controller,
              ),
              _ModeChip(
                'Labels',
                Icons.label_outline,
                GeometryBuilderMode.labels,
                controller,
              ),
              _ModeChip(
                'Marks',
                Icons.gesture,
                GeometryBuilderMode.marks,
                controller,
              ),
              _ModeChip(
                'Export',
                Icons.ios_share,
                GeometryBuilderMode.export,
                controller,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final GeometryBuilderMode mode;
  final GeometryController controller;

  const _ModeChip(this.label, this.icon, this.mode, this.controller);

  @override
  Widget build(BuildContext context) {
    final selected = controller.mode == mode;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        avatar: Icon(icon, size: 16),
        label: Text(label),
        onSelected: (_) => controller.mode = mode,
      ),
    );
  }
}

class _ModeBody extends StatelessWidget {
  final GeometryController controller;
  final GlobalKey repaintKey;

  const _ModeBody({required this.controller, required this.repaintKey});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return switch (controller.mode) {
          GeometryBuilderMode.shapes => ShapePicker(
            onSelected: (shape) => controller.loadTemplate(shape),
          ),
          GeometryBuilderMode.draw => _DrawHelp(controller: controller),
          GeometryBuilderMode.labels => _LabelButtons(controller: controller),
          GeometryBuilderMode.marks => _MarkButtons(controller: controller),
          GeometryBuilderMode.export => ExportPanel(
            controller: controller,
            repaintKey: repaintKey,
          ),
        };
      },
    );
  }
}

class _DrawHelp extends StatelessWidget {
  final GeometryController controller;

  const _DrawHelp({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Tap the canvas to add points. Two points make a line, three make a triangle, and more points make a polygon.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: controller.clear,
          icon: const Icon(Icons.add),
          label: const Text('Start new custom polygon'),
        ),
      ],
    );
  }
}

class _LabelButtons extends StatelessWidget {
  final GeometryController controller;

  const _LabelButtons({required this.controller});

  @override
  Widget build(BuildContext context) {
    final labels = <(GeometryLabelType, String, IconData)>[
      (GeometryLabelType.side, 'Side label', Icons.straighten),
      (GeometryLabelType.angle, 'Angle label', Icons.architecture),
      (GeometryLabelType.height, 'Height label', Icons.height),
      (GeometryLabelType.width, 'Width label', Icons.width_full),
      (GeometryLabelType.radius, 'Radius label', Icons.radio_button_unchecked),
      (GeometryLabelType.diameter, 'Diameter label', Icons.horizontal_rule),
      (GeometryLabelType.area, 'Area label', Icons.square_foot),
      (GeometryLabelType.perimeter, 'Perimeter label', Icons.crop_free),
      (GeometryLabelType.custom, 'Custom text', Icons.text_fields),
    ];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final item in labels)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton.tonalIcon(
              onPressed: () => _openLabelSheet(context, item.$1),
              icon: Icon(item.$3),
              label: Text(item.$2),
            ),
          ),
      ],
    );
  }

  void _openLabelSheet(BuildContext context, GeometryLabelType type) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => LabelEditorSheet(
        type: type,
        onSubmitted: (text) => controller.addLabel(type, text),
      ),
    );
  }
}

class _MarkButtons extends StatelessWidget {
  final GeometryController controller;

  const _MarkButtons({required this.controller});

  @override
  Widget build(BuildContext context) {
    final marks = <(GeometryMarkType, String, IconData)>[
      (GeometryMarkType.angleArc, 'Angle arc', Icons.architecture),
      (GeometryMarkType.rightAngle, 'Right angle mark', Icons.crop_square),
      (GeometryMarkType.equalSideTick, 'Equal side tick', Icons.done),
      (GeometryMarkType.parallelLine, 'Parallel mark', Icons.drag_handle),
      (
        GeometryMarkType.dottedConstructionLine,
        'Dotted construction line',
        Icons.more_horiz,
      ),
      (
        GeometryMarkType.dashedHeightLine,
        'Dashed height line',
        Icons.more_vert,
      ),
      (
        GeometryMarkType.radiusLine,
        'Radius line',
        Icons.radio_button_unchecked,
      ),
      (GeometryMarkType.diameterLine, 'Diameter line', Icons.horizontal_rule),
      (GeometryMarkType.arrowHead, 'Arrow head', Icons.arrow_forward),
      (GeometryMarkType.doubleArrow, 'Double arrow', Icons.compare_arrows),
      (GeometryMarkType.curvedArc, 'Curved arc', Icons.rotate_right),
      (GeometryMarkType.centerPoint, 'Center point', Icons.center_focus_strong),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.2,
      ),
      itemCount: marks.length,
      itemBuilder: (context, index) {
        final mark = marks[index];
        return FilledButton.tonalIcon(
          onPressed: () => controller.addMark(mark.$1),
          icon: Icon(mark.$3),
          label: Text(mark.$2, overflow: TextOverflow.ellipsis),
        );
      },
    );
  }
}
