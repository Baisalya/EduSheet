import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../models/geometry_diagram.dart';
import 'geometry_svg_service.dart';

class GeometryExportService {
  Future<Uint8List> capturePng(
    GlobalKey repaintKey, {
    double pixelRatio = 3,
  }) async {
    final boundary =
        repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Geometry canvas is not ready for export.');
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Could not encode geometry diagram as PNG.');
    }
    return byteData.buffer.asUint8List();
  }

  Future<File> savePng(GeometryDiagram diagram, Uint8List bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory(
      '${directory.path}${Platform.pathSeparator}EduSheet Geometry',
    );
    if (!await folder.exists()) await folder.create(recursive: true);
    final file = File(
      '${folder.path}${Platform.pathSeparator}${_fileName(diagram)}.png',
    );
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<File> saveSvg(GeometryDiagram diagram) async {
    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory(
      '${directory.path}${Platform.pathSeparator}EduSheet Geometry',
    );
    if (!await folder.exists()) await folder.create(recursive: true);
    final file = File(
      '${folder.path}${Platform.pathSeparator}${_fileName(diagram)}.svg',
    );
    return file.writeAsString(GeometrySvgService().toSvg(diagram), flush: true);
  }

  String _fileName(GeometryDiagram diagram) {
    final safeName = diagram.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '${safeName.isEmpty ? 'geometry_diagram' : safeName}_${diagram.id.substring(0, 8)}';
  }
}
