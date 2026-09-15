import '../models/math_dynamic_structure.dart';

/// Compiles runtime structure specs into canonical TeX plus a flat token plan
/// that visual adapters can turn into navigable editable slots.
///
/// The reverse parser intentionally recognizes only these environment families
/// and the canonical/fixed forms EduSheet already owns. It is not a general TeX
/// parser; unknown input is left to the existing Advanced source path.
class MathDynamicStructureCodec {
  const MathDynamicStructureCodec();

  MathDynamicStructureDocument compile(MathDynamicStructureInstance instance) {
    final spec = instance.spec;
    if (!spec.isValid) {
      throw ArgumentError(spec.validationMessage);
    }

    return switch (spec.kind) {
      MathDynamicStructureKind.matrix => _compileMatrix(
        instance,
        begin: r'\begin{pmatrix}',
        end: r'\end{pmatrix}',
        description: '${spec.rows}×${spec.columns} matrix',
      ),
      MathDynamicStructureKind.determinant => _compileMatrix(
        instance,
        begin: r'\begin{vmatrix}',
        end: r'\end{vmatrix}',
        description: '${spec.rows}×${spec.columns} determinant',
      ),
      MathDynamicStructureKind.augmentedMatrix => _compileAugmented(instance),
      MathDynamicStructureKind.piecewise => _compilePiecewise(instance),
      MathDynamicStructureKind.equationSystem => _compileEquationSystem(
        instance,
      ),
      MathDynamicStructureKind.alignedDerivation => _compileAligned(instance),
    };
  }

  MathDynamicStructureInstance? tryParse(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return null;

    final matrix = _tryParseSimpleMatrix(trimmed);
    if (matrix != null) return matrix;

    final augmented = _tryParseAugmented(trimmed);
    if (augmented != null) return augmented;

    final cases = _tryParseCases(trimmed);
    if (cases != null) return cases;

    return _tryParseAligned(trimmed);
  }

  MathDynamicStructureDocument _compileMatrix(
    MathDynamicStructureInstance instance, {
    required String begin,
    required String end,
    required String description,
  }) {
    final tokens = <MathDynamicStructureToken>[MathDynamicLiteralToken(begin)];
    final slots = <MathDynamicSlotSpec>[];
    var slotIndex = 0;

    for (var row = 0; row < instance.spec.rows; row++) {
      for (var column = 0; column < instance.spec.columns; column++) {
        final slot = MathDynamicSlotSpec(
          index: slotIndex,
          row: row,
          column: column,
          role: MathDynamicSlotRole.matrixCell,
          label: 'Row ${row + 1}, column ${column + 1}',
        );
        slots.add(slot);
        tokens.add(
          MathDynamicSlotToken(
            slot: slot,
            initialValue: instance.valueAt(slotIndex),
          ),
        );
        slotIndex++;
        if (column + 1 < instance.spec.columns) {
          tokens.add(const MathDynamicLiteralToken('&'));
        }
      }
      if (row + 1 < instance.spec.rows) {
        tokens.add(const MathDynamicLiteralToken(r'\\'));
      }
    }
    tokens.add(MathDynamicLiteralToken(end));

    return _document(instance, tokens, slots, description);
  }

  MathDynamicStructureDocument _compileAugmented(
    MathDynamicStructureInstance instance,
  ) {
    final spec = instance.spec;
    final split = spec.augmentedSplitAfter!;
    final columnSpec = StringBuffer();
    for (var column = 1; column <= spec.columns; column++) {
      if (column == split + 1) columnSpec.write('|');
      columnSpec.write('c');
    }

    final arrayOpening = StringBuffer(r'\left[\begin{array}{')
      ..write(columnSpec)
      ..write('}');

    final tokens = <MathDynamicStructureToken>[
      MathDynamicLiteralToken(arrayOpening.toString()),
    ];
    final slots = <MathDynamicSlotSpec>[];
    var slotIndex = 0;

    for (var row = 0; row < spec.rows; row++) {
      for (var column = 0; column < spec.columns; column++) {
        final slot = MathDynamicSlotSpec(
          index: slotIndex,
          row: row,
          column: column,
          role: MathDynamicSlotRole.matrixCell,
          label: 'Row ${row + 1}, column ${column + 1}',
        );
        slots.add(slot);
        tokens.add(
          MathDynamicSlotToken(
            slot: slot,
            initialValue: instance.valueAt(slotIndex),
          ),
        );
        slotIndex++;
        if (column + 1 < spec.columns) {
          tokens.add(const MathDynamicLiteralToken('&'));
        }
      }
      if (row + 1 < spec.rows) {
        tokens.add(const MathDynamicLiteralToken(r'\\'));
      }
    }
    tokens.add(const MathDynamicLiteralToken(r'\end{array}\right]'));

    return _document(
      instance,
      tokens,
      slots,
      '${spec.rows}×${spec.columns} augmented matrix',
    );
  }

  MathDynamicStructureDocument _compilePiecewise(
    MathDynamicStructureInstance instance,
  ) {
    final tokens = <MathDynamicStructureToken>[
      const MathDynamicLiteralToken(r'f(x)=\begin{cases}'),
    ];
    final slots = <MathDynamicSlotSpec>[];
    var slotIndex = 0;

    for (var row = 0; row < instance.spec.rows; row++) {
      final expression = MathDynamicSlotSpec(
        index: slotIndex,
        row: row,
        column: 0,
        role: MathDynamicSlotRole.expression,
        label: 'Case ${row + 1} expression',
      );
      slots.add(expression);
      tokens.add(
        MathDynamicSlotToken(
          slot: expression,
          initialValue: instance.valueAt(slotIndex),
        ),
      );
      slotIndex++;
      tokens.add(const MathDynamicLiteralToken('&'));

      final condition = MathDynamicSlotSpec(
        index: slotIndex,
        row: row,
        column: 1,
        role: MathDynamicSlotRole.condition,
        label: 'Case ${row + 1} condition',
      );
      slots.add(condition);
      tokens.add(
        MathDynamicSlotToken(
          slot: condition,
          initialValue: instance.valueAt(slotIndex),
        ),
      );
      slotIndex++;
      if (row + 1 < instance.spec.rows) {
        tokens.add(const MathDynamicLiteralToken(r'\\'));
      }
    }
    tokens.add(const MathDynamicLiteralToken(r'\end{cases}'));

    return _document(
      instance,
      tokens,
      slots,
      'piecewise function with ${instance.spec.rows} cases',
    );
  }

  MathDynamicStructureDocument _compileEquationSystem(
    MathDynamicStructureInstance instance,
  ) {
    final tokens = <MathDynamicStructureToken>[
      const MathDynamicLiteralToken(r'\begin{cases}'),
    ];
    final slots = <MathDynamicSlotSpec>[];

    for (var row = 0; row < instance.spec.rows; row++) {
      final slot = MathDynamicSlotSpec(
        index: row,
        row: row,
        column: 0,
        role: MathDynamicSlotRole.equation,
        label: 'Equation ${row + 1}',
      );
      slots.add(slot);
      tokens.add(
        MathDynamicSlotToken(slot: slot, initialValue: instance.valueAt(row)),
      );
      if (row + 1 < instance.spec.rows) {
        tokens.add(const MathDynamicLiteralToken(r'\\'));
      }
    }
    tokens.add(const MathDynamicLiteralToken(r'\end{cases}'));

    return _document(
      instance,
      tokens,
      slots,
      'system of ${instance.spec.rows} equations',
    );
  }

  MathDynamicStructureDocument _compileAligned(
    MathDynamicStructureInstance instance,
  ) {
    final tokens = <MathDynamicStructureToken>[
      const MathDynamicLiteralToken(r'\begin{aligned}'),
    ];
    final slots = <MathDynamicSlotSpec>[];
    var slotIndex = 0;

    for (var row = 0; row < instance.spec.rows; row++) {
      final left = MathDynamicSlotSpec(
        index: slotIndex,
        row: row,
        column: 0,
        role: MathDynamicSlotRole.leftSide,
        label: 'Step ${row + 1} left side',
      );
      slots.add(left);
      tokens.add(
        MathDynamicSlotToken(
          slot: left,
          initialValue: instance.valueAt(slotIndex),
        ),
      );
      slotIndex++;
      tokens.add(MathDynamicLiteralToken('&${instance.spec.relation}'));

      final right = MathDynamicSlotSpec(
        index: slotIndex,
        row: row,
        column: 1,
        role: MathDynamicSlotRole.rightSide,
        label: 'Step ${row + 1} right side',
      );
      slots.add(right);
      tokens.add(
        MathDynamicSlotToken(
          slot: right,
          initialValue: instance.valueAt(slotIndex),
        ),
      );
      slotIndex++;
      if (row + 1 < instance.spec.rows) {
        tokens.add(const MathDynamicLiteralToken(r'\\'));
      }
    }
    tokens.add(const MathDynamicLiteralToken(r'\end{aligned}'));

    return _document(
      instance,
      tokens,
      slots,
      'aligned derivation with ${instance.spec.rows} steps',
    );
  }

  MathDynamicStructureDocument _document(
    MathDynamicStructureInstance instance,
    List<MathDynamicStructureToken> tokens,
    List<MathDynamicSlotSpec> slots,
    String description,
  ) {
    final buffer = StringBuffer();
    for (final token in tokens) {
      switch (token) {
        case MathDynamicLiteralToken(:final source):
          buffer.write(source);
        case MathDynamicSlotToken(:final initialValue):
          buffer
            ..write('{')
            ..write(initialValue)
            ..write('}');
      }
    }
    return MathDynamicStructureDocument(
      instance: instance,
      tokens: List<MathDynamicStructureToken>.unmodifiable(tokens),
      slots: List<MathDynamicSlotSpec>.unmodifiable(slots),
      tex: buffer.toString(),
      plainText: '[$description]',
    );
  }

  MathDynamicStructureInstance? _tryParseSimpleMatrix(String source) {
    final match = RegExp(
      r'^\\begin\{(pmatrix|vmatrix)\}([\s\S]*)\\end\{(pmatrix|vmatrix)\}$',
    ).firstMatch(source);
    if (match == null || match.group(1) != match.group(3)) return null;

    final rows = _splitRows(match.group(2)!);
    if (rows.isEmpty) return null;
    final cells = rows.map(_splitCells).toList(growable: false);
    final columns = cells.first.length;
    if (columns == 0 || cells.any((row) => row.length != columns)) return null;

    final kind = match.group(1) == 'vmatrix'
        ? MathDynamicStructureKind.determinant
        : MathDynamicStructureKind.matrix;
    final spec = MathDynamicStructureSpec(
      kind: kind,
      rows: rows.length,
      columns: columns,
    );
    if (!spec.isValid) return null;
    return MathDynamicStructureInstance(
      spec: spec,
      values: cells.expand((row) => row.map(_normalizeCell)).toList(),
    );
  }

  MathDynamicStructureInstance? _tryParseAugmented(String source) {
    final match = RegExp(
      r'^\\left\[\\begin\{array\}\{([clr|]+)\}([\s\S]*)\\end\{array\}\\right\]$',
    ).firstMatch(source);
    if (match == null) return null;

    final columnSpec = match.group(1)!;
    if (columnSpec.indexOf('|') != columnSpec.lastIndexOf('|')) return null;
    final splitIndex = columnSpec.indexOf('|');
    if (splitIndex <= 0 || splitIndex >= columnSpec.length - 1) return null;
    final columns = columnSpec.replaceAll('|', '').length;
    final splitAfter = columnSpec.substring(0, splitIndex).length;
    final rows = _splitRows(match.group(2)!);
    final cells = rows.map(_splitCells).toList(growable: false);
    if (rows.isEmpty || cells.any((row) => row.length != columns)) return null;

    final spec = MathDynamicStructureSpec(
      kind: MathDynamicStructureKind.augmentedMatrix,
      rows: rows.length,
      columns: columns,
      augmentedSplitAfter: splitAfter,
    );
    if (!spec.isValid) return null;
    return MathDynamicStructureInstance(
      spec: spec,
      values: cells.expand((row) => row.map(_normalizeCell)).toList(),
    );
  }

  MathDynamicStructureInstance? _tryParseCases(String source) {
    const piecewisePrefix = r'f(x)=';
    final hasPiecewisePrefix = source.startsWith(piecewisePrefix);
    final bodySource = hasPiecewisePrefix
        ? source.substring(piecewisePrefix.length)
        : source;
    final match = RegExp(
      r'^\\begin\{cases\}([\s\S]*)\\end\{cases\}$',
    ).firstMatch(bodySource);
    if (match == null) return null;

    final rows = _splitRows(match.group(1)!);
    if (rows.isEmpty) return null;
    final cells = rows.map(_splitCells).toList(growable: false);

    if (!hasPiecewisePrefix &&
        cells.every(
          (row) =>
              row.length == 2 &&
              _startsWithEquationRelation(_normalizeCell(row[1])),
        )) {
      final spec = MathDynamicStructureSpec(
        kind: MathDynamicStructureKind.equationSystem,
        rows: rows.length,
      );
      if (!spec.isValid) return null;
      return MathDynamicStructureInstance(
        spec: spec,
        values: cells
            .map((row) => '${_normalizeCell(row[0])}${_normalizeCell(row[1])}')
            .toList(growable: false),
      );
    }

    final piecewise =
        hasPiecewisePrefix || cells.every((row) => row.length == 2);
    if (piecewise) {
      if (cells.any((row) => row.length != 2)) return null;
      final spec = MathDynamicStructureSpec(
        kind: MathDynamicStructureKind.piecewise,
        rows: rows.length,
      );
      if (!spec.isValid) return null;
      return MathDynamicStructureInstance(
        spec: spec,
        values: cells.expand((row) => row.map(_normalizeCell)).toList(),
      );
    }

    if (cells.any((row) => row.length != 1)) return null;
    final spec = MathDynamicStructureSpec(
      kind: MathDynamicStructureKind.equationSystem,
      rows: rows.length,
    );
    if (!spec.isValid) return null;
    return MathDynamicStructureInstance(
      spec: spec,
      values: cells.map((row) => _normalizeCell(row.single)).toList(),
    );
  }

  MathDynamicStructureInstance? _tryParseAligned(String source) {
    final match = RegExp(
      r'^\\begin\{aligned\}([\s\S]*)\\end\{aligned\}$',
    ).firstMatch(source);
    if (match == null) return null;

    final rows = _splitRows(match.group(1)!);
    if (rows.isEmpty) return null;
    final values = <String>[];
    String? relation;
    for (final row in rows) {
      final split = _splitAlignedRow(row);
      if (split == null) return null;
      relation ??= split.$2;
      if (split.$2 != relation) return null;
      values
        ..add(_normalizeCell(split.$1))
        ..add(_normalizeCell(split.$3));
    }

    final spec = MathDynamicStructureSpec(
      kind: MathDynamicStructureKind.alignedDerivation,
      rows: rows.length,
      relation: relation!,
    );
    if (!spec.isValid) return null;
    return MathDynamicStructureInstance(spec: spec, values: values);
  }

  List<String> _splitRows(String source) =>
      _splitTopLevel(source, rowMode: true);

  List<String> _splitCells(String source) =>
      _splitTopLevel(source, rowMode: false);

  List<String> _splitTopLevel(String source, {required bool rowMode}) {
    final result = <String>[];
    final buffer = StringBuffer();
    var braceDepth = 0;
    var index = 0;
    while (index < source.length) {
      final char = source[index];
      if (char == '\\' && index + 1 < source.length) {
        final next = source[index + 1];
        if (braceDepth == 0 && rowMode && next == '\\') {
          result.add(buffer.toString().trim());
          buffer.clear();
          index += 2;
          continue;
        }
        // Preserve commands and escaped separators atomically so `\&`,
        // `\{` and nested command text cannot be mistaken for layout syntax.
        buffer
          ..write(char)
          ..write(next);
        index += 2;
        continue;
      }
      if (char == '{') {
        braceDepth++;
        buffer.write(char);
        index++;
        continue;
      }
      if (char == '}') {
        if (braceDepth > 0) braceDepth--;
        buffer.write(char);
        index++;
        continue;
      }
      if (braceDepth == 0) {
        if (!rowMode && char == '&') {
          result.add(buffer.toString().trim());
          buffer.clear();
          index++;
          continue;
        }
      }
      buffer.write(char);
      index++;
    }
    result.add(buffer.toString().trim());
    return List<String>.unmodifiable(result);
  }

  bool _startsWithEquationRelation(String source) {
    const relations = <String>[
      r'\Rightarrow',
      r'\Leftrightarrow',
      r'\leq',
      r'\geq',
      r'\neq',
      r'\approx',
      r'\equiv',
      '=',
      '<',
      '>',
    ];
    return relations.any(source.startsWith);
  }

  (String, String, String)? _splitAlignedRow(String row) {
    var braceDepth = 0;
    for (var index = 0; index < row.length; index++) {
      final char = row[index];
      if (char == '\\' && index + 1 < row.length) {
        index++;
        continue;
      }
      if (char == '{') {
        braceDepth++;
        continue;
      }
      if (char == '}') {
        if (braceDepth > 0) braceDepth--;
        continue;
      }
      if (braceDepth != 0 || char != '&') continue;

      final right = row.substring(index + 1).trimLeft();
      const relations = <String>[r'\Rightarrow', r'\leq', r'\geq', '='];
      for (final candidate in relations) {
        if (!right.startsWith(candidate)) continue;
        return (
          row.substring(0, index).trim(),
          candidate,
          right.substring(candidate.length).trim(),
        );
      }
      return null;
    }
    return null;
  }

  String _normalizeCell(String source) {
    final trimmed = source.trim();
    final unwrapped = _stripOneOuterGroup(trimmed);
    return unwrapped == r'\Box' ? '' : unwrapped;
  }

  String _stripOneOuterGroup(String source) {
    if (source.length < 2 || !source.startsWith('{') || !source.endsWith('}')) {
      return source;
    }
    var depth = 0;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if (char == '\\' && index + 1 < source.length) {
        index++;
        continue;
      }
      if (char == '{') depth++;
      if (char == '}') depth--;
      if (depth == 0 && index != source.length - 1) return source;
      if (depth < 0) return source;
    }
    return depth == 0 ? source.substring(1, source.length - 1) : source;
  }
}
