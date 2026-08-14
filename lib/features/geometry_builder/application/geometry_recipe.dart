import '../models/geometry_shape.dart';

enum GeometryRecipeCategory {
  quick,
  lines,
  triangles,
  quadrilaterals,
  circles,
  coordinate,
  solids,
  polygons,
}

class GeometryRecipe {
  final String id;
  final String label;
  final String description;
  final GeometryRecipeCategory category;
  final GeometryShapeType? baseShape;
  final List<String> searchTerms;

  const GeometryRecipe({
    required this.id,
    required this.label,
    required this.description,
    required this.category,
    this.baseShape,
    this.searchTerms = const [],
  });

  String get searchableText => [
    label,
    description,
    ...searchTerms,
  ].join(' ').toLowerCase();
}

class GeometryRecipeCatalog {
  const GeometryRecipeCatalog._();

  static const triangle = GeometryRecipe(
    id: 'triangle',
    label: 'Triangle',
    description: 'A clean triangle with A, B and C',
    category: GeometryRecipeCategory.triangles,
    baseShape: GeometryShapeType.triangle,
    searchTerms: ['3 sides', 'abc'],
  );

  static const rightTriangle = GeometryRecipe(
    id: 'right_triangle',
    label: 'Right triangle',
    description: 'Triangle with a real 90° corner mark',
    category: GeometryRecipeCategory.triangles,
    baseShape: GeometryShapeType.rightTriangle,
    searchTerms: ['90 degree', 'right angle', 'perpendicular'],
  );

  static const isoscelesTriangle = GeometryRecipe(
    id: 'isosceles_triangle',
    label: 'Isosceles triangle',
    description: 'Two equal sides already marked',
    category: GeometryRecipeCategory.triangles,
    searchTerms: ['equal sides', 'two equal'],
  );

  static const equilateralTriangle = GeometryRecipe(
    id: 'equilateral_triangle',
    label: 'Equilateral triangle',
    description: 'All three sides marked equal',
    category: GeometryRecipeCategory.triangles,
    searchTerms: ['all equal', '60 degree'],
  );

  static const angle = GeometryRecipe(
    id: 'angle',
    label: 'Angle',
    description: 'Two rays with an angle arc',
    category: GeometryRecipeCategory.lines,
    searchTerms: ['angle arc', 'vertex'],
  );

  static const parallelLines = GeometryRecipe(
    id: 'parallel_lines',
    label: 'Parallel lines',
    description: 'Two lines with matching parallel marks',
    category: GeometryRecipeCategory.lines,
    searchTerms: ['parallel', 'matching arrows'],
  );

  static const circleRadius = GeometryRecipe(
    id: 'circle_radius',
    label: 'Circle + radius',
    description: 'Circle with centre and radius line',
    category: GeometryRecipeCategory.circles,
    baseShape: GeometryShapeType.circle,
    searchTerms: ['radius', 'centre', 'center'],
  );

  static const circleDiameter = GeometryRecipe(
    id: 'circle_diameter',
    label: 'Circle + diameter',
    description: 'Circle with centre and full diameter',
    category: GeometryRecipeCategory.circles,
    baseShape: GeometryShapeType.circle,
    searchTerms: ['diameter', 'centre', 'center'],
  );

  static const circleChord = GeometryRecipe(
    id: 'circle_chord',
    label: 'Circle + chord',
    description: 'Circle with a chord ready to label',
    category: GeometryRecipeCategory.circles,
    baseShape: GeometryShapeType.circle,
    searchTerms: ['chord'],
  );

  static const circleTangent = GeometryRecipe(
    id: 'circle_tangent',
    label: 'Circle + tangent',
    description: 'Circle with a tangent line at one point',
    category: GeometryRecipeCategory.circles,
    baseShape: GeometryShapeType.circle,
    searchTerms: ['tangent'],
  );

  static const coordinateAxes = GeometryRecipe(
    id: 'coordinate_axes',
    label: 'Coordinate axes',
    description: 'X and Y axes ready for points',
    category: GeometryRecipeCategory.coordinate,
    baseShape: GeometryShapeType.coordinateAxes,
    searchTerms: ['graph', 'x axis', 'y axis', 'cartesian'],
  );

  static const numberLine = GeometryRecipe(
    id: 'number_line',
    label: 'Number line',
    description: 'A clean number-line base',
    category: GeometryRecipeCategory.coordinate,
    baseShape: GeometryShapeType.numberLine,
    searchTerms: ['number line', 'integers'],
  );

  static const quick = <GeometryRecipe>[
    rightTriangle,
    circleRadius,
    coordinateAxes,
    GeometryRecipe(
      id: 'rectangle',
      label: 'Rectangle',
      description: 'Clean rectangle with A, B, C and D',
      category: GeometryRecipeCategory.quadrilaterals,
      baseShape: GeometryShapeType.rectangle,
      searchTerms: ['length breadth', 'quadrilateral'],
    ),
    GeometryRecipe(
      id: 'line',
      label: 'Line',
      description: 'Straight line segment',
      category: GeometryRecipeCategory.lines,
      baseShape: GeometryShapeType.line,
      searchTerms: ['segment'],
    ),
    GeometryRecipe(
      id: 'cube',
      label: 'Cube',
      description: '3D cube diagram',
      category: GeometryRecipeCategory.solids,
      baseShape: GeometryShapeType.cube,
      searchTerms: ['3d solid'],
    ),
  ];

  static List<GeometryRecipe> get all => <GeometryRecipe>[
    ...quick,
    triangle,
    isoscelesTriangle,
    equilateralTriangle,
    angle,
    parallelLines,
    circleDiameter,
    circleChord,
    circleTangent,
    numberLine,
    ..._baseShapeRecipes,
  ];

  static List<GeometryRecipe> get _baseShapeRecipes => <GeometryRecipe>[
    for (final type in GeometryShapeType.values)
      if (!_coveredBaseShape(type))
        GeometryRecipe(
          id: 'shape_${type.name}',
          label: _labelForType(type),
          description: _descriptionForType(type),
          category: _categoryForType(type),
          baseShape: type,
          searchTerms: [type.name],
        ),
  ];

  static List<GeometryRecipe> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return all;
    return all
        .where((recipe) => recipe.searchableText.contains(normalized))
        .toList();
  }

  static List<GeometryRecipe> inCategory(GeometryRecipeCategory category) {
    if (category == GeometryRecipeCategory.quick) return quick;
    return all.where((recipe) => recipe.category == category).toList();
  }

  static bool _coveredBaseShape(GeometryShapeType type) {
    return const {
      GeometryShapeType.line,
      GeometryShapeType.triangle,
      GeometryShapeType.rightTriangle,
      GeometryShapeType.rectangle,
      GeometryShapeType.coordinateAxes,
      GeometryShapeType.numberLine,
      GeometryShapeType.cube,
    }.contains(type);
  }

  static GeometryRecipeCategory _categoryForType(GeometryShapeType type) {
    switch (type) {
      case GeometryShapeType.line:
      case GeometryShapeType.arrow:
        return GeometryRecipeCategory.lines;
      case GeometryShapeType.triangle:
      case GeometryShapeType.rightTriangle:
        return GeometryRecipeCategory.triangles;
      case GeometryShapeType.square:
      case GeometryShapeType.rectangle:
      case GeometryShapeType.parallelogram:
      case GeometryShapeType.trapezium:
      case GeometryShapeType.rhombus:
        return GeometryRecipeCategory.quadrilaterals;
      case GeometryShapeType.circle:
      case GeometryShapeType.semicircle:
        return GeometryRecipeCategory.circles;
      case GeometryShapeType.coordinateAxes:
      case GeometryShapeType.numberLine:
        return GeometryRecipeCategory.coordinate;
      case GeometryShapeType.cube:
      case GeometryShapeType.cuboid:
      case GeometryShapeType.cylinder:
      case GeometryShapeType.cone:
      case GeometryShapeType.sphere:
        return GeometryRecipeCategory.solids;
      case GeometryShapeType.pentagon:
      case GeometryShapeType.hexagon:
      case GeometryShapeType.polygon:
        return GeometryRecipeCategory.polygons;
    }
  }

  static String _labelForType(GeometryShapeType type) {
    final words = type.name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  static String _descriptionForType(GeometryShapeType type) {
    switch (type) {
      case GeometryShapeType.arrow:
        return 'Directed line / vector';
      case GeometryShapeType.square:
        return 'Four equal sides';
      case GeometryShapeType.parallelogram:
        return 'Opposite sides parallel';
      case GeometryShapeType.trapezium:
        return 'One pair of parallel sides';
      case GeometryShapeType.rhombus:
        return 'Diamond-shaped quadrilateral';
      case GeometryShapeType.pentagon:
        return 'Five-sided polygon';
      case GeometryShapeType.hexagon:
        return 'Six-sided polygon';
      case GeometryShapeType.polygon:
        return 'Editable polygon';
      case GeometryShapeType.semicircle:
        return 'Half-circle figure';
      case GeometryShapeType.cuboid:
        return 'Rectangular 3D solid';
      case GeometryShapeType.cylinder:
        return 'Cylindrical solid';
      case GeometryShapeType.cone:
        return 'Conical solid';
      case GeometryShapeType.sphere:
        return 'Spherical solid';
      default:
        return 'Ready-to-edit ${_labelForType(type).toLowerCase()}';
    }
  }
}
