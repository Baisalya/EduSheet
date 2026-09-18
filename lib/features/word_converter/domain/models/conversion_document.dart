class ConversionDocument {
  const ConversionDocument({required this.sections});

  final List<ConversionSection> sections;

  bool get hasContent => sections.any(
    (section) =>
        section.blocks.isNotEmpty ||
        section.headerBlocks.isNotEmpty ||
        section.footerBlocks.isNotEmpty,
  );
}

class ConversionSection {
  const ConversionSection({
    required this.page,
    required this.blocks,
    this.headerBlocks = const [],
    this.footerBlocks = const [],
  });

  final ConversionPageSettings page;
  final List<ConversionBlock> blocks;
  final List<ConversionBlock> headerBlocks;
  final List<ConversionBlock> footerBlocks;
}

class ConversionPageSettings {
  const ConversionPageSettings({
    this.widthPoints = 595.3,
    this.heightPoints = 841.9,
    this.marginTopPoints = 72,
    this.marginRightPoints = 72,
    this.marginBottomPoints = 72,
    this.marginLeftPoints = 72,
    this.headerDistancePoints = 36,
    this.footerDistancePoints = 36,
  });

  final double widthPoints;
  final double heightPoints;
  final double marginTopPoints;
  final double marginRightPoints;
  final double marginBottomPoints;
  final double marginLeftPoints;
  final double headerDistancePoints;
  final double footerDistancePoints;
}

sealed class ConversionBlock {
  const ConversionBlock();
}

class ConversionParagraph extends ConversionBlock {
  const ConversionParagraph({
    required this.inlines,
    this.alignment = ConversionTextAlignment.left,
    this.spaceBeforePoints = 0,
    this.spaceAfterPoints = 6,
    this.leftIndentPoints = 0,
    this.rightIndentPoints = 0,
    this.firstLineIndentPoints = 0,
    this.pageBreakBefore = false,
    this.keepWithNext = false,
    this.listLabel,
  });

  final List<ConversionInline> inlines;
  final ConversionTextAlignment alignment;
  final double spaceBeforePoints;
  final double spaceAfterPoints;
  final double leftIndentPoints;
  final double rightIndentPoints;
  final double firstLineIndentPoints;
  final bool pageBreakBefore;
  final bool keepWithNext;
  final String? listLabel;

  bool get hasVisibleContent =>
      (listLabel?.isNotEmpty ?? false) || inlines.any((inline) => inline.isVisible);
}

class ConversionTable extends ConversionBlock {
  const ConversionTable({
    required this.rows,
    this.showBorders = false,
  });

  final List<ConversionTableRow> rows;
  final bool showBorders;
}

class ConversionTableRow {
  const ConversionTableRow({required this.cells, this.isHeader = false});

  final List<ConversionTableCell> cells;
  final bool isHeader;
}

class ConversionTableCell {
  const ConversionTableCell({
    required this.blocks,
    this.shadingHex,
    this.widthPoints,
  });

  final List<ConversionBlock> blocks;
  final String? shadingHex;
  final double? widthPoints;
}

sealed class ConversionInline {
  const ConversionInline();

  bool get isVisible;
}

class ConversionTextRun extends ConversionInline {
  const ConversionTextRun({
    required this.text,
    this.style = const ConversionTextStyle(),
    this.hyperlink,
  });

  final String text;
  final ConversionTextStyle style;
  final String? hyperlink;

  @override
  bool get isVisible => text.isNotEmpty;
}


class ConversionDynamicFieldRun extends ConversionInline {
  const ConversionDynamicFieldRun({
    required this.field,
    this.style = const ConversionTextStyle(),
  });

  final ConversionDynamicField field;
  final ConversionTextStyle style;

  @override
  bool get isVisible => true;
}

enum ConversionDynamicField { pageNumber, pageCount }

class ConversionImageRun extends ConversionInline {
  const ConversionImageRun({
    required this.bytes,
    required this.widthPoints,
    required this.heightPoints,
    this.altText,
    this.hyperlink,
  });

  final List<int> bytes;
  final double widthPoints;
  final double heightPoints;
  final String? altText;
  final String? hyperlink;

  @override
  bool get isVisible => bytes.isNotEmpty;
}

class ConversionTextStyle {
  const ConversionTextStyle({
    this.fontFamily,
    this.fontSizePoints = 11,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.colorHex,
    this.highlightHex,
  });

  final String? fontFamily;
  final double fontSizePoints;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final String? colorHex;
  final String? highlightHex;

  ConversionTextStyle copyWith({
    String? fontFamily,
    double? fontSizePoints,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    String? colorHex,
    String? highlightHex,
  }) {
    return ConversionTextStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSizePoints: fontSizePoints ?? this.fontSizePoints,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strike: strike ?? this.strike,
      colorHex: colorHex ?? this.colorHex,
      highlightHex: highlightHex ?? this.highlightHex,
    );
  }
}

enum ConversionTextAlignment { left, center, right, justify }
