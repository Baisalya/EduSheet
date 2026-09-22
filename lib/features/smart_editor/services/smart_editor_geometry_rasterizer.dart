import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/geometry_builder/painters/geometry_painter.dart';

class SmartEditorGeometryRasterizer {
  const SmartEditorGeometryRasterizer();

  Future<Uint8List> toPng(
    GeometryDiagram diagram, {
    double scale = 2.0,
  }) async {
    final safeScale = scale.clamp(1.0, 4.0).toDouble();
    final logicalWidth = diagram.canvasSize.width.clamp(120.0, 1200.0).toDouble();
    final logicalHeight = diagram.canvasSize.height.clamp(90.0, 900.0).toDouble();
    final width = (logicalWidth * safeScale).round().clamp(1, 4096);
    final height = (logicalHeight * safeScale).round().clamp(1, 4096);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(safeScale, safeScale);
    GeometryPainter(
      diagram: diagram,
      showPointHandles: false,
    ).paint(canvas, ui.Size(logicalWidth, logicalHeight));
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(width, height);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw StateError('Could not encode geometry as PNG.');
        }
        return data.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }
}
