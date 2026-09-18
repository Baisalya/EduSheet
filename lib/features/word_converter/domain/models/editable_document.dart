import 'dart:ui';

class EditableDocument {
  const EditableDocument({required this.pages});

  final List<EditablePage> pages;

  bool get hasContent => pages.any((page) => page.blocks.isNotEmpty);
}

class EditablePage {
  const EditablePage({
    required this.pageIndex,
    required this.size,
    required this.blocks,
    this.margins = const EditablePageMargins(),
  });

  final int pageIndex;
  final Size size;
  final List<EditableBlock> blocks;
  final EditablePageMargins margins;
}

class EditablePageMargins {
  const EditablePageMargins({
    this.leftPoints = 36,
    this.topPoints = 36,
    this.rightPoints = 36,
    this.bottomPoints = 36,
  });

  final double leftPoints;
  final double topPoints;
  final double rightPoints;
  final double bottomPoints;
}

sealed class EditableBlock {
  const EditableBlock();
}

class EditableParagraphBlock extends EditableBlock {
  const EditableParagraphBlock({
    required this.runs,
    this.kind = EditableParagraphKind.body,
    this.alignment = EditableParagraphAlignment.left,
    this.leftIndentPoints = 0,
    this.spaceBeforePoints = 0,
    this.spaceAfterPoints = 6,
  });

  final List<EditableTextRun> runs;
  final EditableParagraphKind kind;
  final EditableParagraphAlignment alignment;
  final double leftIndentPoints;
  final double spaceBeforePoints;
  final double spaceAfterPoints;

  String get plainText => runs.map((run) => run.text).join();
}

enum EditableParagraphKind { body, heading1, heading2, listItem }

enum EditableParagraphAlignment { left, center, right, justify }

class EditableTableBlock extends EditableBlock {
  const EditableTableBlock({
    required this.rows,
    required this.columnWidthsPoints,
  });

  final List<EditableTableRow> rows;
  final List<double> columnWidthsPoints;
}

class EditableTableRow {
  const EditableTableRow({required this.cells});

  final List<EditableTableCell> cells;
}

class EditableTableCell {
  const EditableTableCell({required this.paragraphs});

  final List<EditableParagraphBlock> paragraphs;
}

class EditableTextRun {
  const EditableTextRun({
    required this.text,
    this.style = const EditableTextStyle(),
  });

  final String text;
  final EditableTextStyle style;
}

class EditableTextStyle {
  const EditableTextStyle({
    this.fontFamily,
    this.fontSizePoints = 11,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
  });

  final String? fontFamily;
  final double fontSizePoints;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;

  EditableTextStyle copyWith({
    String? fontFamily,
    double? fontSizePoints,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
  }) {
    return EditableTextStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSizePoints: fontSizePoints ?? this.fontSizePoints,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strike: strike ?? this.strike,
    );
  }
}
