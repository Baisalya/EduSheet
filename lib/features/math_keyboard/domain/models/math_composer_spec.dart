/// Semantic description of a structured math insertion.
///
/// The editor command is responsible for cursor choreography. This model
/// describes the slots a teacher sees so composition logic, source wrapping,
/// tests and future UI do not have to infer structure from raw TeX strings.
enum MathComposerSlotRole {
  numerator,
  denominator,
  radicand,
  rootIndex,
  exponent,
  subscript,
  lowerLimit,
  upperLimit,
  variable,
  expression,
  argument,
  base,
  leftValue,
  rightValue,
  upperValue,
  lowerValue,
  modulus,
  body,
  endpoint,
}

class MathComposerSlotSpec {
  final String id;
  final String label;
  final MathComposerSlotRole role;

  /// True when the insertion recipe pre-populates part of this slot (for
  /// example the `d` in a derivative template) but still leaves it editable.
  final bool seeded;

  const MathComposerSlotSpec({
    required this.id,
    required this.label,
    required this.role,
    this.seeded = false,
  });
}

/// TeX-source wrapping recipe used only when an editor exposes an actual text
/// selection. The visual MathField in math_keyboard 0.3.3 does not expose a
/// public selection range, so visual composition continues through slots.
class MathSelectionWrapRecipe {
  final String beforeSelection;
  final String afterSelection;

  /// Cursor offset measured from the beginning of [afterSelection].
  ///
  /// Example: a fraction uses `}{}` and offset 2 so a selected numerator is
  /// wrapped as `\\frac{selection}{|}`.
  final int cursorOffsetInSuffix;

  const MathSelectionWrapRecipe({
    required this.beforeSelection,
    required this.afterSelection,
    required this.cursorOffsetInSuffix,
  }) : assert(cursorOffsetInSuffix >= 0),
       assert(cursorOffsetInSuffix <= afterSelection.length);
}

class MathComposerSpec {
  final String id;
  final List<MathComposerSlotSpec> slots;
  final MathSelectionWrapRecipe? selectionWrap;

  /// Structured commands are intentionally nestable unless a future adapter
  /// explicitly reports otherwise.
  final bool supportsNesting;

  const MathComposerSpec({
    required this.id,
    required this.slots,
    this.selectionWrap,
    this.supportsNesting = true,
  });

  int get slotCount => slots.length;
}

/// Reusable structure metadata. These constants describe meaning only; they do
/// not know about Flutter widgets or the math_keyboard package.
abstract final class MathComposerSpecs {
  static const binomial = MathComposerSpec(
    id: 'binomial-coefficient',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'upper',
        label: 'Total items',
        role: MathComposerSlotRole.upperValue,
      ),
      MathComposerSlotSpec(
        id: 'lower',
        label: 'Chosen items',
        role: MathComposerSlotRole.lowerValue,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: r'\binom{',
      afterSelection: '}{}',
      cursorOffsetInSuffix: 2,
    ),
  );

  static const modulo = MathComposerSpec(
    id: 'modulo-argument',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'modulus',
        label: 'Modulus',
        role: MathComposerSlotRole.modulus,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: r'\pmod{',
      afterSelection: '}',
      cursorOffsetInSuffix: 1,
    ),
  );

  static const fraction = MathComposerSpec(
    id: 'fraction',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'numerator',
        label: 'Numerator',
        role: MathComposerSlotRole.numerator,
      ),
      MathComposerSlotSpec(
        id: 'denominator',
        label: 'Denominator',
        role: MathComposerSlotRole.denominator,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: r'\frac{',
      afterSelection: '}{}',
      cursorOffsetInSuffix: 2,
    ),
  );

  static const squareRoot = MathComposerSpec(
    id: 'square-root',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'radicand',
        label: 'Inside root',
        role: MathComposerSlotRole.radicand,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: r'\sqrt{',
      afterSelection: '}',
      cursorOffsetInSuffix: 1,
    ),
  );

  static const nthRoot = MathComposerSpec(
    id: 'nth-root',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'index',
        label: 'Root index',
        role: MathComposerSlotRole.rootIndex,
      ),
      MathComposerSlotSpec(
        id: 'radicand',
        label: 'Inside root',
        role: MathComposerSlotRole.radicand,
      ),
    ],
  );

  static const superscript = MathComposerSpec(
    id: 'superscript',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'exponent',
        label: 'Exponent',
        role: MathComposerSlotRole.exponent,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: '',
      afterSelection: '^{}',
      cursorOffsetInSuffix: 2,
    ),
  );

  static const subscript = MathComposerSpec(
    id: 'subscript',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'subscript',
        label: 'Subscript',
        role: MathComposerSlotRole.subscript,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: '',
      afterSelection: '_{}',
      cursorOffsetInSuffix: 2,
    ),
  );

  static const subscriptAndSuperscript = MathComposerSpec(
    id: 'subscript-superscript',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'subscript',
        label: 'Subscript',
        role: MathComposerSlotRole.subscript,
      ),
      MathComposerSlotSpec(
        id: 'exponent',
        label: 'Exponent',
        role: MathComposerSlotRole.exponent,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: '',
      afterSelection: '_{}^{}',
      cursorOffsetInSuffix: 2,
    ),
  );

  static const limits = MathComposerSpec(
    id: 'lower-upper-limits',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'lower',
        label: 'Lower limit',
        role: MathComposerSlotRole.lowerLimit,
      ),
      MathComposerSlotSpec(
        id: 'upper',
        label: 'Upper limit',
        role: MathComposerSlotRole.upperLimit,
      ),
    ],
  );

  static const limitCondition = MathComposerSpec(
    id: 'limit-condition',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'condition',
        label: 'Limit condition',
        role: MathComposerSlotRole.lowerLimit,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: r'\lim_{',
      afterSelection: '}',
      cursorOffsetInSuffix: 1,
    ),
  );

  static const derivative = MathComposerSpec(
    id: 'derivative',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'numerator-expression',
        label: 'Differentiate',
        role: MathComposerSlotRole.expression,
        seeded: true,
      ),
      MathComposerSlotSpec(
        id: 'denominator-variable',
        label: 'Variable',
        role: MathComposerSlotRole.variable,
        seeded: true,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: r'\frac{d',
      afterSelection: r'}{d{}}',
      cursorOffsetInSuffix: 4,
    ),
  );

  static const absoluteValue = MathComposerSpec(
    id: 'absolute-value',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'body',
        label: 'Inside bars',
        role: MathComposerSlotRole.body,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: '|',
      afterSelection: '|',
      cursorOffsetInSuffix: 1,
    ),
  );

  static const norm = MathComposerSpec(
    id: 'norm',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'body',
        label: 'Inside norm',
        role: MathComposerSlotRole.body,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: '||',
      afterSelection: '||',
      cursorOffsetInSuffix: 2,
    ),
  );

  static const parentheses = MathComposerSpec(
    id: 'parentheses',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'body',
        label: 'Inside parentheses',
        role: MathComposerSlotRole.body,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: '(',
      afterSelection: ')',
      cursorOffsetInSuffix: 1,
    ),
  );

  static const squareBrackets = MathComposerSpec(
    id: 'square-brackets',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'body',
        label: 'Inside brackets',
        role: MathComposerSlotRole.body,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: '[',
      afterSelection: ']',
      cursorOffsetInSuffix: 1,
    ),
  );

  static const angleBrackets = MathComposerSpec(
    id: 'angle-brackets',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'body',
        label: 'Inside angle brackets',
        role: MathComposerSlotRole.body,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: r'\langle ',
      afterSelection: r' \rangle',
      cursorOffsetInSuffix: 8,
    ),
  );

  static const innerProduct = MathComposerSpec(
    id: 'inner-product',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'left',
        label: 'Left value',
        role: MathComposerSlotRole.leftValue,
      ),
      MathComposerSlotSpec(
        id: 'right',
        label: 'Right value',
        role: MathComposerSlotRole.rightValue,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: r'\langle ',
      afterSelection: r', {}\rangle',
      cursorOffsetInSuffix: 3,
    ),
  );

  static const evaluationBar = MathComposerSpec(
    id: 'evaluation-bar',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'lower',
        label: 'Lower endpoint',
        role: MathComposerSlotRole.lowerLimit,
      ),
      MathComposerSlotSpec(
        id: 'upper',
        label: 'Upper endpoint',
        role: MathComposerSlotRole.upperLimit,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: '',
      afterSelection: r'|_{}^{}',
      cursorOffsetInSuffix: 3,
    ),
  );

  static const accentBody = MathComposerSpec(
    id: 'accent-body',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'body',
        label: 'Expression',
        role: MathComposerSlotRole.body,
      ),
    ],
  );

  static const overline = MathComposerSpec(
    id: 'overline',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'body',
        label: 'Expression',
        role: MathComposerSlotRole.body,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: r'\overline{',
      afterSelection: '}',
      cursorOffsetInSuffix: 1,
    ),
  );

  static const vectorAccent = MathComposerSpec(
    id: 'vector-accent',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'body',
        label: 'Vector expression',
        role: MathComposerSlotRole.body,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: r'\vec{',
      afterSelection: '}',
      cursorOffsetInSuffix: 1,
    ),
  );

  static const wideHat = MathComposerSpec(
    id: 'wide-hat',
    slots: <MathComposerSlotSpec>[
      MathComposerSlotSpec(
        id: 'body',
        label: 'Expression',
        role: MathComposerSlotRole.body,
      ),
    ],
    selectionWrap: MathSelectionWrapRecipe(
      beforeSelection: r'\widehat{',
      afterSelection: '}',
      cursorOffsetInSuffix: 1,
    ),
  );
}
