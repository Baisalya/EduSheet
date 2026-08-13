import '../models/math_symbol.dart';

const List<MathSymbol> chemistryMathSymbols = <MathSymbol>[
  MathSymbol(id: 'math.70a0795f45d3', priority: 60, label: '→', tex: r'\rightarrow', category: MathCategory.chemistry),
  MathSymbol(id: 'math.8eb6ac08e4ee', priority: 60, label: '⇌', tex: r'\rightleftharpoons', category: MathCategory.chemistry),
  MathSymbol(id: 'math.36d613cdd74c', priority: 60, label: '↑', tex: r'\uparrow', category: MathCategory.chemistry),
  MathSymbol(id: 'math.f5d0ab2496bb', priority: 60, label: '↓', tex: r'\downarrow', category: MathCategory.chemistry),
  MathSymbol(id: 'math.763bcca756ef', priority: 60, label: 'Δ', tex: r'\Delta', category: MathCategory.chemistry),
  MathSymbol(id: 'math.4744d556ed29', priority: 60, label: 'H₂O', tex: r'\mathrm{H_2O}', category: MathCategory.chemistry),
  MathSymbol(id: 'math.ee870df613b9', priority: 60, label: 'CO₂', tex: r'\mathrm{CO_2}', category: MathCategory.chemistry),
  MathSymbol(id: 'math.8411205eb38d', priority: 60, label: 'O₂', tex: r'\mathrm{O_2}', category: MathCategory.chemistry),
  MathSymbol(id: 'math.20f55d593f78', priority: 60, label: 'H⁺', tex: r'\mathrm{H^+}', category: MathCategory.chemistry),
  MathSymbol(id: 'math.7cd7805b3d17', priority: 60, label: 'OH⁻', tex: r'\mathrm{OH^-}', category: MathCategory.chemistry),
  MathSymbol(id: 'math.07baf0db42bb', priority: 60, label: 'Ca²⁺', tex: r'\mathrm{Ca^{2+}}', category: MathCategory.chemistry),
  MathSymbol(id: 'math.af1ad14485b9', priority: 60, label: 'Cl⁻', tex: r'\mathrm{Cl^-}', category: MathCategory.chemistry),
  MathSymbol(id: 'math.66d8b7bf6fa0', kind: MathEntryKind.structure, priority: 60, label: '⁺ charge', tex: r'^{+}', category: MathCategory.chemistry, isBuilder: true),
  MathSymbol(id: 'math.b90d73adb742', kind: MathEntryKind.structure, priority: 60, label: '⁻ charge', tex: r'^{-}', category: MathCategory.chemistry, isBuilder: true),
  MathSymbol(id: 'math.27ba6876da5e', kind: MathEntryKind.structure, priority: 60, label: 'ⁿ⁺ charge', tex: r'^{n+}', category: MathCategory.chemistry, isBuilder: true),
  MathSymbol(id: 'math.54f672096349', kind: MathEntryKind.structure, aliases: <String>['isotope', 'atomic number', 'mass number', 'nuclear notation'], priority: 60, label: 'isotope', tex: r'{}^{A}_{Z}X', category: MathCategory.chemistry, isBuilder: true),
  MathSymbol(id: 'math.243c5bbf17c5', priority: 60, label: '(s)', tex: r'\mathrm{(s)}', category: MathCategory.chemistry),
  MathSymbol(id: 'math.77d1f86dfa3e', priority: 60, label: '(l)', tex: r'\mathrm{(l)}', category: MathCategory.chemistry),
  MathSymbol(id: 'math.7369317858d6', priority: 60, label: '(g)', tex: r'\mathrm{(g)}', category: MathCategory.chemistry),
  MathSymbol(id: 'math.1eaac015ba35', priority: 60, label: '(aq)', tex: r'\mathrm{(aq)}', category: MathCategory.chemistry),
];
