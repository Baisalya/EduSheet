import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../application/geometry_embed_layout.dart';
import '../models/geometry_diagram.dart';
import '../painters/geometry_painter.dart';
import '../services/geometry_diagram_registry.dart';
import 'geometry_builder_screen.dart';

class GeometryEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'geometry';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final layout = GeometryEmbedLayout.fromData(embedContext.node.value.data);
    final diagram =
        GeometryDiagramRegistry.instance.diagramFor(layout.id) ??
        layout.diagram;
    if (diagram == null) {
      return Text('{{geometry:${layout.id}}}');
    }
    if (GeometryDiagramRegistry.instance.diagramFor(layout.id) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (GeometryDiagramRegistry.instance.diagramFor(layout.id) == null) {
          GeometryDiagramRegistry.instance.save(diagram);
        }
      });
    }

    return _InteractiveGeometryWrapper(
      layout: layout.copyWith(diagram: diagram),
      diagram: diagram,
      interactive: !embedContext.readOnly,
      embedContext: embedContext,
    );
  }
}

class _InteractiveGeometryWrapper extends StatefulWidget {
  final GeometryEmbedLayout layout;
  final GeometryDiagram diagram;
  final bool interactive;
  final EmbedContext embedContext;

  const _InteractiveGeometryWrapper({
    required this.layout,
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
  late double _marginTop;
  late double _marginBottom;
  late GeometryEmbedWrapMode _wrapMode;
  late GeometryDiagram _diagram;

  @override
  void initState() {
    super.initState();
    _loadLayout(widget.layout);
    _diagram = widget.diagram;
  }

  @override
  void didUpdateWidget(_InteractiveGeometryWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isResizing && oldWidget.layout != widget.layout) {
      _loadLayout(widget.layout);
    }
    if (oldWidget.diagram != widget.diagram) _diagram = widget.diagram;
  }

  void _loadLayout(GeometryEmbedLayout layout) {
    final normalized = layout.normalized();
    _currentHeight = normalized.height;
    _currentWidthFactor = normalized.widthFactor;
    _currentAlignmentX = normalized.alignmentX;
    _marginTop = normalized.marginTop;
    _marginBottom = normalized.marginBottom;
    _wrapMode = normalized.wrapMode;
  }

  int get _embedOffset {
    final node = widget.embedContext.node;
    return widget.embedContext.controller.document
        .queryChild(node.offset)
        .offset;
  }

  GeometryEmbedLayout get _currentLayout => GeometryEmbedLayout(
    id: widget.layout.id,
    diagram: _diagram,
    height: _currentHeight,
    widthFactor: _currentWidthFactor,
    alignmentX: _currentAlignmentX,
    marginTop: _marginTop,
    marginBottom: _marginBottom,
    wrapMode: _wrapMode,
  ).normalized();

  String _payload() => _currentLayout.encode(diagramOverride: _diagram);

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
    setState(() {
      _currentAlignmentX = alignmentX;
      if (_wrapMode == GeometryEmbedWrapMode.squareLeft ||
          _wrapMode == GeometryEmbedWrapMode.squareRight) {
        _wrapMode = GeometryEmbedWrapMode.topAndBottom;
      }
    });
    _commitLayout();
  }

  void _setWrap(GeometryEmbedWrapMode mode) {
    setState(() {
      _wrapMode = mode;
      if (mode == GeometryEmbedWrapMode.squareLeft) {
        _currentAlignmentX = -1;
      } else if (mode == GeometryEmbedWrapMode.squareRight) {
        _currentAlignmentX = 1;
      }
    });
    _commitLayout();
  }

  void _setSpacing(_GeometrySpacingPreset preset) {
    setState(() {
      _marginTop = preset.space;
      _marginBottom = preset.space;
    });
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
        final effectiveAlignment = _currentLayout.effectiveAlignmentX;

        return Container(
          key: ValueKey('geometry-embed-${widget.layout.id}'),
          width: double.infinity,
          margin: EdgeInsets.only(top: _marginTop, bottom: _marginBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.interactive && _isSelected) _buildMiniToolbar(theme),
              Align(
                alignment: Alignment(effectiveAlignment, 0),
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
                            if (_wrapMode == GeometryEmbedWrapMode.squareLeft ||
                                _wrapMode ==
                                    GeometryEmbedWrapMode.squareRight) {
                              _wrapMode = GeometryEmbedWrapMode.topAndBottom;
                            }
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
                      : '${_diagram.name} • ${_wrapMode.label}',
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
            selected: _currentLayout.effectiveAlignmentX < -0.5,
            onPressed: () => _setAlignment(-1),
          ),
          _ToolbarIcon(
            tooltip: 'Align center',
            icon: Icons.format_align_center_rounded,
            selected: _currentLayout.effectiveAlignmentX.abs() <= 0.5,
            onPressed: () => _setAlignment(0),
          ),
          _ToolbarIcon(
            tooltip: 'Align right',
            icon: Icons.format_align_right_rounded,
            selected: _currentLayout.effectiveAlignmentX > 0.5,
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
          PopupMenuButton<GeometryEmbedWrapMode>(
            tooltip: 'Text wrapping / anchor',
            icon: const Icon(Icons.wrap_text_rounded, size: 20),
            onSelected: _setWrap,
            itemBuilder: (context) => [
              for (final mode in GeometryEmbedWrapMode.values)
                PopupMenuItem(value: mode, child: Text(mode.label)),
            ],
          ),
          PopupMenuButton<_GeometrySpacingPreset>(
            tooltip: 'Space around diagram',
            icon: const Icon(Icons.height_rounded, size: 20),
            onSelected: _setSpacing,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _GeometrySpacingPreset.compact,
                child: Text('Compact spacing'),
              ),
              PopupMenuItem(
                value: _GeometrySpacingPreset.normal,
                child: Text('Normal spacing'),
              ),
              PopupMenuItem(
                value: _GeometrySpacingPreset.spacious,
                child: Text('Spacious spacing'),
              ),
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

enum _GeometrySpacingPreset {
  compact(6),
  normal(10),
  spacious(18);

  final double space;
  const _GeometrySpacingPreset(this.space);
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
