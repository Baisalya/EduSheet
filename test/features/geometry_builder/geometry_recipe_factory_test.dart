
import 'package:edusheet/features/geometry_builder/application/geometry_recipe.dart';
import 'package:edusheet/features/geometry_builder/application/geometry_recipe_factory.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_mark.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_shape.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const factory = GeometryRecipeFactory();

  test('every persisted shape still has a teacher recipe and round-trips', () {
    for (final type in GeometryShapeType.values) {
      final matches = GeometryRecipeCatalog.all.where(
        (recipe) => recipe.baseShape == type,
      );
      expect(matches, isNotEmpty, reason: type.name);

      final diagram = factory.buildShape(type);
      final restored = GeometryDiagram.fromJson(diagram.toJson());
      expect(restored.shapes.single.type, type, reason: type.name);
    }
  });

  test('base templates do not invent measurements for the teacher', () {
    for (final type in GeometryShapeType.values) {
      final diagram = factory.buildShape(type);
      expect(diagram.labels, isEmpty, reason: type.name);
      expect(
        diagram.points.every(
          (point) => !RegExp(r'\d+\s*(cm|mm|m|°)').hasMatch(point.label),
        ),
        isTrue,
        reason: type.name,
      );
    }
  });

  test('smart triangle recipes encode the mathematical meaning with marks', () {
    final isosceles = factory.build(GeometryRecipeCatalog.isoscelesTriangle);
    expect(
      isosceles.marks.where((mark) => mark.type == GeometryMarkType.equalSideTick),
      hasLength(2),
    );

    final equilateral = factory.build(GeometryRecipeCatalog.equilateralTriangle);
    expect(
      equilateral.marks.where((mark) => mark.type == GeometryMarkType.equalSideTick),
      hasLength(3),
    );

    final points = equilateral.points;
    final ab = (points[0].position - points[1].position).distance;
    final bc = (points[1].position - points[2].position).distance;
    final ca = (points[2].position - points[0].position).distance;
    expect((ab - bc).abs(), lessThan(1.0));
    expect((bc - ca).abs(), lessThan(1.0));
  });

  test('circle and line constructions use existing persisted primitives', () {
    final radius = factory.build(GeometryRecipeCatalog.circleRadius);
    expect(radius.shapes.single.type, GeometryShapeType.circle);
    expect(radius.marks.any((mark) => mark.type == GeometryMarkType.radiusLine), isTrue);

    final parallel = factory.build(GeometryRecipeCatalog.parallelLines);
    expect(parallel.shapes, hasLength(2));
    expect(
      parallel.marks.where((mark) => mark.type == GeometryMarkType.parallelLine),
      hasLength(2),
    );

    final angle = factory.build(GeometryRecipeCatalog.angle);
    expect(angle.shapes, hasLength(2));
    expect(angle.marks.single.type, GeometryMarkType.angleArc);
  });

  test('recipe ids are unique', () {
    final ids = GeometryRecipeCatalog.all.map((recipe) => recipe.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
