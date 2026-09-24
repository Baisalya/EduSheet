import 'dart:convert';

import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_interop_embed_builders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Safe mutations for structured DOCX compatibility objects in Smart Editor.
///
/// Imported Word tables stay structured: editing cell text does not flatten
/// images, nested tables, merged-cell metadata, or Word layout geometry.
class SmartEditorDocxStructureEditing {
  const SmartEditorDocxStructureEditing._();

  static SmartEditorInteropTablePayload updateCellText(
    SmartEditorInteropTablePayload table,
    int rowIndex,
    int cellIndex,
    String text,
  ) {
    if (rowIndex < 0 || rowIndex >= table.rows.length) return table;
    final row = table.rows[rowIndex];
    if (cellIndex < 0 || cellIndex >= row.cells.length) return table;

    final rows = List<SmartEditorInteropTableRow>.from(table.rows);
    final cells = List<SmartEditorInteropTableCell>.from(row.cells);
    cells[cellIndex] = _cellWithText(cells[cellIndex], text);
    rows[rowIndex] = _rowWithCells(row, cells);
    return _tableWithRows(table, rows);
  }

  static SmartEditorInteropTablePayload addRow(
    SmartEditorInteropTablePayload table,
  ) {
    final columnCount = _visualColumnCount(table);
    if (columnCount <= 0) return table;
    final cells = <SmartEditorInteropTableCell>[
      for (var i = 0; i < columnCount; i++)
        const SmartEditorInteropTableCell(
          text: '',
          blocks: <SmartEditorInteropCellBlock>[
            SmartEditorInteropCellBlock.paragraph(
              runs: <SmartEditorInteropTextRun>[],
            ),
          ],
        ),
    ];
    return _tableWithRows(
      table,
      <SmartEditorInteropTableRow>[
        ...table.rows,
        SmartEditorInteropTableRow(cells: cells),
      ],
    );
  }

  static SmartEditorInteropTablePayload removeRow(
    SmartEditorInteropTablePayload table,
    int rowIndex,
  ) {
    if (table.rows.length <= 1 ||
        rowIndex < 0 ||
        rowIndex >= table.rows.length) {
      return table;
    }
    final rows = List<SmartEditorInteropTableRow>.from(table.rows)
      ..removeAt(rowIndex);
    return _tableWithRows(table, rows);
  }

  static SmartEditorInteropTablePayload addColumn(
    SmartEditorInteropTablePayload table,
  ) {
    if (hasMergedStructure(table)) return table;
    final rows = <SmartEditorInteropTableRow>[];
    for (final row in table.rows) {
      rows.add(
        _rowWithCells(
          row,
          <SmartEditorInteropTableCell>[
            ...row.cells,
            const SmartEditorInteropTableCell(
              text: '',
              blocks: <SmartEditorInteropCellBlock>[
                SmartEditorInteropCellBlock.paragraph(
                  runs: <SmartEditorInteropTextRun>[],
                ),
              ],
            ),
          ],
        ),
      );
    }
    final grid = <double>[...table.gridColumnWidths];
    if (grid.isNotEmpty) {
      final average = grid.reduce((a, b) => a + b) / grid.length;
      grid.add(average <= 0 ? 72.0 : average);
    }
    return _copyTable(table, rows: rows, gridColumnWidths: grid);
  }

  static SmartEditorInteropTablePayload removeColumn(
    SmartEditorInteropTablePayload table,
    int columnIndex,
  ) {
    if (hasMergedStructure(table)) return table;
    final maxColumns = table.rows.fold<int>(
      0,
      (value, row) => row.cells.length > value ? row.cells.length : value,
    );
    if (maxColumns <= 1 || columnIndex < 0 || columnIndex >= maxColumns) {
      return table;
    }
    final rows = <SmartEditorInteropTableRow>[];
    for (final row in table.rows) {
      if (columnIndex >= row.cells.length) {
        rows.add(row);
        continue;
      }
      final cells = List<SmartEditorInteropTableCell>.from(row.cells)
        ..removeAt(columnIndex);
      rows.add(_rowWithCells(row, cells));
    }
    final grid = <double>[...table.gridColumnWidths];
    if (columnIndex < grid.length) grid.removeAt(columnIndex);
    return _copyTable(table, rows: rows, gridColumnWidths: grid);
  }

  static SmartEditorInteropTablePayload withPresentation(
    SmartEditorInteropTablePayload table, {
    bool? showBorders,
    String? alignment,
  }) {
    return _copyTable(
      table,
      showBorders: showBorders,
      alignment: alignment,
    );
  }

  static SmartEditorInteropImagePayload resizeImage(
    SmartEditorInteropImagePayload image, {
    required double widthPoints,
    required double heightPoints,
    String? altText,
  }) {
    return SmartEditorInteropImagePayload(
      bytes: image.bytes,
      objectId: image.objectId,
      widthPoints: widthPoints.clamp(24.0, 1200.0).toDouble(),
      heightPoints: heightPoints.clamp(18.0, 1200.0).toDouble(),
      altText: altText,
      hyperlink: image.hyperlink,
      placement: image.placement,
      cropLeft: image.cropLeft,
      cropTop: image.cropTop,
      cropRight: image.cropRight,
      cropBottom: image.cropBottom,
      rotationDegrees: image.rotationDegrees,
      flipHorizontal: image.flipHorizontal,
      flipVertical: image.flipVertical,
    );
  }

  /// Replace one imported custom embed by its persistent DF3 object id.
  static bool replaceEmbedByObjectId(
    QuillController controller, {
    required String keyName,
    required String objectId,
    required String encodedPayload,
  }) {
    if (objectId.trim().isEmpty) return false;
    final operations = controller.document.toDelta().toJson();
    var offset = 0;
    for (final rawOperation in operations) {
      final operation = Map<String, dynamic>.from(rawOperation);
      final insert = operation['insert'];
      if (insert is String) {
        offset += insert.length;
        continue;
      }
      final embed = _embedMap(insert);
      if (embed != null && embed.containsKey(keyName)) {
        if (_objectId(embed[keyName]) == objectId) {
          controller.replaceText(
            offset,
            1,
            BlockEmbed.custom(CustomBlockEmbed(keyName, encodedPayload)),
            null,
          );
          controller.updateSelection(
            TextSelection.collapsed(
              offset: (offset + 1)
                  .clamp(0, controller.document.length - 1)
                  .toInt(),
            ),
            ChangeSource.local,
          );
          return true;
        }
      }
      offset += 1;
    }
    return false;
  }

  static bool hasMergedStructure(SmartEditorInteropTablePayload table) {
    for (final row in table.rows) {
      for (final cell in row.cells) {
        if (cell.gridSpan != 1 || cell.verticalMerge != 'none') return true;
      }
    }
    return false;
  }

  static SmartEditorInteropTableCell _cellWithText(
    SmartEditorInteropTableCell cell,
    String text,
  ) {
    SmartEditorInteropCellBlock? firstParagraph;
    for (final block in cell.blocks) {
      if (block.kind == 'paragraph') {
        firstParagraph = block;
        break;
      }
    }
    final firstRun = firstParagraph == null || firstParagraph.runs.isEmpty
        ? null
        : firstParagraph.runs.first;
    final paragraph = SmartEditorInteropCellBlock.paragraph(
      runs: text.isEmpty
          ? const <SmartEditorInteropTextRun>[]
          : <SmartEditorInteropTextRun>[
              SmartEditorInteropTextRun(
                text: text,
                bold: firstRun?.bold ?? false,
                italic: firstRun?.italic ?? false,
                underline: firstRun?.underline ?? false,
                strike: firstRun?.strike ?? false,
                fontFamily: firstRun?.fontFamily,
                fontSizePoints: firstRun?.fontSizePoints,
                colorHex: firstRun?.colorHex,
                backgroundHex: firstRun?.backgroundHex,
                hyperlink: firstRun?.hyperlink,
              ),
            ],
      alignment: firstParagraph?.alignment ?? 'left',
      spaceBeforePoints: firstParagraph?.spaceBeforePoints ?? 0,
      spaceAfterPoints: firstParagraph?.spaceAfterPoints ?? 0,
      lineSpacingMultiple: firstParagraph?.lineSpacingMultiple,
      exactLineSpacingPoints: firstParagraph?.exactLineSpacingPoints,
    );

    final blocks = <SmartEditorInteropCellBlock>[];
    var paragraphInserted = false;
    for (final block in cell.blocks) {
      if (block.kind == 'paragraph') {
        if (!paragraphInserted) {
          blocks.add(paragraph);
          paragraphInserted = true;
        }
      } else {
        blocks.add(block);
      }
    }
    if (!paragraphInserted) blocks.insert(0, paragraph);

    return SmartEditorInteropTableCell(
      text: text,
      shadingHex: cell.shadingHex,
      borders: cell.borders,
      widthPoints: cell.widthPoints,
      widthPercent: cell.widthPercent,
      gridSpan: cell.gridSpan,
      paddingTopPoints: cell.paddingTopPoints,
      paddingRightPoints: cell.paddingRightPoints,
      paddingBottomPoints: cell.paddingBottomPoints,
      paddingLeftPoints: cell.paddingLeftPoints,
      verticalAlignment: cell.verticalAlignment,
      verticalMerge: cell.verticalMerge,
      noWrap: cell.noWrap,
      blocks: List<SmartEditorInteropCellBlock>.unmodifiable(blocks),
    );
  }

  static SmartEditorInteropTableRow _rowWithCells(
    SmartEditorInteropTableRow row,
    List<SmartEditorInteropTableCell> cells,
  ) {
    return SmartEditorInteropTableRow(
      cells: cells,
      header: row.header,
      cantSplit: row.cantSplit,
      heightPoints: row.heightPoints,
      heightRule: row.heightRule,
    );
  }

  static SmartEditorInteropTablePayload _tableWithRows(
    SmartEditorInteropTablePayload table,
    List<SmartEditorInteropTableRow> rows,
  ) => _copyTable(table, rows: rows);

  static SmartEditorInteropTablePayload _copyTable(
    SmartEditorInteropTablePayload table, {
    List<SmartEditorInteropTableRow>? rows,
    bool? showBorders,
    List<double>? gridColumnWidths,
    String? alignment,
  }) {
    return SmartEditorInteropTablePayload(
      rows: rows ?? table.rows,
      showBorders: showBorders ?? table.showBorders,
      styleId: table.styleId,
      shadingHex: table.shadingHex,
      borders: table.borders,
      layout: table.layout,
      objectId: table.objectId,
      sourceKind: table.sourceKind,
      widthPoints: table.widthPoints,
      heightPoints: table.heightPoints,
      widthPercent: table.widthPercent,
      indentPoints: table.indentPoints,
      cellSpacingPoints: table.cellSpacingPoints,
      gridColumnWidths: gridColumnWidths ?? table.gridColumnWidths,
      alignment: alignment ?? table.alignment,
      placement: table.placement,
    );
  }

  static int _visualColumnCount(SmartEditorInteropTablePayload table) {
    var result = table.gridColumnWidths.length;
    for (final row in table.rows) {
      var count = 0;
      for (final cell in row.cells) {
        count += cell.gridSpan;
      }
      if (count > result) result = count;
    }
    return result;
  }

  static Map<String, dynamic>? _embedMap(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final custom = map['custom'];
    if (custom is Map) return Map<String, dynamic>.from(custom);
    if (custom is String) {
      try {
        final decoded = jsonDecode(custom);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } on FormatException {
        return null;
      }
    }
    return map;
  }

  static String? _objectId(Object? data) {
    try {
      final raw = data is String ? jsonDecode(data) : data;
      if (raw is! Map) return null;
      final value = raw['objectId']?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }
}
