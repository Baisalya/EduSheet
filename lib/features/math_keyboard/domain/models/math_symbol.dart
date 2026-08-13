enum MathCategory {
  recent,
  favorites,
  basic,
  functions,
  trig,
  calculus,
  geometry,
  physics,
  chemistry,
  statistics,
  matrices,
  greek,
  operators,
  brackets,
  arrows,
  sets,
  templates,
  format,
  misc,
}

/// Semantic type of an entry, independent from where the UI chooses to show it.
enum MathEntryKind {
  symbol,
  operator,
  relation,
  function,
  structure,
  formulaTemplate,
  unit,
  constant,
  text,
}

/// Broad subject metadata used by search, ranking, and future smart palettes.
enum MathSubject {
  general,
  arithmetic,
  algebra,
  trigonometry,
  calculus,
  geometry,
  probability,
  statistics,
  linearAlgebra,
  sets,
  logic,
  physics,
  chemistry,
}

/// Coarse education levels. These are deliberately curriculum-neutral.
enum MathEducationLevel {
  primary,
  middle,
  secondary,
  higherSecondary,
  university,
  advanced,
}

/// Editing behavior is domain metadata, not presentation-layer TeX matching.
enum MathInputBehavior { insert, powerMode, subscriptMode }

class MathSymbol {
  /// Stable semantic identity.
  ///
  /// Entries with the same TeX meaning intentionally share an id even when
  /// they are surfaced in multiple categories.
  final String id;
  final String label;
  final String tex;
  final MathCategory category;
  final MathEntryKind kind;
  final MathInputBehavior inputBehavior;

  /// Optional source inserted before activating a modal input behavior.
  /// Examples: `e` for eˣ, `\sum` for a summation-index builder.
  final String? modeBaseSource;

  /// Preserved for compatibility with the current insertion layer.
  /// New domain/UI code should prefer [isStructural].
  final bool isBuilder;

  /// TeX alternatives exposed by the current long-press UI.
  final List<String>? variations;

  /// Plain-language terms a teacher may use to find this entry.
  final List<String> aliases;

  /// Optional explicit accessibility wording.
  final String? spokenLabel;

  /// Lower numbers rank earlier in broad search results.
  final int priority;

  /// Empty lists intentionally fall back to category metadata.
  final List<MathSubject> subjects;
  final List<MathEducationLevel> levels;

  const MathSymbol({
    required this.id,
    required this.label,
    required this.tex,
    required this.category,
    this.kind = MathEntryKind.symbol,
    this.inputBehavior = MathInputBehavior.insert,
    this.modeBaseSource,
    this.isBuilder = false,
    this.variations,
    this.aliases = const <String>[],
    this.spokenLabel,
    this.priority = 100,
    this.subjects = const <MathSubject>[],
    this.levels = const <MathEducationLevel>[],
  });

  bool get isStructural =>
      isBuilder ||
      kind == MathEntryKind.structure ||
      kind == MathEntryKind.formulaTemplate;

  String get accessibilityLabel =>
      spokenLabel ?? _spokenMathLabels[tex] ?? label;

  List<String> get effectiveAliases => <String>[
    ...aliases,
    ...?_mathSearchAliases[tex],
  ];

  String get searchableText => <String>[
    label,
    accessibilityLabel,
    ...effectiveAliases,
    category.name,
    kind.name,
    ...effectiveSubjects.map((subject) => subject.name),
    tex,
  ].join(' ').toLowerCase();

  List<MathSubject> get effectiveSubjects =>
      subjects.isNotEmpty ? subjects : category.defaultSubjects;

  List<MathEducationLevel> get effectiveLevels =>
      levels.isNotEmpty ? levels : category.defaultLevels;

  MathSymbol copyWith({
    String? id,
    String? label,
    String? tex,
    MathCategory? category,
    MathEntryKind? kind,
    MathInputBehavior? inputBehavior,
    String? modeBaseSource,
    bool clearModeBaseSource = false,
    bool? isBuilder,
    List<String>? variations,
    List<String>? aliases,
    String? spokenLabel,
    int? priority,
    List<MathSubject>? subjects,
    List<MathEducationLevel>? levels,
  }) {
    return MathSymbol(
      id: id ?? this.id,
      label: label ?? this.label,
      tex: tex ?? this.tex,
      category: category ?? this.category,
      kind: kind ?? this.kind,
      inputBehavior: inputBehavior ?? this.inputBehavior,
      modeBaseSource: clearModeBaseSource
          ? null
          : (modeBaseSource ?? this.modeBaseSource),
      isBuilder: isBuilder ?? this.isBuilder,
      variations: variations ?? this.variations,
      aliases: aliases ?? this.aliases,
      spokenLabel: spokenLabel ?? this.spokenLabel,
      priority: priority ?? this.priority,
      subjects: subjects ?? this.subjects,
      levels: levels ?? this.levels,
    );
  }
}

extension MathCategoryMetadata on MathCategory {
  List<MathSubject> get defaultSubjects {
    switch (this) {
      case MathCategory.basic:
        return const <MathSubject>[
          MathSubject.general,
          MathSubject.arithmetic,
        ];
      case MathCategory.functions:
        return const <MathSubject>[MathSubject.algebra];
      case MathCategory.trig:
        return const <MathSubject>[MathSubject.trigonometry];
      case MathCategory.calculus:
        return const <MathSubject>[MathSubject.calculus];
      case MathCategory.geometry:
        return const <MathSubject>[MathSubject.geometry];
      case MathCategory.physics:
        return const <MathSubject>[MathSubject.physics];
      case MathCategory.chemistry:
        return const <MathSubject>[MathSubject.chemistry];
      case MathCategory.statistics:
        return const <MathSubject>[
          MathSubject.statistics,
          MathSubject.probability,
        ];
      case MathCategory.matrices:
        return const <MathSubject>[MathSubject.linearAlgebra];
      case MathCategory.sets:
        return const <MathSubject>[MathSubject.sets, MathSubject.logic];
      case MathCategory.operators:
        return const <MathSubject>[MathSubject.general, MathSubject.logic];
      case MathCategory.recent:
      case MathCategory.favorites:
      case MathCategory.greek:
      case MathCategory.brackets:
      case MathCategory.arrows:
      case MathCategory.templates:
      case MathCategory.format:
      case MathCategory.misc:
        return const <MathSubject>[MathSubject.general];
    }
  }

  List<MathEducationLevel> get defaultLevels {
    switch (this) {
      case MathCategory.basic:
        return const <MathEducationLevel>[
          MathEducationLevel.primary,
          MathEducationLevel.middle,
          MathEducationLevel.secondary,
        ];
      case MathCategory.functions:
      case MathCategory.geometry:
      case MathCategory.statistics:
        return const <MathEducationLevel>[
          MathEducationLevel.middle,
          MathEducationLevel.secondary,
          MathEducationLevel.higherSecondary,
        ];
      case MathCategory.trig:
      case MathCategory.calculus:
      case MathCategory.matrices:
        return const <MathEducationLevel>[
          MathEducationLevel.secondary,
          MathEducationLevel.higherSecondary,
          MathEducationLevel.university,
        ];
      case MathCategory.recent:
      case MathCategory.favorites:
      case MathCategory.physics:
      case MathCategory.chemistry:
      case MathCategory.greek:
      case MathCategory.operators:
      case MathCategory.brackets:
      case MathCategory.arrows:
      case MathCategory.sets:
      case MathCategory.templates:
      case MathCategory.format:
      case MathCategory.misc:
        return const <MathEducationLevel>[
          MathEducationLevel.middle,
          MathEducationLevel.secondary,
          MathEducationLevel.higherSecondary,
          MathEducationLevel.university,
        ];
    }
  }
}

const Map<String, String> _spokenMathLabels = <String, String>{
  r'\frac{}{}': 'fraction with numerator and denominator',
  r'\sqrt{}': 'square root',
  r'\sqrt[3]{}': 'cube root',
  r'\sqrt[]{}': 'nth root',
  r'\int': 'integral',
  r'\iint': 'double integral',
  r'\iiint': 'triple integral',
  r'\sum': 'summation',
  r'\prod': 'product notation',
  r'\infty': 'infinity',
  r'\leq': 'less than or equal to',
  r'\geq': 'greater than or equal to',
  r'\neq': 'not equal to',
  r'\approx': 'approximately equal to',
  r'\therefore': 'therefore',
  r'\because': 'because',
  r'\in': 'is an element of',
  r'\notin': 'is not an element of',
  r'\cup': 'union',
  r'\cap': 'intersection',
  r'\rightarrow': 'right arrow',
  r'\rightleftharpoons': 'equilibrium reaction arrow',
};

const Map<String, List<String>> _mathSearchAliases =
    <String, List<String>>{
      r'\frac{}{}': <String>[
        'fraction',
        'divide',
        'numerator',
        'denominator',
        'over',
      ],
      r'\sqrt{}': <String>['square root', 'root', 'radical'],
      r'\sqrt[3]{}': <String>['cube root', 'third root'],
      r'\sqrt[]{}': <String>['nth root', 'index root'],
      r'^{}': <String>['power', 'exponent', 'superscript'],
      r'_{}': <String>['subscript', 'index'],
      r'\int': <String>['integral', 'integration'],
      r'\iint': <String>['double integral'],
      r'\iiint': <String>['triple integral'],
      r'\oint': <String>['contour integral', 'closed integral'],
      r'\sum': <String>['sum', 'summation', 'sigma'],
      r'\prod': <String>['product', 'product notation'],
      r'\partial': <String>['partial derivative', 'partial'],
      r'\nabla': <String>['nabla', 'del', 'gradient'],
      r'\infty': <String>['infinity', 'infinite'],
      r'\leq': <String>['less than or equal', 'at most'],
      r'\geq': <String>['greater than or equal', 'at least'],
      r'\neq': <String>['not equal', 'unequal'],
      r'\approx': <String>[
        'approximately',
        'approximately equal',
        'roughly equal',
      ],
      r'\equiv': <String>['equivalent', 'identical'],
      r'\pm': <String>['plus minus', 'plus or minus'],
      r'\propto': <String>['proportional', 'proportional to'],
      r'\in': <String>['element of', 'belongs to'],
      r'\notin': <String>['not element of', 'does not belong'],
      r'\subset': <String>['subset'],
      r'\subseteq': <String>['subset or equal'],
      r'\cup': <String>['union'],
      r'\cap': <String>['intersection'],
      r'\varnothing': <String>['empty set', 'null set'],
      r'\angle': <String>['angle'],
      r'\perp': <String>['perpendicular', 'normal'],
      r'\parallel': <String>['parallel'],
      r'\cong': <String>['congruent'],
      r'\rightarrow': <String>['right arrow', 'reaction arrow', 'tends to'],
      r'\rightleftharpoons': <String>[
        'equilibrium',
        'reversible reaction',
        'equilibrium arrow',
      ],
      r'\bar{x}': <String>['mean', 'average', 'x bar'],
      r'\sigma': <String>['sigma', 'standard deviation'],
      r'\mu': <String>['mu', 'mean', 'coefficient of friction'],
      r'\lambda': <String>['lambda', 'wavelength'],
      r'\omega': <String>['omega', 'angular frequency'],
      r'\rho': <String>['rho', 'density'],
      r'\Delta': <String>['delta', 'change', 'difference'],
      r'\begin{pmatrix}  & \\  & \end{pmatrix}': <String>[
        '2x2 matrix',
        'matrix two by two',
      ],
      r'\begin{pmatrix}  &  & \\  &  & \\  &  & \end{pmatrix}':
          <String>['3x3 matrix', 'matrix three by three'],
      r'\begin{vmatrix}  & \\  & \end{vmatrix}': <String>[
        'determinant',
        '2x2 determinant',
      ],
      r'f(x)=\begin{cases} & \\ & \end{cases}': <String>[
        'piecewise',
        'cases',
        'piecewise function',
      ],
      r'{}^{A}_{Z}X': <String>[
        'isotope',
        'atomic number',
        'mass number',
        'nuclear notation',
      ],
      r'{}\times 10^{}': <String>[
        'scientific notation',
        'standard form',
        'times ten power',
      ],
    };
