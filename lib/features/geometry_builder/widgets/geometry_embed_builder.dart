import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../services/geometry_diagram_registry.dart';
import '../painters/geometry_painter.dart';

class GeometryEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'geometry';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = embedContext.node.value.data;
    String id;
    double height = 200.0;

    try {
      if (data is String && data.startsWith('{')) {
        final map = jsonDecode(data);
        id = map['id'];
        height = (map['height'] as num?)?.toDouble() ?? 200.0;
      } else {
        id = data.toString();
      }
    } catch (e) {
      id = data.toString();
    }

    final diagram = GeometryDiagramRegistry.instance.diagramFor(id);

    if (diagram == null) {
      return Text('{{geometry:$id}}');
    }

    return _InteractiveGeometryWrapper(
      id: id,
      height: height,
      diagram: diagram,
      embedContext: embedContext,
    );
  }
}

class _InteractiveGeometryWrapper extends StatefulWidget {
  final String id;
  final double height;
  final dynamic diagram;
  final EmbedContext embedContext;

  const _InteractiveGeometryWrapper({
    required this.id,
    required this.height,
    required this.diagram,
    required this.embedContext,
  });

  @override
  State<_InteractiveGeometryWrapper> createState() =>
      _InteractiveGeometryWrapperState();
}

class _InteractiveGeometryWrapperState
    extends State<_InteractiveGeometryWrapper> {
  bool _isSelected = false;
  late double _currentHeight;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentHeight = widget.height;
  }

  @override
  void didUpdateWidget(_InteractiveGeometryWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && oldWidget.height != widget.height) {
      _currentHeight = widget.height;
    }
  }

  void _commitNewSize() {
    final controller = widget.embedContext.controller;
    final node = widget.embedContext.node;
    final offset = widget.embedContext.controller.document
        .queryChild(node.offset)
        .offset;

    final newData = jsonEncode({'id': widget.id, 'height': _currentHeight});

    controller.replaceText(
      offset,
      1,
      BlockEmbed.custom(CustomBlockEmbed('geometry', newData)),
      null,
    );
  }

  void _remove() {
    final controller = widget.embedContext.controller;
    final node = widget.embedContext.node;
    final offset = widget.embedContext.controller.document
        .queryChild(node.offset)
        .offset;
    controller.replaceText(offset, 1, '', null);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isSelected = !_isSelected),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isSelected) _buildMiniToolbar(),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isSelected
                          ? Colors.blue
                          : Colors.black.withValues(alpha: 0.1),
                      width: _isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      if (_isSelected)
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.1),
                          blurRadius: 12,
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: _currentHeight,
                      width: double.infinity,
                      color: Colors.white,
                      child: CustomPaint(
                        painter: GeometryPainter(
                          diagram: widget.diagram.copyWith(showGrid: false),
                          showPointHandles: false,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isSelected) _buildDragHandle(),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                widget.diagram.name,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniToolbar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Geometry Figure',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: _remove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      onPanStart: (_) {
        setState(() => _isDragging = true);
      },
      onPanUpdate: (details) {
        setState(() {
          _currentHeight = (_currentHeight + details.delta.dy).clamp(
            80.0,
            600.0,
          );
        });
      },
      onPanEnd: (_) {
        setState(() => _isDragging = false);
        _commitNewSize();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.open_in_full, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}
