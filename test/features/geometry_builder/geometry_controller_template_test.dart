import 'package:edusheet/features/geometry_builder/controllers/geometry_controller.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_shape.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every supported teacher shape creates and serializes a diagram', () {
    for (final type in GeometryShapeType.values) {
      final controller = GeometryController();
      try {
        controller.loadTemplate(type);
        final diagram = controller.diagram;

        expect(diagram.shapes, hasLength(1), reason: type.name);
        expect(diagram.shapes.single.type, type, reason: type.name);
        expect(diagram.points, isNotEmpty, reason: type.name);

        final restored = GeometryDiagram.fromJson(diagram.toJson());
        expect(restored.shapes, hasLength(1), reason: '${type.name} restore');
        expect(
          restored.shapes.single.type,
          type,
          reason: '${type.name} restore',
        );
        expect(
          restored.points.length,
          diagram.points.length,
          reason: type.name,
        );
      } finally {
        controller.dispose();
      }
    }
  });
}
