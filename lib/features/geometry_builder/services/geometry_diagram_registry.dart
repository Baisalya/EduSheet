import 'package:flutter/foundation.dart';

import '../models/geometry_diagram.dart';

class GeometryDiagramRegistry extends ChangeNotifier {
  GeometryDiagramRegistry._();

  static final GeometryDiagramRegistry instance = GeometryDiagramRegistry._();

  final Map<String, GeometryDiagram> _diagrams = {};

  GeometryDiagram? diagramFor(String id) => _diagrams[id];

  void save(GeometryDiagram diagram) {
    _diagrams[diagram.id] = diagram;
    notifyListeners();
  }

  void remove(String id) {
    if (_diagrams.remove(id) != null) notifyListeners();
  }
}
