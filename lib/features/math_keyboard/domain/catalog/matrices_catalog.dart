import '../models/math_symbol.dart';

const List<MathSymbol> matricesMathSymbols = <MathSymbol>[
  MathSymbol(
      id: 'math.8b302ecf9580',
      kind: MathEntryKind.structure,
      priority: 100,
      label: '[2×2]',
      tex: r'\begin{pmatrix}  & \\  & \end{pmatrix}',
      category: MathCategory.matrices,
      isBuilder: true,
    ),
  MathSymbol(
      id: 'math.c0a3f5279ecf',
      kind: MathEntryKind.structure,
      priority: 100,
      label: '[3×3]',
      tex: r'\begin{pmatrix}  &  & \\  &  & \\  &  & \end{pmatrix}',
      category: MathCategory.matrices,
      isBuilder: true,
    ),
  MathSymbol(
      id: 'math.fa6deb9c0956',
      kind: MathEntryKind.structure,
      priority: 100,
      label: '|A|',
      tex: r'\begin{vmatrix}  & \\  & \end{vmatrix}',
      category: MathCategory.matrices,
      isBuilder: true,
    ),
  MathSymbol(id: 'math.b0f3b15177af', priority: 100, label: 'det', tex: r'\det', category: MathCategory.matrices),
];
