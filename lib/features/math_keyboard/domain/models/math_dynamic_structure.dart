/// Runtime-configurable mathematical structures whose slot count depends on
/// teacher input (matrix dimensions, number of cases, derivation rows, etc.).
///
/// These models deliberately contain no Flutter or math_keyboard package
/// types. Rendering/editing adapters consume the compiled token plan.
enum MathDynamicStructureKind {
  matrix,
  determinant,
  augmentedMatrix,
  piecewise,
  equationSystem,
  alignedDerivation,
}

abstract final class MathDynamicStructureLimits {
  static const Set<String> alignedRelations = <String>{
    '=',
    r'\leq',
    r'\geq',
    r'\Rightarrow',
  };

  static const int minRows = 1;
  static const int maxRows = 12;
  static const int minColumns = 1;
  static const int maxColumns = 12;
  static const int maxSlots = 144;
}

class MathDynamicStructureSpec {
  final MathDynamicStructureKind kind;
  final int rows;
  final int columns;

  /// For augmented matrices, the vertical divider is placed after this
  /// 1-based column. Null for every other structure kind.
  final int? augmentedSplitAfter;

  /// Relation rendered between the two editable columns of an aligned
  /// derivation. The UI only exposes a vetted small set, but keeping it in the
  /// domain spec makes the compiler reusable and testable.
  final String relation;

  const MathDynamicStructureSpec({
    required this.kind,
    required this.rows,
    this.columns = 1,
    this.augmentedSplitAfter,
    this.relation = '=',
  });

  int get effectiveColumns {
    switch (kind) {
      case MathDynamicStructureKind.matrix:
      case MathDynamicStructureKind.determinant:
      case MathDynamicStructureKind.augmentedMatrix:
        return columns;
      case MathDynamicStructureKind.piecewise:
      case MathDynamicStructureKind.alignedDerivation:
        return 2;
      case MathDynamicStructureKind.equationSystem:
        return 1;
    }
  }

  int get slotCount => rows * effectiveColumns;

  bool get isValid => validationMessage == null;

  String? get validationMessage {
    if (rows < MathDynamicStructureLimits.minRows ||
        rows > MathDynamicStructureLimits.maxRows) {
      return 'Rows must be between ${MathDynamicStructureLimits.minRows} and ${MathDynamicStructureLimits.maxRows}.';
    }
    if (effectiveColumns < MathDynamicStructureLimits.minColumns ||
        effectiveColumns > MathDynamicStructureLimits.maxColumns) {
      return 'Columns must be between ${MathDynamicStructureLimits.minColumns} and ${MathDynamicStructureLimits.maxColumns}.';
    }
    if (slotCount > MathDynamicStructureLimits.maxSlots) {
      return 'Structure is too large ($slotCount editable boxes; maximum ${MathDynamicStructureLimits.maxSlots}).';
    }
    if (kind == MathDynamicStructureKind.determinant && rows != columns) {
      return 'A determinant must be square (same rows and columns).';
    }
    if (kind == MathDynamicStructureKind.augmentedMatrix) {
      if (columns < 2) {
        return 'An augmented matrix needs at least two columns.';
      }
      final split = augmentedSplitAfter;
      if (split == null || split < 1 || split >= columns) {
        return 'Choose a divider between matrix columns.';
      }
    } else if (augmentedSplitAfter != null) {
      return 'Only augmented matrices can define a divider column.';
    }
    if (kind == MathDynamicStructureKind.alignedDerivation) {
      if (relation.trim().isEmpty) {
        return 'Aligned derivations need a relation between columns.';
      }
      if (!MathDynamicStructureLimits.alignedRelations.contains(relation)) {
        return 'Aligned derivation relation is not supported.';
      }
    }
    return null;
  }

  MathDynamicStructureSpec copyWith({
    MathDynamicStructureKind? kind,
    int? rows,
    int? columns,
    int? augmentedSplitAfter,
    bool clearAugmentedSplit = false,
    String? relation,
  }) {
    return MathDynamicStructureSpec(
      kind: kind ?? this.kind,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      augmentedSplitAfter: clearAugmentedSplit
          ? null
          : (augmentedSplitAfter ?? this.augmentedSplitAfter),
      relation: relation ?? this.relation,
    );
  }
}

class MathDynamicStructureInstance {
  final MathDynamicStructureSpec spec;
  final List<String> values;

  MathDynamicStructureInstance({required this.spec, List<String>? values})
    : values = List<String>.unmodifiable(
        values ?? List<String>.filled(spec.slotCount, ''),
      ) {
    if (!spec.isValid) {
      throw ArgumentError(spec.validationMessage);
    }
    if (this.values.length != spec.slotCount) {
      throw ArgumentError(
        'Expected ${spec.slotCount} slot values, got ${this.values.length}.',
      );
    }
  }

  String valueAt(int index) => values[index];
}

enum MathDynamicSlotRole {
  matrixCell,
  expression,
  condition,
  equation,
  leftSide,
  rightSide,
}

class MathDynamicSlotSpec {
  final int index;
  final int row;
  final int column;
  final MathDynamicSlotRole role;
  final String label;

  const MathDynamicSlotSpec({
    required this.index,
    required this.row,
    required this.column,
    required this.role,
    required this.label,
  });
}

sealed class MathDynamicStructureToken {
  const MathDynamicStructureToken();
}

class MathDynamicLiteralToken extends MathDynamicStructureToken {
  final String source;

  const MathDynamicLiteralToken(this.source);
}

class MathDynamicSlotToken extends MathDynamicStructureToken {
  final MathDynamicSlotSpec slot;
  final String initialValue;

  const MathDynamicSlotToken({required this.slot, required this.initialValue});
}

class MathDynamicStructureDocument {
  final MathDynamicStructureInstance instance;
  final List<MathDynamicStructureToken> tokens;
  final List<MathDynamicSlotSpec> slots;
  final String tex;
  final String plainText;

  const MathDynamicStructureDocument({
    required this.instance,
    required this.tokens,
    required this.slots,
    required this.tex,
    required this.plainText,
  });
}
