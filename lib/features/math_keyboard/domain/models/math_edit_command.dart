import 'math_composer_spec.dart';
import 'math_dynamic_structure.dart';

/// Declarative editing instructions for the visual math-field adapter.
///
/// These commands deliberately contain no Flutter or `math_keyboard` package
/// types. Domain catalogue entries can therefore describe how they should be
/// constructed without presentation code matching raw TeX strings.
enum MathEditArgument { braces, brackets }

enum MathSlotMoveDirection { previous, next }

sealed class MathEditOperation {
  const MathEditOperation();
}

class MathInsertLeaf extends MathEditOperation {
  final String source;

  const MathInsertLeaf(this.source);
}

class MathInsertFunction extends MathEditOperation {
  final String function;
  final List<MathEditArgument> arguments;

  const MathInsertFunction(this.function, this.arguments);
}

class MathMoveSlot extends MathEditOperation {
  final MathSlotMoveDirection direction;
  final int count;

  const MathMoveSlot(this.direction, {this.count = 1}) : assert(count > 0);
}

/// Inserts a runtime-sized mathematical structure through the adapter's
/// dynamic slot engine. The spec is domain-only; presentation code decides how
/// to materialize its editable boxes.
class MathInsertDynamicStructure extends MathEditOperation {
  final MathDynamicStructureSpec spec;

  const MathInsertDynamicStructure(this.spec);
}

/// A complete, deterministic visual-editor insertion recipe.
class MathEditCommand {
  final List<MathEditOperation> operations;

  /// Optional semantic slot model for structures that participate in the
  /// universal composer. The imperative operations remain the adapter-facing
  /// execution plan; this metadata tells the rest of EduSheet what those
  /// editable positions mean without re-parsing TeX.
  final MathComposerSpec? composer;

  const MathEditCommand(this.operations, {this.composer});

  bool get isEmpty => operations.isEmpty;
  bool get isStructured => composer != null;
}

/// Shared command recipes used by catalogue entries.
///
/// Keeping recipes here prevents duplicated imperative cursor choreography in
/// UI adapters while still making each catalogue entry explicitly opt into the
/// behavior it needs.
abstract final class MathEditCommands {
  static const MathEditCommand fraction = MathEditCommand(<MathEditOperation>[
    MathInsertFunction(r'\frac', <MathEditArgument>[
      MathEditArgument.braces,
      MathEditArgument.braces,
    ]),
  ], composer: MathComposerSpecs.fraction);

  static const MathEditCommand half = MathEditCommand(<MathEditOperation>[
    MathInsertFunction(r'\frac', <MathEditArgument>[
      MathEditArgument.braces,
      MathEditArgument.braces,
    ]),
    MathInsertLeaf('1'),
    MathMoveSlot(MathSlotMoveDirection.next),
    MathInsertLeaf('2'),
    MathMoveSlot(MathSlotMoveDirection.next),
  ]);

  static const MathEditCommand oneThird = MathEditCommand(<MathEditOperation>[
    MathInsertFunction(r'\frac', <MathEditArgument>[
      MathEditArgument.braces,
      MathEditArgument.braces,
    ]),
    MathInsertLeaf('1'),
    MathMoveSlot(MathSlotMoveDirection.next),
    MathInsertLeaf('3'),
    MathMoveSlot(MathSlotMoveDirection.next),
  ]);

  static const MathEditCommand twoThirds = MathEditCommand(<MathEditOperation>[
    MathInsertFunction(r'\frac', <MathEditArgument>[
      MathEditArgument.braces,
      MathEditArgument.braces,
    ]),
    MathInsertLeaf('2'),
    MathMoveSlot(MathSlotMoveDirection.next),
    MathInsertLeaf('3'),
    MathMoveSlot(MathSlotMoveDirection.next),
  ]);

  static const MathEditCommand derivativeDByDx = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction(r'\frac', <MathEditArgument>[
        MathEditArgument.braces,
        MathEditArgument.braces,
      ]),
      MathInsertLeaf('d'),
      MathMoveSlot(MathSlotMoveDirection.next),
      MathInsertLeaf('d'),
      MathInsertLeaf('x'),
      MathMoveSlot(MathSlotMoveDirection.next),
    ],
  );

  static const MathEditCommand derivativeDyByDx = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction(r'\frac', <MathEditArgument>[
        MathEditArgument.braces,
        MathEditArgument.braces,
      ]),
      MathInsertLeaf('d'),
      MathInsertLeaf('y'),
      MathMoveSlot(MathSlotMoveDirection.next),
      MathInsertLeaf('d'),
      MathInsertLeaf('x'),
      MathMoveSlot(MathSlotMoveDirection.next),
    ],
  );

  static const MathEditCommand secondDerivative = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction(r'\frac', <MathEditArgument>[
        MathEditArgument.braces,
        MathEditArgument.braces,
      ]),
      MathInsertLeaf('d'),
      MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
      MathInsertLeaf('2'),
      MathMoveSlot(MathSlotMoveDirection.next),
      MathMoveSlot(MathSlotMoveDirection.next),
      MathInsertLeaf('d'),
      MathInsertLeaf('x'),
      MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
      MathInsertLeaf('2'),
      MathMoveSlot(MathSlotMoveDirection.next),
      MathMoveSlot(MathSlotMoveDirection.next),
    ],
  );

  static const MathEditCommand limitToInfinity = MathEditCommand(
    <MathEditOperation>[
      MathInsertLeaf(r'\lim'),
      MathInsertFunction('_', <MathEditArgument>[MathEditArgument.braces]),
      MathInsertLeaf('x'),
      MathInsertLeaf(r'\to'),
      MathInsertLeaf(r'\infty'),
      MathMoveSlot(MathSlotMoveDirection.next),
    ],
  );

  static const MathEditCommand integralWithLimits = MathEditCommand(
    <MathEditOperation>[
      MathInsertLeaf(r'\int'),
      MathInsertFunction('_', <MathEditArgument>[MathEditArgument.braces]),
      MathMoveSlot(MathSlotMoveDirection.next),
      MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
      MathMoveSlot(MathSlotMoveDirection.previous, count: 2),
    ],
    composer: MathComposerSpecs.limits,
  );

  static const MathEditCommand sumWithLimits = MathEditCommand(
    <MathEditOperation>[
      MathInsertLeaf(r'\sum'),
      MathInsertFunction('_', <MathEditArgument>[MathEditArgument.braces]),
      MathMoveSlot(MathSlotMoveDirection.next),
      MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
      MathMoveSlot(MathSlotMoveDirection.previous, count: 2),
    ],
    composer: MathComposerSpecs.limits,
  );

  static const MathEditCommand productWithLimits = MathEditCommand(
    <MathEditOperation>[
      MathInsertLeaf(r'\prod'),
      MathInsertFunction('_', <MathEditArgument>[MathEditArgument.braces]),
      MathMoveSlot(MathSlotMoveDirection.next),
      MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
      MathMoveSlot(MathSlotMoveDirection.previous, count: 2),
    ],
    composer: MathComposerSpecs.limits,
  );

  static const MathEditCommand squareRoot = MathEditCommand(<MathEditOperation>[
    MathInsertFunction(r'\sqrt', <MathEditArgument>[MathEditArgument.braces]),
  ], composer: MathComposerSpecs.squareRoot);

  static const MathEditCommand cubeRoot = MathEditCommand(<MathEditOperation>[
    MathInsertFunction(r'\sqrt', <MathEditArgument>[
      MathEditArgument.brackets,
      MathEditArgument.braces,
    ]),
    MathInsertLeaf('3'),
    MathMoveSlot(MathSlotMoveDirection.next),
  ]);

  static const MathEditCommand nthRoot = MathEditCommand(<MathEditOperation>[
    MathInsertFunction(r'\sqrt', <MathEditArgument>[
      MathEditArgument.brackets,
      MathEditArgument.braces,
    ]),
  ], composer: MathComposerSpecs.nthRoot);

  static const MathEditCommand superscriptSlot = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
    ],
    composer: MathComposerSpecs.superscript,
  );

  static const MathEditCommand subscriptSlot = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction('_', <MathEditArgument>[MathEditArgument.braces]),
    ],
    composer: MathComposerSpecs.subscript,
  );

  static const MathEditCommand squared = MathEditCommand(<MathEditOperation>[
    MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
    MathInsertLeaf('2'),
    MathMoveSlot(MathSlotMoveDirection.next),
  ]);

  static const MathEditCommand cubed = MathEditCommand(<MathEditOperation>[
    MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
    MathInsertLeaf('3'),
    MathMoveSlot(MathSlotMoveDirection.next),
  ]);

  // These character-level recipes intentionally preserve the previous visual
  // adapter's behavior for legacy superscript TeX. Phase 6 can normalize them
  // once parser/render compatibility is handled explicitly.
  static const MathEditCommand degree = MathEditCommand(<MathEditOperation>[
    MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
    MathInsertLeaf('\\'),
    MathInsertLeaf('c'),
    MathInsertLeaf('i'),
    MathInsertLeaf('r'),
    MathInsertLeaf('c'),
    MathMoveSlot(MathSlotMoveDirection.next),
  ]);

  static const MathEditCommand prime = MathEditCommand(<MathEditOperation>[
    MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
    MathInsertLeaf('\\'),
    MathInsertLeaf('p'),
    MathInsertLeaf('r'),
    MathInsertLeaf('i'),
    MathInsertLeaf('m'),
    MathInsertLeaf('e'),
    MathMoveSlot(MathSlotMoveDirection.next),
  ]);

  static const MathEditCommand doublePrime = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
      MathInsertLeaf('\\'),
      MathInsertLeaf('p'),
      MathInsertLeaf('r'),
      MathInsertLeaf('i'),
      MathInsertLeaf('m'),
      MathInsertLeaf('e'),
      MathInsertLeaf('\\'),
      MathInsertLeaf('p'),
      MathInsertLeaf('r'),
      MathInsertLeaf('i'),
      MathInsertLeaf('m'),
      MathInsertLeaf('e'),
      MathMoveSlot(MathSlotMoveDirection.next),
    ],
  );

  static const MathEditCommand degreeCelsiusLegacy = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
      MathInsertLeaf('\\'),
      MathInsertLeaf('c'),
      MathInsertLeaf('i'),
      MathInsertLeaf('r'),
      MathInsertLeaf('c'),
      MathInsertLeaf('}'),
      MathInsertLeaf('\\'),
      MathInsertLeaf('t'),
      MathInsertLeaf('e'),
      MathInsertLeaf('x'),
      MathInsertLeaf('t'),
      MathInsertLeaf('{'),
      MathInsertLeaf('C'),
      MathMoveSlot(MathSlotMoveDirection.next),
    ],
  );

  static const MathEditCommand positiveCharge = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
      MathInsertLeaf('+'),
      MathMoveSlot(MathSlotMoveDirection.next),
    ],
  );

  static const MathEditCommand negativeCharge = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
      MathInsertLeaf('-'),
      MathMoveSlot(MathSlotMoveDirection.next),
    ],
  );

  static const MathEditCommand genericPositiveIon = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
      MathInsertLeaf('n'),
      MathInsertLeaf('+'),
      MathMoveSlot(MathSlotMoveDirection.next),
    ],
  );

  static const MathEditCommand logWithBase = MathEditCommand(
    <MathEditOperation>[
      MathInsertLeaf(r'\log'),
      MathInsertFunction('_', <MathEditArgument>[MathEditArgument.braces]),
      MathInsertLeaf('a'),
      MathMoveSlot(MathSlotMoveDirection.next),
      MathInsertLeaf('('),
      MathInsertLeaf(')'),
      MathMoveSlot(MathSlotMoveDirection.previous),
    ],
  );

  static const MathEditCommand exponential = MathEditCommand(
    <MathEditOperation>[
      MathInsertLeaf('e'),
      MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
    ],
  );

  static const MathEditCommand absoluteValue =
      MathEditCommand(<MathEditOperation>[
        MathInsertLeaf('|'),
        MathInsertLeaf('|'),
        MathMoveSlot(MathSlotMoveDirection.previous),
      ], composer: MathComposerSpecs.absoluteValue);

  static const MathEditCommand norm = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf('||'),
    MathInsertLeaf('||'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ], composer: MathComposerSpecs.norm);

  static const MathEditCommand parentheses =
      MathEditCommand(<MathEditOperation>[
        MathInsertLeaf('('),
        MathInsertLeaf(')'),
        MathMoveSlot(MathSlotMoveDirection.previous),
      ], composer: MathComposerSpecs.parentheses);

  static const MathEditCommand squareBrackets =
      MathEditCommand(<MathEditOperation>[
        MathInsertLeaf('['),
        MathInsertLeaf(']'),
        MathMoveSlot(MathSlotMoveDirection.previous),
      ], composer: MathComposerSpecs.squareBrackets);

  static const MathEditCommand braces = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf('{'),
    MathInsertLeaf('}'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand angleBrackets =
      MathEditCommand(<MathEditOperation>[
        MathInsertLeaf(r'\langle'),
        MathInsertLeaf(r'\rangle'),
        MathMoveSlot(MathSlotMoveDirection.previous),
      ], composer: MathComposerSpecs.angleBrackets);

  static const MathEditCommand floor = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\lfloor'),
    MathInsertLeaf(r'\rfloor'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand ceiling = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\lceil'),
    MathInsertLeaf(r'\rceil'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand emptyOverline = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction(r'\overline', <MathEditArgument>[
        MathEditArgument.braces,
      ]),
    ],
    composer: MathComposerSpecs.overline,
  );

  static const MathEditCommand emptyOverrightarrow = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction(r'\overrightarrow', <MathEditArgument>[
        MathEditArgument.braces,
      ]),
    ],
    composer: MathComposerSpecs.accentBody,
  );

  static const MathEditCommand emptyOverleftrightarrow = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction(r'\overleftrightarrow', <MathEditArgument>[
        MathEditArgument.braces,
      ]),
    ],
    composer: MathComposerSpecs.accentBody,
  );

  static const MathEditCommand emptyWidehat = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction(r'\widehat', <MathEditArgument>[
        MathEditArgument.braces,
      ]),
    ],
    composer: MathComposerSpecs.wideHat,
  );

  static const MathEditCommand emptyBar = MathEditCommand(<MathEditOperation>[
    MathInsertFunction(r'\bar', <MathEditArgument>[MathEditArgument.braces]),
  ], composer: MathComposerSpecs.accentBody);

  static const MathEditCommand emptyVector = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction(r'\vec', <MathEditArgument>[MathEditArgument.braces]),
    ],
    composer: MathComposerSpecs.vectorAccent,
  );

  static const MathEditCommand sinCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\sin'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand cosCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\cos'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand tanCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\tan'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand cscCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\csc'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand secCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\sec'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand cotCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\cot'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand logCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\log'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand lnCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\ln'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand arcsinCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\arcsin'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand arccosCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\arccos'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand arctanCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\arctan'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand sinhCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\sinh'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand coshCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\cosh'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand tanhCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\tanh'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);
  static const MathEditCommand tanTheta = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\tan'),
    MathInsertLeaf('('),
    MathInsertLeaf(r'\theta'),
    MathInsertLeaf(')'),
  ]);

  static const MathEditCommand sinSquaredTheta =
      MathEditCommand(<MathEditOperation>[
        MathInsertLeaf(r'\sin^2'),
        MathInsertLeaf('('),
        MathInsertLeaf(r'\theta'),
        MathInsertLeaf(')'),
      ]);

  static const MathEditCommand cosSquaredTheta =
      MathEditCommand(<MathEditOperation>[
        MathInsertLeaf(r'\cos^2'),
        MathInsertLeaf('('),
        MathInsertLeaf(r'\theta'),
        MathInsertLeaf(')'),
      ]);

  static const MathEditCommand subscriptAndSuperscript = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction('_', <MathEditArgument>[MathEditArgument.braces]),
      MathMoveSlot(MathSlotMoveDirection.next),
      MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
      MathMoveSlot(MathSlotMoveDirection.previous, count: 2),
    ],
    composer: MathComposerSpecs.subscriptAndSuperscript,
  );

  static const MathEditCommand genericDerivative = MathEditCommand(
    <MathEditOperation>[
      MathInsertFunction(r'\frac', <MathEditArgument>[
        MathEditArgument.braces,
        MathEditArgument.braces,
      ]),
      MathInsertLeaf('d'),
      MathMoveSlot(MathSlotMoveDirection.next),
      MathInsertLeaf('d'),
      // Return from the denominator to the numerator after its seeded `d`.
      // One previous move only places the cursor before the denominator `d`.
      MathMoveSlot(MathSlotMoveDirection.previous, count: 2),
    ],
    composer: MathComposerSpecs.derivative,
  );

  static const MathEditCommand genericLimit = MathEditCommand(
    <MathEditOperation>[
      MathInsertLeaf(r'\lim'),
      MathInsertFunction('_', <MathEditArgument>[MathEditArgument.braces]),
    ],
    composer: MathComposerSpecs.limitCondition,
  );

  static const MathEditCommand innerProduct =
      MathEditCommand(<MathEditOperation>[
        MathInsertLeaf(r'\langle'),
        MathInsertLeaf(','),
        MathInsertLeaf(r'\rangle'),
        MathMoveSlot(MathSlotMoveDirection.previous, count: 2),
      ], composer: MathComposerSpecs.innerProduct);

  static const MathEditCommand evaluationBar = MathEditCommand(
    <MathEditOperation>[
      MathInsertLeaf('|'),
      MathInsertFunction('_', <MathEditArgument>[MathEditArgument.braces]),
      MathMoveSlot(MathSlotMoveDirection.next),
      MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
      MathMoveSlot(MathSlotMoveDirection.previous, count: 2),
    ],
    composer: MathComposerSpecs.evaluationBar,
  );

  static const MathEditCommand binomial = MathEditCommand(<MathEditOperation>[
    MathInsertFunction(r'\binom', <MathEditArgument>[
      MathEditArgument.braces,
      MathEditArgument.braces,
    ]),
  ], composer: MathComposerSpecs.binomial);

  static const MathEditCommand modulo = MathEditCommand(<MathEditOperation>[
    MathInsertFunction(r'\pmod', <MathEditArgument>[MathEditArgument.braces]),
  ], composer: MathComposerSpecs.modulo);

  static const MathEditCommand bigUnionWithLimits = MathEditCommand(
    <MathEditOperation>[
      MathInsertLeaf(r'\bigcup'),
      MathInsertFunction('_', <MathEditArgument>[MathEditArgument.braces]),
      MathMoveSlot(MathSlotMoveDirection.next),
      MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
      MathMoveSlot(MathSlotMoveDirection.previous, count: 2),
    ],
    composer: MathComposerSpecs.limits,
  );

  static const MathEditCommand bigIntersectionWithLimits = MathEditCommand(
    <MathEditOperation>[
      MathInsertLeaf(r'\bigcap'),
      MathInsertFunction('_', <MathEditArgument>[MathEditArgument.braces]),
      MathMoveSlot(MathSlotMoveDirection.next),
      MathInsertFunction('^', <MathEditArgument>[MathEditArgument.braces]),
      MathMoveSlot(MathSlotMoveDirection.previous, count: 2),
    ],
    composer: MathComposerSpecs.limits,
  );

  static const MathEditCommand gcdCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\gcd'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand lcmCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\operatorname{lcm}'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand argCall = MathEditCommand(<MathEditOperation>[
    MathInsertLeaf(r'\arg'),
    MathInsertLeaf('('),
    MathInsertLeaf(')'),
    MathMoveSlot(MathSlotMoveDirection.previous),
  ]);

  static const MathEditCommand matrix2x2 = MathEditCommand(<MathEditOperation>[
    MathInsertDynamicStructure(
      MathDynamicStructureSpec(
        kind: MathDynamicStructureKind.matrix,
        rows: 2,
        columns: 2,
      ),
    ),
  ]);

  static const MathEditCommand matrix3x3 = MathEditCommand(<MathEditOperation>[
    MathInsertDynamicStructure(
      MathDynamicStructureSpec(
        kind: MathDynamicStructureKind.matrix,
        rows: 3,
        columns: 3,
      ),
    ),
  ]);

  static const MathEditCommand determinant2x2 =
      MathEditCommand(<MathEditOperation>[
        MathInsertDynamicStructure(
          MathDynamicStructureSpec(
            kind: MathDynamicStructureKind.determinant,
            rows: 2,
            columns: 2,
          ),
        ),
      ]);

  static const MathEditCommand piecewise2Rows =
      MathEditCommand(<MathEditOperation>[
        MathInsertDynamicStructure(
          MathDynamicStructureSpec(
            kind: MathDynamicStructureKind.piecewise,
            rows: 2,
          ),
        ),
      ]);

  static const MathEditCommand triangleSubscript = MathEditCommand(
    <MathEditOperation>[
      MathInsertLeaf(r'\triangle'),
      MathInsertFunction('_', <MathEditArgument>[MathEditArgument.braces]),
    ],
  );

  static const MathEditCommand graphFrameLegacy = MathEditCommand(
    <MathEditOperation>[MathInsertLeaf(r'\text{Graph Frame}')],
  );
}

/// Declarative compatibility table for callers that still use raw
/// visual-editor insertion with historical catalogue TeX.
///
/// New catalogue UI code must use `MathSymbol.editorCommand`; this table exists
/// only to preserve old raw/recent/variation insertion behavior during the
/// staged refactor.
abstract final class MathLegacyEditCommandRegistry {
  static const Map<String, MathEditCommand> bySource =
      <String, MathEditCommand>{
        r'\frac{1}{2}': MathEditCommands.half,
        r'\frac{1}{3}': MathEditCommands.oneThird,
        r'\frac{2}{3}': MathEditCommands.twoThirds,
        r'\frac{d}{dx}': MathEditCommands.derivativeDByDx,
        r'\frac{dy}{dx}': MathEditCommands.derivativeDyByDx,
        r'\frac{d^2}{dx^2}': MathEditCommands.secondDerivative,
        r'\lim_{x \to \infty}': MathEditCommands.limitToInfinity,
        r'\int_{}^{}': MathEditCommands.integralWithLimits,
        r'\int_{}^{}^{}': MathEditCommands.integralWithLimits,
        r'\sum_{}^{}': MathEditCommands.sumWithLimits,
        r'\sum_{}^{}^{}': MathEditCommands.sumWithLimits,
        r'\prod_{}^{}': MathEditCommands.productWithLimits,
        r'\prod_{}^{}^{}': MathEditCommands.productWithLimits,
        r'\triangle_{A B C}': MathEditCommands.triangleSubscript,
        r'\overline{AB}': MathEditCommands.emptyOverline,
        r'\overrightarrow{AB}': MathEditCommands.emptyOverrightarrow,
        r'\overleftrightarrow{AB}': MathEditCommands.emptyOverleftrightarrow,
        r'\widehat{AB}': MathEditCommands.emptyWidehat,
        r'\bar{x}': MathEditCommands.emptyBar,
        r'\vec{v}': MathEditCommands.emptyVector,
        r'\vec{F}': MathEditCommands.emptyVector,
        r'\text{Graph}': MathEditCommands.graphFrameLegacy,
        r'\sin': MathEditCommands.sinCall,
        r'\cos': MathEditCommands.cosCall,
        r'\tan': MathEditCommands.tanCall,
        r'\csc': MathEditCommands.cscCall,
        r'\sec': MathEditCommands.secCall,
        r'\cot': MathEditCommands.cotCall,
        r'\log': MathEditCommands.logCall,
        r'\ln': MathEditCommands.lnCall,
        r'\arcsin': MathEditCommands.arcsinCall,
        r'\arccos': MathEditCommands.arccosCall,
        r'\arctan': MathEditCommands.arctanCall,
        r'\sinh': MathEditCommands.sinhCall,
        r'\cosh': MathEditCommands.coshCall,
        r'\tanh': MathEditCommands.tanhCall,
        r'\sin^2 \theta': MathEditCommands.sinSquaredTheta,
        r'\cos^2 \theta': MathEditCommands.cosSquaredTheta,
        r'\tan \theta': MathEditCommands.tanTheta,
        r'\sqrt{}': MathEditCommands.squareRoot,
        r'\sqrt[3]{}': MathEditCommands.cubeRoot,
        r'\sqrt[]{}': MathEditCommands.nthRoot,
        r'^{}': MathEditCommands.superscriptSlot,
        r'^{2}': MathEditCommands.squared,
        r'^{3}': MathEditCommands.cubed,
        r'^{\circ}': MathEditCommands.degree,
        r'^{\prime}': MathEditCommands.prime,
        r'^{\prime\prime}': MathEditCommands.doublePrime,
        r'^{+}': MathEditCommands.positiveCharge,
        r'^{-}': MathEditCommands.negativeCharge,
        r'^{n+}': MathEditCommands.genericPositiveIon,
        r'^{\circ}\text{C}': MathEditCommands.degreeCelsiusLegacy,
        r'_{}': MathEditCommands.subscriptSlot,
        r'\log_{}': MathEditCommands.logWithBase,
        r'e^{}': MathEditCommands.exponential,
        r'|{}|': MathEditCommands.absoluteValue,
        r'||{}||': MathEditCommands.norm,
        '(': MathEditCommands.parentheses,
        '[': MathEditCommands.squareBrackets,
        '{': MathEditCommands.braces,
        r'\langle\rangle': MathEditCommands.angleBrackets,
        r'\lfloor\rfloor': MathEditCommands.floor,
        r'\lceil\rceil': MathEditCommands.ceiling,
        r'\frac{}{}': MathEditCommands.fraction,
        r'_{}^{}': MathEditCommands.subscriptAndSuperscript,
        r'\frac{d{}}{d{}}': MathEditCommands.genericDerivative,
        r'\lim_{}': MathEditCommands.genericLimit,
        r'\langle{},{}\rangle': MathEditCommands.innerProduct,
        r'|_{}^{}': MathEditCommands.evaluationBar,
        r'\binom{}{}': MathEditCommands.binomial,
        r'\pmod{}': MathEditCommands.modulo,
        r'\bigcup_{}^{}': MathEditCommands.bigUnionWithLimits,
        r'\bigcap_{}^{}': MathEditCommands.bigIntersectionWithLimits,
        r'\gcd': MathEditCommands.gcdCall,
        r'\operatorname{lcm}': MathEditCommands.lcmCall,
        r'\arg': MathEditCommands.argCall,
        r'\overline{}': MathEditCommands.emptyOverline,
      };
}
