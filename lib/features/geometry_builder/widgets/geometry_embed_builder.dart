import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../services/geometry_diagram_registry.dart';
import '../painters/geometry_painter.dart';

class GeometryEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'geometry';

  @override
  Widget build(
    BuildContext context,
    EmbedContext embedContext,
  ) {
    final id = embedContext.node.value.data;
    final diagram = GeometryDiagramRegistry.instance.diagramFor(id);

    if (diagram == null) {
      return Text('{{geometry:$id}}');
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: CustomPaint(
              painter: GeometryPainter(
                diagram: diagram.copyWith(showGrid: false),
                showPointHandles: false,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            diagram.name,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
