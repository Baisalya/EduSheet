class SpreadsheetWorkbook {
  final List<SpreadsheetSheet> sheets;
  final bool truncated;

  const SpreadsheetWorkbook({required this.sheets, this.truncated = false});

  bool get isEmpty => sheets.every((sheet) => sheet.rows.isEmpty);
}

class SpreadsheetSheet {
  final String name;
  final List<SpreadsheetRow> rows;
  final int columnCount;

  const SpreadsheetSheet({
    required this.name,
    required this.rows,
    required this.columnCount,
  });

  int get rowCount => rows.isEmpty ? 0 : rows.last.rowIndex;
}

class SpreadsheetRow {
  final int rowIndex;
  final Map<int, String> cells;

  const SpreadsheetRow({required this.rowIndex, required this.cells});

  String valueAt(int columnIndex) => cells[columnIndex] ?? '';
}
