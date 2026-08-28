import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../models/geometry_diagram.dart';
import '../painters/geometry_painter.dart';
import '../services/geometry_diagram_registry.dart';
import 'geometry_builder_screen.dart';

class GeometryEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'geometry';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = embedContext.node.value.data;
    var id = data.toString();
    var height = 200.0;
    var widthFactor = 1.0;
    var alignmentX = 0.0;
    GeometryDiagram? embeddedDiagram;

    try {
      if (data is String && data.trimLeft().startsWith('{')) {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          id = decoded['id']?.toString() ?? id;
          height = (decoded['height'] as num?)?.toDouble() ?? height;
          widthFactor =
              (decoded['widthFactor'] as num?)?.toDouble() ?? widthFactor;
          alignmentX =
              (decoded['alignmentX'] as num?)?.toDouble() ?? alignmentX;
          final diagramJson = decoded['diagram'];
          if (diagramJson is Map<String, dynamic>) {
            embeddedDiagram = GeometryDiagram.fromJson(diagramJson);
          } else if (diagramJson is Map) {
            embeddedDiagram = GeometryDiagram.fromJson(
              Map<String, dynamic>.from(diagramJson),
            );
          }
        }
      }
    } catch (_) {
      id = data.toString();
    }

    final diagram =
        GeometryDiagramRegistry.instance.diagramFor(id) ?? embeddedDiagram;
    if (diagram == null) {
      return Text('{{geometry:$id}}');
    }
    if (GeometryDiagramRegistry.instance.diagramFor(id) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (GeometryDiagramRegistry.instance.diagramFor(id) == null) {
          GeometryDiagramRegistry.instance.save(diagram);
        }
      });
    }

    return _InteractiveGeometryWrapper(
      id: id,
      height: height.clamp(90.0, 520.0).toDouble(),
      widthFactor: widthFactor.clamp(0.35, 1.0).toDouble(),
      alignmentX: alignmentX.clamp(-1.0, 1.0).toDouble(),
      diagram: diagram,
      interactive: !embedContext.readOnly,
      embedContext: embedContext,
    );
  }
}

class _InteractiveGeometryWrapper extends StatefulWidget {
  final String id;
  final double height;
  final double widthFactor;
  final double alignmentX;
  final GeometryDiagram diagram;
  final bool interactive;
  final EmbedContext embedContext;

  const _InteractiveGeometryWrapper({
    required this.id,
    required this.height,
    required this.widthFactor,
    required this.alignmentX,
    required this.diagram,
    required this.interactive,
    required this.embedContext,
  });

  @override
  State<_InteractiveGeometryWrapper> createState() =>
      _InteractiveGeometryWrapperState();
}

class _InteractiveGeometryWrapperState
    extends State<_InteractiveGeometryWrapper> {
  bool _isSelected = false;
  bool _isResizing = false;
  late double _currentHeight;
  late double _currentWidthFactor;
  late double _currentAlignmentX;
  late GeometryDiagram _diagram;

  @override
  void initState() {
    super.initState();
    _currentHeight = widget.height;
    _currentWidthFactor = widget.widthFactor;
    _currentAlignmentX = widget.alignmentX;
    _diagram = widget.diagram;
  }

  @override
  void didUpdateWidget(_InteractiveGeometryWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isResizing) {
      _currentHeight = widget.height;
      _currentWidthFactor = widget.widthFactor;
      _currentAlignmentX = widget.alignmentX;
    }
    if (oldWidget.diagram != widget.diagram) _diagram = widget.diagram;
  }

  int get _embedOffset {
    final node = widget.embedContext.node;
    return widget.embedContext.controller.document
        .queryChild(node.offset)
        .offset;
  }

  String _payload() => jsonEncode({
    'id': widget.id,
    'height': _currentHeight,
    'widthFactor': _currentWidthFactor,
    'alignmentX': _currentAlignmentX,
    'diagram': _diagram.toJson(),
  });

  void _commitLayout() {
    widget.embedContext.controller.replaceText(
      _embedOffset,
      1,
      BlockEmbed.custom(CustomBlockEmbed('geometry', _payload())),
      null,
    );
  }

  void _remove() {
    widget.embedContext.controller.replaceText(_embedOffset, 1, '', null);
  }

  Future<void> _editDiagram() async {
    final updated = await GeometryBuilderScreen.show(
      context,
      initialDiagram: _diagram,
    );
    if (updated == null || !mounted) return;
    GeometryDiagramRegistry.instance.save(updated);
    setState(() => _diagram = updated);
    _commitLayout();
  }

  void _setWidth(double widthFactor) {
    setState(() => _currentWidthFactor = widthFactor);
    _commitLayout();
  }

  void _setAlignment(double alignmentX) {
    setState(() => _currentAlignmentX = alignmentX);
    _commitLayout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final figureWidth = (availableWidth * _currentWidthFactor)
            .clamp(120.0, availableWidth)
            .toDouble();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.interactive && _isSelected) _buildMiniToolbar(theme),
              Align(
                alignment: Alignment(_currentAlignmentX, 0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.interactive
                      ? () => setState(() => _isSelected = !_isSelected)
                      : null,
                  onDoubleTap: widget.interactive ? _editDiagram : null,
                  onHorizontalDragUpdate: widget.interactive && _isSelected
                      ? (details) {
                          setState(() {
                            _currentAlignmentX =
                                (_currentAlignmentX +
                                        (details.delta.dx / availableWidth) * 2)
                                    .clamp(-1.0, 1.0)
                                    .toDouble();
                          });
                        }
                      : null,
                  onHorizontalDragEnd: widget.interactive && _isSelected
                      ? (_) => _commitLayout()
                      : null,
                  child: SizedBox(
                    width: figureWidth,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          height: _currentHeight,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.black.withValues(alpha: 0.12),
                              width: _isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              if (_isSelected)
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  blurRadius: 12,
                                ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: CustomPaint(
                              painter: GeometryPainter(
                                diagram: _diagram.copyWith(showGrid: false),
                                showPointHandles: false,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                        if (widget.interactive && _isSelected)
                          _ResizeHandle(
                            onStart: () => setState(() => _isResizing = true),
                            onUpdate: (details) {
                              setState(() {
                                _currentHeight =
                                    (_currentHeight + details.delta.dy)
                                        .clamp(90.0, 520.0)
                                        .toDouble();
                                _currentWidthFactor =
                                    (_currentWidthFactor +
                                            details.delta.dx / availableWidth)
                                        .clamp(0.35, 1.0)
                                        .toDouble();
                              });
                            },
                            onEnd: () {
                              setState(() => _isResizing = false);
                              _commitLayout();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  widget.interactive && _isSelected
                      ? 'Drag sideways to position • drag corner to resize • double-tap to edit'
                      : _diagram.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniToolbar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.tonalIcon(
            onPressed: _editDiagram,
            icon: const Icon(Icons.edit_rounded, size: 17),
            label: const Text('Edit'),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
          _ToolbarIcon(
            tooltip: 'Align left',
            icon: Icons.format_align_left_rounded,
            selected: _currentAlignmentX < -0.5,
            onPressed: () => _setAlignment(-1),
          ),
          _ToolbarIcon(
            tooltip: 'Align center',
            icon: Icons.format_align_center_rounded,
            selected: _currentAlignmentX.abs() <= 0.5,
            onPressed: () => _setAlignment(0),
          ),
          _ToolbarIcon(
            tooltip: 'Align right',
            icon: Icons.format_align_right_rounded,
            selected: _currentAlignmentX > 0.5,
            onPressed: () => _setAlignment(1),
          ),
          PopupMenuButton<double>(
            tooltip: 'Diagram width',
            icon: const Icon(Icons.aspect_ratio_rounded, size: 20),
            onSelected: _setWidth,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 0.5, child: Text('Half width')),
              PopupMenuItem(value: 0.75, child: Text('Three-quarter width')),
              PopupMenuItem(value: 1.0, child: Text('Full width')),
            ],
          ),
          IconButton(
            tooltip: 'Remove diagram',
            visualDensity: VisualDensity.compact,
            onPressed: _remove,
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _ToolbarIcon({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      isSelected: selected,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  final VoidCallback onStart;
  final ValueChanged<DragUpdateDetails> onUpdate;
  final VoidCallback onEnd;

  const _ResizeHandle({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => onStart(),
      onPanUpdate: onUpdate,
      onPanEnd: (_) => onEnd(),
      onPanCancel: onEnd,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpLeftDownRight,
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.open_in_full_rounded,
            size: 15,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
