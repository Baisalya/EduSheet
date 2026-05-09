enum MathCategory {
  basic,
  trig,
  calculus,
  geometry,
  matrices,
}

class MathSymbol {
  final String label;
  final String tex;
  final MathCategory category;
  final bool isBuilder;

  const MathSymbol({
    required this.label,
    required this.tex,
    required this.category,
    this.isBuilder = false,
  });
}

const List<MathSymbol> mathSymbols = [
  // Basic
  MathSymbol(label: 'Fraction', tex: r'\frac{}{}', category: MathCategory.basic, isBuilder: true),
  MathSymbol(label: 'Square Root', tex: r'\sqrt{}', category: MathCategory.basic, isBuilder: true),
  MathSymbol(label: 'Power', tex: r'^{}', category: MathCategory.basic, isBuilder: true),
  MathSymbol(label: 'Square', tex: r'^{2}', category: MathCategory.basic),
  MathSymbol(label: 'Cube', tex: r'^{3}', category: MathCategory.basic),
  
  // Trig
  MathSymbol(label: 'sin', tex: r'\sin(', category: MathCategory.trig),
  MathSymbol(label: 'cos', tex: r'\cos(', category: MathCategory.trig),
  MathSymbol(label: 'tan', tex: r'\tan(', category: MathCategory.trig),
  MathSymbol(label: 'arcsin', tex: r'\arcsin(', category: MathCategory.trig),
  MathSymbol(label: 'arccos', tex: r'\arccos(', category: MathCategory.trig),
  MathSymbol(label: 'arctan', tex: r'\arctan(', category: MathCategory.trig),

  // Calculus
  MathSymbol(label: 'Integral', tex: r'\int', category: MathCategory.calculus),
  MathSymbol(label: 'Definite Integral', tex: r'\int_{}^{}', category: MathCategory.calculus, isBuilder: true),
  MathSymbol(label: 'Summation', tex: r'\sum_{}^{}', category: MathCategory.calculus, isBuilder: true),
  MathSymbol(label: 'Derivative', tex: r'\frac{d}{dx}', category: MathCategory.calculus),
  MathSymbol(label: 'Limit', tex: r'\lim_{x \to \infty}', category: MathCategory.calculus),

  // Geometry
  MathSymbol(label: 'Angle', tex: r'\angle', category: MathCategory.geometry),
  MathSymbol(label: 'Perpendicular', tex: r'\perp', category: MathCategory.geometry),
  MathSymbol(label: 'Congruent', tex: r'\cong', category: MathCategory.geometry),
  MathSymbol(label: 'Degree', tex: r'^{\circ}', category: MathCategory.geometry),
  MathSymbol(label: 'Pi', tex: r'\pi', category: MathCategory.geometry),

  // Matrices
  MathSymbol(label: '2x2 Matrix', tex: r'\begin{pmatrix} & \\ & \end{pmatrix}', category: MathCategory.matrices, isBuilder: true),
];
