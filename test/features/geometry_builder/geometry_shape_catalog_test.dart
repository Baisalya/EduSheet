import 'package:edusheet/features/geometry_builder/models/geometry_shape.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_shape_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeometryShapeCatalog', () {
    test('covers every persisted geometry shape exactly once', () {
      final catalogTypes = GeometryShapeCatalog.all.map((entry) => entry.type).toList();

      expect(catalogTypes.toSet(), GeometryShapeType.values.toSet());
      expect(catalogTypes.length, GeometryShapeType.values.length);
    });

    test('every category exposed to teachers contains a supported shape', () {
      for (final category in GeometryShapeCategory.values) {
        final entries = GeometryShapeCatalog.inCategory(category);
        expect(entries, isNotEmpty, reason: '${category.name} must not be empty');
        expect(entries.every((entry) => entry.label.trim().isNotEmpty), isTrue);
        expect(entries.every((entry) => entry.description.trim().isNotEmpty), isTrue);
      }
    });
  });
}
