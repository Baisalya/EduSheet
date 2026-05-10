enum MathCategory {
  basic,
  functions,
  trig,
  calculus,
  geometry,
  matrices,
  greek,
  operators,
  brackets,
  arrows,
  sets,
  templates,
  misc,
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
  // --- BASIC CATEGORY (High Density) ---
  MathSymbol(label: '0', tex: '0', category: MathCategory.basic),
  MathSymbol(label: '1', tex: '1', category: MathCategory.basic),
  MathSymbol(label: '2', tex: '2', category: MathCategory.basic),
  MathSymbol(label: '3', tex: '3', category: MathCategory.basic),
  MathSymbol(label: '4', tex: '4', category: MathCategory.basic),
  MathSymbol(label: '5', tex: '5', category: MathCategory.basic),
  MathSymbol(label: '6', tex: '6', category: MathCategory.basic),
  MathSymbol(label: '7', tex: '7', category: MathCategory.basic),
  MathSymbol(label: '8', tex: '8', category: MathCategory.basic),
  MathSymbol(label: '9', tex: '9', category: MathCategory.basic),
  MathSymbol(label: '+', tex: '+', category: MathCategory.basic),
  MathSymbol(label: '-', tex: '-', category: MathCategory.basic),
  MathSymbol(label: '×', tex: r'\times', category: MathCategory.basic),
  MathSymbol(label: '÷', tex: r'\div', category: MathCategory.basic),
  MathSymbol(label: '=', tex: '=', category: MathCategory.basic),
  MathSymbol(label: '.', tex: '.', category: MathCategory.basic),
  MathSymbol(label: ',', tex: ',', category: MathCategory.basic),
  MathSymbol(label: '(', tex: '(', category: MathCategory.basic),
  MathSymbol(label: ')', tex: ')', category: MathCategory.basic),
  MathSymbol(label: 'π', tex: r'\pi', category: MathCategory.basic),
  MathSymbol(label: 'e', tex: 'e', category: MathCategory.basic),
  MathSymbol(label: 'i', tex: 'i', category: MathCategory.basic),
  MathSymbol(label: 'x', tex: 'x', category: MathCategory.basic),
  MathSymbol(label: 'y', tex: 'y', category: MathCategory.basic),
  MathSymbol(label: 'z', tex: 'z', category: MathCategory.basic),
  MathSymbol(label: 'n', tex: 'n', category: MathCategory.basic),
  MathSymbol(label: '²', tex: r'^{2}', category: MathCategory.basic),
  MathSymbol(label: '³', tex: r'^{3}', category: MathCategory.basic),
  MathSymbol(label: 'xⁿ', tex: r'^{}', category: MathCategory.basic, isBuilder: true),
  MathSymbol(label: '√', tex: r'\sqrt{}', category: MathCategory.basic, isBuilder: true),
  MathSymbol(label: '∛', tex: r'\sqrt[3]{}', category: MathCategory.basic, isBuilder: true),
  MathSymbol(label: 'Fraction', tex: r'\frac{1}{2}', category: MathCategory.basic, isBuilder: true),
  MathSymbol(label: '%', tex: r'\%', category: MathCategory.basic),
  MathSymbol(label: '!', tex: '!', category: MathCategory.basic),
  MathSymbol(label: 'log', tex: r'\log', category: MathCategory.basic),
  MathSymbol(label: 'ln', tex: r'\ln', category: MathCategory.basic),
  MathSymbol(label: '|x|', tex: r'|{}|', category: MathCategory.basic, isBuilder: true),
  MathSymbol(label: '<', tex: '<', category: MathCategory.basic),
  MathSymbol(label: '>', tex: '>', category: MathCategory.basic),
  MathSymbol(label: '≤', tex: r'\leq', category: MathCategory.basic),
  MathSymbol(label: '≥', tex: r'\geq', category: MathCategory.basic),
  MathSymbol(label: '≠', tex: r'\neq', category: MathCategory.basic),
  MathSymbol(label: '±', tex: r'\pm', category: MathCategory.basic),
  MathSymbol(label: '∞', tex: r'\infty', category: MathCategory.basic),

  // Brackets
  MathSymbol(label: '⟨', tex: r'\langle', category: MathCategory.brackets),
  MathSymbol(label: '⟩', tex: r'\rangle', category: MathCategory.brackets),
  MathSymbol(label: '⟦', tex: r'\llbracket', category: MathCategory.brackets),
  MathSymbol(label: '⟧', tex: r'\rrbracket', category: MathCategory.brackets),
  MathSymbol(label: '⌊', tex: r'\lfloor', category: MathCategory.brackets),
  MathSymbol(label: '⌋', tex: r'\rfloor', category: MathCategory.brackets),
  MathSymbol(label: '⌈', tex: r'\lceil', category: MathCategory.brackets),
  MathSymbol(label: '⌉', tex: r'\rceil', category: MathCategory.brackets),

  // Arrows
  MathSymbol(label: '↑', tex: r'\uparrow', category: MathCategory.arrows),
  MathSymbol(label: '⇐', tex: r'\Leftarrow', category: MathCategory.arrows),
  MathSymbol(label: '←', tex: r'\leftarrow', category: MathCategory.arrows),
  MathSymbol(label: '↔', tex: r'\leftrightarrow', category: MathCategory.arrows),
  MathSymbol(label: '⇒', tex: r'\Rightarrow', category: MathCategory.arrows),
  MathSymbol(label: '→', tex: r'\rightarrow', category: MathCategory.arrows),
  MathSymbol(label: '⇔', tex: r'\Leftrightarrow', category: MathCategory.arrows),

  // Greek Uppercase
  MathSymbol(label: 'Γ', tex: r'\Gamma', category: MathCategory.greek),
  MathSymbol(label: 'Δ', tex: r'\Delta', category: MathCategory.greek),
  MathSymbol(label: 'Λ', tex: r'\Lambda', category: MathCategory.greek),
  MathSymbol(label: 'Ξ', tex: r'\Xi', category: MathCategory.greek),
  MathSymbol(label: 'Π', tex: r'\Pi', category: MathCategory.greek),
  MathSymbol(label: 'Σ', tex: r'\Sigma', category: MathCategory.greek),
  MathSymbol(label: 'Φ', tex: r'\Phi', category: MathCategory.greek),
  MathSymbol(label: 'Ψ', tex: r'\Psi', category: MathCategory.greek),
  MathSymbol(label: 'Ω', tex: r'\Omega', category: MathCategory.greek),

  // Greek Lowercase
  MathSymbol(label: 'α', tex: r'\alpha', category: MathCategory.greek),
  MathSymbol(label: 'β', tex: r'\beta', category: MathCategory.greek),
  MathSymbol(label: 'γ', tex: r'\gamma', category: MathCategory.greek),
  MathSymbol(label: 'δ', tex: r'\delta', category: MathCategory.greek),
  MathSymbol(label: 'ε', tex: r'\epsilon', category: MathCategory.greek),
  MathSymbol(label: 'ζ', tex: r'\zeta', category: MathCategory.greek),
  MathSymbol(label: 'η', tex: r'\eta', category: MathCategory.greek),
  MathSymbol(label: 'θ', tex: r'\theta', category: MathCategory.greek),
  MathSymbol(label: 'κ', tex: r'\kappa', category: MathCategory.greek),
  MathSymbol(label: 'λ', tex: r'\lambda', category: MathCategory.greek),
  MathSymbol(label: 'μ', tex: r'\mu', category: MathCategory.greek),
  MathSymbol(label: 'ν', tex: r'\nu', category: MathCategory.greek),
  MathSymbol(label: 'ξ', tex: r'\xi', category: MathCategory.greek),
  MathSymbol(label: 'π', tex: r'\pi', category: MathCategory.greek),
  MathSymbol(label: 'ρ', tex: r'\rho', category: MathCategory.greek),
  MathSymbol(label: 'σ', tex: r'\sigma', category: MathCategory.greek),
  MathSymbol(label: 'τ', tex: r'\tau', category: MathCategory.greek),
  MathSymbol(label: 'υ', tex: r'\upsilon', category: MathCategory.greek),
  MathSymbol(label: 'φ', tex: r'\phi', category: MathCategory.greek),
  MathSymbol(label: 'χ', tex: r'\chi', category: MathCategory.greek),
  MathSymbol(label: 'ψ', tex: r'\psi', category: MathCategory.greek),
  MathSymbol(label: 'ω', tex: r'\omega', category: MathCategory.greek),

  // Trigonometry
  MathSymbol(label: 'sin', tex: r'\sin', category: MathCategory.trig),
  MathSymbol(label: 'cos', tex: r'\cos', category: MathCategory.trig),
  MathSymbol(label: 'tan', tex: r'\tan', category: MathCategory.trig),
  MathSymbol(label: 'csc', tex: r'\csc', category: MathCategory.trig),
  MathSymbol(label: 'sec', tex: r'\sec', category: MathCategory.trig),
  MathSymbol(label: 'cot', tex: r'\cot', category: MathCategory.trig),
  MathSymbol(label: 'arcsin', tex: r'\arcsin', category: MathCategory.trig),
  MathSymbol(label: 'arccos', tex: r'\arccos', category: MathCategory.trig),
  MathSymbol(label: 'arctan', tex: r'\arctan', category: MathCategory.trig),

  // Calculus
  MathSymbol(label: '∫', tex: r'\int', category: MathCategory.calculus),
  MathSymbol(label: '∬', tex: r'\iint', category: MathCategory.calculus),
  MathSymbol(label: '∭', tex: r'\iiint', category: MathCategory.calculus),
  MathSymbol(label: '∂', tex: r'\partial', category: MathCategory.calculus),
  MathSymbol(label: '∇', tex: r'\nabla', category: MathCategory.calculus),
  MathSymbol(label: 'lim', tex: r'\lim_{x \to \infty}', category: MathCategory.calculus, isBuilder: true),
  MathSymbol(label: 'd/dx', tex: r'\frac{d}{dx}', category: MathCategory.calculus),

  // Matrices
  MathSymbol(label: '[2x2]', tex: r'\begin{pmatrix}  & \\  & \end{pmatrix}', category: MathCategory.matrices, isBuilder: true),
  MathSymbol(label: '[3x3]', tex: r'\begin{pmatrix}  &  & \\  &  & \\  &  & \end{pmatrix}', category: MathCategory.matrices, isBuilder: true),
  MathSymbol(label: 'det', tex: r'\det', category: MathCategory.matrices),

  // Geometry
  MathSymbol(label: '△', tex: r'\triangle', category: MathCategory.geometry),
  MathSymbol(label: '≅', tex: r'\cong', category: MathCategory.geometry),
  MathSymbol(label: '∼', tex: r'\sim', category: MathCategory.geometry),
  MathSymbol(label: '⊥', tex: r'\perp', category: MathCategory.geometry),
  MathSymbol(label: '∥', tex: r'\parallel', category: MathCategory.geometry),
  MathSymbol(label: '∠', tex: r'\angle', category: MathCategory.geometry),

  // Sets
  MathSymbol(label: '∈', tex: r'\in', category: MathCategory.sets),
  MathSymbol(label: '∉', tex: r'\notin', category: MathCategory.sets),
  MathSymbol(label: '⊂', tex: r'\subset', category: MathCategory.sets),
  MathSymbol(label: '⊆', tex: r'\subseteq', category: MathCategory.sets),
  MathSymbol(label: '∪', tex: r'\cup', category: MathCategory.sets),
  MathSymbol(label: '∩', tex: r'\cap', category: MathCategory.sets),
  MathSymbol(label: '∅', tex: r'\empty', category: MathCategory.sets),

  // Templates
  MathSymbol(label: 'Quad', tex: r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}', category: MathCategory.templates),
  MathSymbol(label: 'Pyth', tex: r'a^2 + b^2 = c^2', category: MathCategory.templates),

  // Misc
  MathSymbol(label: 'ℂ', tex: r'\mathbb{C}', category: MathCategory.misc),
  MathSymbol(label: 'ℕ', tex: r'\mathbb{N}', category: MathCategory.misc),
  MathSymbol(label: 'ℝ', tex: r'\mathbb{R}', category: MathCategory.misc),
  MathSymbol(label: 'ℤ', tex: r'\mathbb{Z}', category: MathCategory.misc),
  
  // Explicitly add common powers for quick access if needed, 
  // though Sticky Mode handles them, these can be visual helpers
  MathSymbol(label: 'x²', tex: r'^{2}', category: MathCategory.basic),
  MathSymbol(label: 'x³', tex: r'^{3}', category: MathCategory.basic),
];
