enum MathCategory {
  basic,
  trig,
  calculus,
  geometry,
  matrices,
  greek,
  operators,
}

class MathSymbol {
  final String label;
  final String tex;
  final MathCategory category;
  final bool isBuilder;
  final List<String>? variations;

  const MathSymbol({
    required this.label,
    required this.tex,
    required this.category,
    this.isBuilder = false,
    this.variations,
  });
}

const List<MathSymbol> mathSymbols = [
  // Basic
  MathSymbol(label: 'Fraction', tex: r'\frac{}{}', category: MathCategory.basic, isBuilder: true),
  MathSymbol(label: 'Square Root', tex: r'\sqrt{}', category: MathCategory.basic, isBuilder: true),
  MathSymbol(label: 'Power', tex: r'^{}', category: MathCategory.basic, isBuilder: true),
  MathSymbol(label: 'Square', tex: r'^{2}', category: MathCategory.basic),
  MathSymbol(label: 'Cube', tex: r'^{3}', category: MathCategory.basic),
  MathSymbol(label: 'Subscript', tex: r'_{}', category: MathCategory.basic, isBuilder: true),

  // Trig
  MathSymbol(label: 'sin', tex: r'\sin(', category: MathCategory.trig, variations: [r'\arcsin(', r'\sinh(']),
  MathSymbol(label: 'cos', tex: r'\cos(', category: MathCategory.trig, variations: [r'\arccos(', r'\cosh(']),
  MathSymbol(label: 'tan', tex: r'\tan(', category: MathCategory.trig, variations: [r'\arctan(', r'\tanh(']),
  MathSymbol(label: 'sec', tex: r'\sec(', category: MathCategory.trig),
  MathSymbol(label: 'csc', tex: r'\csc(', category: MathCategory.trig),
  MathSymbol(label: 'cot', tex: r'\cot(', category: MathCategory.trig),

  // Calculus
  MathSymbol(label: 'Integral', tex: r'\int', category: MathCategory.calculus),
  MathSymbol(label: 'Definite Integral', tex: r'\int_{}^{}', category: MathCategory.calculus, isBuilder: true),
  MathSymbol(label: 'Summation', tex: r'\sum_{}^{}', category: MathCategory.calculus, isBuilder: true),
  MathSymbol(label: 'Product', tex: r'\prod_{}^{}', category: MathCategory.calculus, isBuilder: true),
  MathSymbol(label: 'Derivative', tex: r'\frac{d}{dx}', category: MathCategory.calculus),
  MathSymbol(label: 'Partial', tex: r'\partial', category: MathCategory.calculus),
  MathSymbol(label: 'Limit', tex: r'\lim_{x \to \infty}', category: MathCategory.calculus),

  // Geometry
  MathSymbol(label: 'Angle', tex: r'\angle', category: MathCategory.geometry),
  MathSymbol(label: 'Perpendicular', tex: r'\perp', category: MathCategory.geometry),
  MathSymbol(label: 'Parallel', tex: r'\parallel', category: MathCategory.geometry),
  MathSymbol(label: 'Congruent', tex: r'\cong', category: MathCategory.geometry),
  MathSymbol(label: 'Similar', tex: r'\sim', category: MathCategory.geometry),
  MathSymbol(label: 'Degree', tex: r'^{\circ}', category: MathCategory.geometry),
  MathSymbol(label: 'Pi', tex: r'\pi', category: MathCategory.geometry),
  MathSymbol(label: 'Triangle', tex: r'\triangle', category: MathCategory.geometry),

  // Greek
  MathSymbol(label: 'alpha', tex: r'\alpha', category: MathCategory.greek),
  MathSymbol(label: 'beta', tex: r'\beta', category: MathCategory.greek),
  MathSymbol(label: 'gamma', tex: r'\gamma', category: MathCategory.greek),
  MathSymbol(label: 'delta', tex: r'\delta', category: MathCategory.greek, variations: [r'\Delta']),
  MathSymbol(label: 'theta', tex: r'\theta', category: MathCategory.greek),
  MathSymbol(label: 'lambda', tex: r'\lambda', category: MathCategory.greek),
  MathSymbol(label: 'mu', tex: r'\mu', category: MathCategory.greek),
  MathSymbol(label: 'sigma', tex: r'\sigma', category: MathCategory.greek, variations: [r'\Sigma']),
  MathSymbol(label: 'omega', tex: r'\omega', category: MathCategory.greek, variations: [r'\Omega']),
  MathSymbol(label: 'phi', tex: r'\phi', category: MathCategory.greek, variations: [r'\Phi']),

  // Operators
  MathSymbol(label: 'Plus-Minus', tex: r'\pm', category: MathCategory.operators),
  MathSymbol(label: 'Multiply', tex: r'\times', category: MathCategory.operators),
  MathSymbol(label: 'Divide', tex: r'\div', category: MathCategory.operators),
  MathSymbol(label: 'Infinity', tex: r'\infty', category: MathCategory.operators),
  MathSymbol(label: 'Exists', tex: r'\exists', category: MathCategory.operators),
  MathSymbol(label: 'For All', tex: r'\forall', category: MathCategory.operators),
  MathSymbol(label: 'Intersection', tex: r'\cap', category: MathCategory.operators),
  MathSymbol(label: 'Union', tex: r'\cup', category: MathCategory.operators),

  // Matrices
  MathSymbol(label: '2x2 Matrix', tex: r'\begin{pmatrix} & \\ & \end{pmatrix}', category: MathCategory.matrices, isBuilder: true),
  MathSymbol(label: '3x3 Matrix', tex: r'\begin{pmatrix} & & \\ & & \\ & & \end{pmatrix}', category: MathCategory.matrices, isBuilder: true),
];

