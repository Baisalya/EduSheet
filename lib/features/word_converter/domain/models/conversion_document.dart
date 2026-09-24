class ConversionDocument {
  const ConversionDocument({
    required this.sections,
    this.evenAndOddHeaders = false,
    this.mirrorMargins = false,
    this.gutterAtTop = false,
    this.backgroundColorHex,
  });

  final List<ConversionSection> sections;

  /// Document-level Word settings that change page/story selection semantics.
  final bool evenAndOddHeaders;
  final bool mirrorMargins;
  final bool gutterAtTop;

  /// Word document background (`w:background`). Kept separate from page styles
  /// because OOXML stores it at document scope and it applies across sections.
  final String? backgroundColorHex;

  bool get hasContent => sections.any(
    (section) =>
        section.blocks.isNotEmpty ||
        section.headerBlocks.isNotEmpty ||
        section.footerBlocks.isNotEmpty ||
        section.firstPageHeaderBlocks.isNotEmpty ||
        section.firstPageFooterBlocks.isNotEmpty ||
        section.evenPageHeaderBlocks.isNotEmpty ||
        section.evenPageFooterBlocks.isNotEmpty,
  );
}

enum ConversionSectionBreakType { nextPage, continuous, evenPage, oddPage, nextColumn }

class ConversionSection {
  const ConversionSection({
    required this.page,
    required this.blocks,
    this.headerBlocks = const [],
    this.footerBlocks = const [],
    this.firstPageHeaderBlocks = const [],
    this.firstPageFooterBlocks = const [],
    this.evenPageHeaderBlocks = const [],
    this.evenPageFooterBlocks = const [],
    this.breakType = ConversionSectionBreakType.nextPage,
    this.titlePage = false,
    this.columns = const ConversionColumns(),
    this.pageNumberStart,
    this.pageNumberFormat,
  });

  final ConversionPageSettings page;
  final List<ConversionBlock> blocks;

  /// Resolved Word header/footer stories. `headerBlocks` / `footerBlocks` are
  /// the default (odd-page) stories retained for backwards compatibility.
  final List<ConversionBlock> headerBlocks;
  final List<ConversionBlock> footerBlocks;
  final List<ConversionBlock> firstPageHeaderBlocks;
  final List<ConversionBlock> firstPageFooterBlocks;
  final List<ConversionBlock> evenPageHeaderBlocks;
  final List<ConversionBlock> evenPageFooterBlocks;

  /// Section-start semantics from `w:sectPr/w:type`.
  final ConversionSectionBreakType breakType;
  final bool titlePage;
  final ConversionColumns columns;
  final int? pageNumberStart;
  final String? pageNumberFormat;

  List<ConversionBlock> headerForPage({
    required int pageIndexInSection,
    required bool evenAndOddHeaders,
  }) {
    if (pageIndexInSection == 0 && titlePage) {
      return firstPageHeaderBlocks;
    }
    // Word counts odd/even story pages from one inside each section,
    // independently from physical/document page numbering and pgNumType.
    if (evenAndOddHeaders &&
        (pageIndexInSection + 1).isEven &&
        evenPageHeaderBlocks.isNotEmpty) {
      return evenPageHeaderBlocks;
    }
    return headerBlocks;
  }

  List<ConversionBlock> footerForPage({
    required int pageIndexInSection,
    required bool evenAndOddHeaders,
  }) {
    if (pageIndexInSection == 0 && titlePage) {
      return firstPageFooterBlocks;
    }
    if (evenAndOddHeaders &&
        (pageIndexInSection + 1).isEven &&
        evenPageFooterBlocks.isNotEmpty) {
      return evenPageFooterBlocks;
    }
    return footerBlocks;
  }
}

class ConversionColumnSpec {
  const ConversionColumnSpec({this.widthPoints, this.spacingPoints});

  final double? widthPoints;
  final double? spacingPoints;
}

class ConversionColumns {
  const ConversionColumns({
    this.count = 1,
    this.equalWidth = true,
    this.spacingPoints = 36,
    this.separator = false,
    this.columns = const <ConversionColumnSpec>[],
  });

  final int count;
  final bool equalWidth;
  final double spacingPoints;
  final bool separator;
  final List<ConversionColumnSpec> columns;

  bool get isMultiColumn => count > 1 || columns.length > 1;
}

class ConversionPageBorders {
  const ConversionPageBorders({
    this.borders = const ConversionBorders(),
    this.offsetFrom = 'text',
    this.display = 'allPages',
    this.zOrder = 'front',
  });

  final ConversionBorders borders;
  final String offsetFrom;
  final String display;
  final String zOrder;

  bool get isEmpty => borders.isEmpty;
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
    this.gutterPoints = 0,
    this.pageBorders = const ConversionPageBorders(),
  });

  final double widthPoints;
  final double heightPoints;
  final double marginTopPoints;
  final double marginRightPoints;
  final double marginBottomPoints;
  final double marginLeftPoints;
  final double headerDistancePoints;
  final double footerDistancePoints;
  final double gutterPoints;
  final ConversionPageBorders pageBorders;
}

sealed class ConversionBlock {
  const ConversionBlock();
}

class ConversionParagraph extends ConversionBlock {
  const ConversionParagraph({
    required this.inlines,
    this.styleId,
    this.alignment = ConversionTextAlignment.left,
    this.spaceBeforePoints = 0,
    this.spaceAfterPoints = 6,
    this.leftIndentPoints = 0,
    this.rightIndentPoints = 0,
    this.firstLineIndentPoints = 0,
    this.lineSpacingMultiple,
    this.exactLineSpacingPoints,
    this.pageBreakBefore = false,
    this.columnBreakBefore = false,
    this.keepWithNext = false,
    this.keepLines = false,
    this.widowControl = true,
    this.contextualSpacing = false,
    this.tabStops = const <ConversionTabStop>[],
    this.shadingHex,
    this.borders = const ConversionBorders(),
    this.listLabel,
    this.listLabelStyle,
  });

  final List<ConversionInline> inlines;

  /// Effective Word paragraph style ID. Retained so contextual spacing and
  /// non-destructive round-trip layers can distinguish adjacent style groups.
  final String? styleId;
  final ConversionTextAlignment alignment;
  final double spaceBeforePoints;
  final double spaceAfterPoints;
  final double leftIndentPoints;
  final double rightIndentPoints;
  final double firstLineIndentPoints;

  /// Word stores automatic line spacing as 240 units per single line.
  /// A value of 1.0 means single spacing, 1.5 means one-and-a-half, etc.
  final double? lineSpacingMultiple;

  /// Exact/at-least Word line spacing, represented in points.
  final double? exactLineSpacingPoints;
  final bool pageBreakBefore;
  final bool columnBreakBefore;
  final bool keepWithNext;

  /// `w:keepLines` / `w:widowControl` / `w:contextualSpacing` are retained in
  /// the canonical model even when pagination is delegated to the viewer.
  final bool keepLines;
  final bool widowControl;
  final bool contextualSpacing;

  /// Effective tab stops after Word style inheritance and direct overrides.
  final List<ConversionTabStop> tabStops;

  /// Paragraph background shading (`w:pPr/w:shd`). This is separate from run
  /// highlighting and table-cell shading in Word's visual model.
  final String? shadingHex;

  /// Paragraph borders (`w:pBdr`), including separator rules used heavily by
  /// resumes, forms and school documents.
  final ConversionBorders borders;

  /// Rendered numbering/bullet marker. The marker style is independent from the
  /// paragraph body because Word numbering levels can specify their own font.
  final String? listLabel;
  final ConversionTextStyle? listLabelStyle;

  bool get hasVisibleContent =>
      (listLabel?.isNotEmpty ?? false) || inlines.any((inline) => inline.isVisible);

  bool get hasAdvancedLayout =>
      tabStops.isNotEmpty ||
      shadingHex != null ||
      !borders.isEmpty ||
      keepLines ||
      keepWithNext ||
      pageBreakBefore;
}

enum ConversionTabAlignment { left, center, right, decimal, bar, clear }

enum ConversionTabLeader { none, dot, hyphen, underscore, heavy, middleDot }

class ConversionTabStop {
  const ConversionTabStop({
    required this.positionPoints,
    this.alignment = ConversionTabAlignment.left,
    this.leader = ConversionTabLeader.none,
  });

  final double positionPoints;
  final ConversionTabAlignment alignment;
  final ConversionTabLeader leader;
}

enum ConversionBorderStyle {
  none,
  single,
  doubleLine,
  dotted,
  dashed,
  dashDot,
  dashDotDot,
  thick,
  wave,
}

class ConversionBorderSide {
  const ConversionBorderSide({
    this.style = ConversionBorderStyle.none,
    this.widthPoints = 0,
    this.colorHex,
    this.spacePoints = 0,
  });

  final ConversionBorderStyle style;
  final double widthPoints;
  final String? colorHex;
  final double spacePoints;

  bool get isVisible => style != ConversionBorderStyle.none && widthPoints > 0;
}

class ConversionBorders {
  const ConversionBorders({
    this.top,
    this.right,
    this.bottom,
    this.left,
    this.insideHorizontal,
    this.insideVertical,
    this.between,
    this.bar,
  });

  final ConversionBorderSide? top;
  final ConversionBorderSide? right;
  final ConversionBorderSide? bottom;
  final ConversionBorderSide? left;
  final ConversionBorderSide? insideHorizontal;
  final ConversionBorderSide? insideVertical;
  final ConversionBorderSide? between;
  final ConversionBorderSide? bar;

  bool get isEmpty =>
      !(top?.isVisible ?? false) &&
      !(right?.isVisible ?? false) &&
      !(bottom?.isVisible ?? false) &&
      !(left?.isVisible ?? false) &&
      !(insideHorizontal?.isVisible ?? false) &&
      !(insideVertical?.isVisible ?? false) &&
      !(between?.isVisible ?? false) &&
      !(bar?.isVisible ?? false);

  ConversionBorders merge(ConversionBorders other) {
    return ConversionBorders(
      top: other.top ?? top,
      right: other.right ?? right,
      bottom: other.bottom ?? bottom,
      left: other.left ?? left,
      insideHorizontal: other.insideHorizontal ?? insideHorizontal,
      insideVertical: other.insideVertical ?? insideVertical,
      between: other.between ?? between,
      bar: other.bar ?? bar,
    );
  }
}


/// OOXML block that EduSheet cannot safely edit yet, but must not destroy.
///
/// `rawXml` is the exact source element. `fallbackBlocks` are a best-effort
/// readable projection used by the viewer while the raw payload remains the
/// authoritative round-trip representation.
class ConversionOpaqueOoxmlBlock extends ConversionBlock {
  const ConversionOpaqueOoxmlBlock({
    required this.featureKind,
    required this.rawXml,
    this.fallbackBlocks = const <ConversionBlock>[],
    this.relationshipIds = const <String>[],
  });

  final String featureKind;
  final String rawXml;
  final List<ConversionBlock> fallbackBlocks;
  final List<String> relationshipIds;
}

class ConversionTable extends ConversionBlock {
  const ConversionTable({
    required this.rows,
    this.showBorders = false,
    this.styleId,
    this.shadingHex,
    this.borders = const ConversionBorders(),
    this.layout = ConversionTableLayout.autoFit,
    this.widthPoints,
    this.widthPercent,
    this.indentPoints = 0,
    this.cellSpacingPoints = 0,
    this.gridColumnWidths = const <double>[],
    this.alignment = ConversionTextAlignment.left,
  });

  final List<ConversionTableRow> rows;
  final bool showBorders;
  final String? styleId;
  final String? shadingHex;
  final ConversionBorders borders;
  final ConversionTableLayout layout;
  final double? widthPoints;
  final double? widthPercent;
  final double indentPoints;
  final double cellSpacingPoints;
  final List<double> gridColumnWidths;
  final ConversionTextAlignment alignment;
}

enum ConversionTableLayout { autoFit, fixed }

class ConversionTableRow {
  const ConversionTableRow({
    required this.cells,
    this.isHeader = false,
    this.cantSplit = false,
    this.heightPoints,
    this.heightRule = ConversionTableRowHeightRule.auto,
  });

  final List<ConversionTableCell> cells;
  final bool isHeader;
  final bool cantSplit;
  final double? heightPoints;
  final ConversionTableRowHeightRule heightRule;
}

enum ConversionTableRowHeightRule { auto, atLeast, exact }

class ConversionTableCell {
  const ConversionTableCell({
    required this.blocks,
    this.shadingHex,
    this.borders = const ConversionBorders(),
    this.widthPoints,
    this.widthPercent,
    this.gridSpan = 1,
    this.paddingTopPoints = 4,
    this.paddingRightPoints = 4,
    this.paddingBottomPoints = 4,
    this.paddingLeftPoints = 4,
    this.verticalAlignment = ConversionTableCellVerticalAlignment.top,
    this.verticalMerge = ConversionVerticalMerge.none,
    this.noWrap = false,
  });

  final List<ConversionBlock> blocks;
  final String? shadingHex;
  final ConversionBorders borders;
  final double? widthPoints;
  final double? widthPercent;
  final int gridSpan;
  final double paddingTopPoints;
  final double paddingRightPoints;
  final double paddingBottomPoints;
  final double paddingLeftPoints;
  final ConversionTableCellVerticalAlignment verticalAlignment;
  final ConversionVerticalMerge verticalMerge;
  final bool noWrap;
}

enum ConversionTableCellVerticalAlignment { top, center, bottom }

enum ConversionVerticalMerge { none, restart, continuation }

sealed class ConversionInline {
  const ConversionInline();

  bool get isVisible;
}


/// Preserve-only inline OOXML capsule. Unsupported Word objects remain in the
/// canonical stream instead of being silently flattened or discarded.
class ConversionOpaqueOoxmlRun extends ConversionInline {
  const ConversionOpaqueOoxmlRun({
    required this.featureKind,
    required this.rawXml,
    this.fallbackText = '',
    this.relationshipIds = const <String>[],
    this.style = const ConversionTextStyle(),
  });

  final String featureKind;
  final String rawXml;
  final String fallbackText;
  final List<String> relationshipIds;
  final ConversionTextStyle style;

  @override
  bool get isVisible => fallbackText.isNotEmpty || rawXml.trim().isNotEmpty;
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

enum ConversionWordNoteType { footnote, endnote }

enum ConversionWordMarkerKind { start, end, reference }

/// A generic Word field that EduSheet does not reduce to a hard-coded token.
///
/// `instruction` is the canonical Word field instruction and `resultText` is
/// the last calculated display result stored by Word. This allows the viewer
/// to show something useful while Smart Editor/export retain the real field.
class ConversionFieldRun extends ConversionInline {
  const ConversionFieldRun({
    required this.instruction,
    required this.resultText,
    this.style = const ConversionTextStyle(),
    this.locked = false,
    this.dirty = false,
  });

  final String instruction;
  final String resultText;
  final ConversionTextStyle style;
  final bool locked;
  final bool dirty;

  String get fieldName {
    final normalized = instruction.trim();
    if (normalized.isEmpty) return '';
    return normalized.split(RegExp(r'\s+')).first.toUpperCase();
  }

  @override
  bool get isVisible => resultText.isNotEmpty || instruction.trim().isNotEmpty;
}

/// Native OMML retained as structured Word math instead of flattening it into
/// plain text. `plainText` is only a readable/rendering fallback.
class ConversionMathRun extends ConversionInline {
  const ConversionMathRun({
    required this.ommlXml,
    required this.plainText,
    this.display = false,
    this.style = const ConversionTextStyle(fontFamily: 'Cambria Math'),
  });

  final String ommlXml;
  final String plainText;
  final bool display;
  final ConversionTextStyle style;

  @override
  bool get isVisible => ommlXml.trim().isNotEmpty || plainText.isNotEmpty;
}

/// Footnote/endnote reference plus the resolved note story.
class ConversionNoteReferenceRun extends ConversionInline {
  const ConversionNoteReferenceRun({
    required this.type,
    required this.noteId,
    required this.blocks,
    this.displayLabel,
    this.style = const ConversionTextStyle(),
  });

  final ConversionWordNoteType type;
  final String noteId;
  final List<ConversionBlock> blocks;
  final String? displayLabel;
  final ConversionTextStyle style;

  @override
  bool get isVisible => true;
}

/// Bookmark boundary retained in document order. It is intentionally invisible
/// in the viewer but remains addressable for internal hyperlinks and round-trip.
class ConversionBookmarkMarkerRun extends ConversionInline {
  const ConversionBookmarkMarkerRun({
    required this.bookmarkId,
    required this.kind,
    this.name,
  });

  final String bookmarkId;
  final String? name;
  final ConversionWordMarkerKind kind;

  @override
  bool get isVisible => false;
}

class ConversionCommentInfo {
  const ConversionCommentInfo({
    required this.commentId,
    this.author,
    this.initials,
    this.dateIso,
    this.text = '',
    this.blocks = const <ConversionBlock>[],
  });

  final String commentId;
  final String? author;
  final String? initials;
  final String? dateIso;
  final String text;
  final List<ConversionBlock> blocks;
}

/// Comment range/reference marker kept in the same inline stream as Word.
class ConversionCommentMarkerRun extends ConversionInline {
  const ConversionCommentMarkerRun({
    required this.commentId,
    required this.kind,
    this.comment,
    this.style = const ConversionTextStyle(),
  });

  final String commentId;
  final ConversionWordMarkerKind kind;
  final ConversionCommentInfo? comment;
  final ConversionTextStyle style;

  @override
  bool get isVisible => kind == ConversionWordMarkerKind.reference;
}

class ConversionTextBoxRun extends ConversionInline {
  const ConversionTextBoxRun({
    required this.blocks,
    this.widthPoints,
    this.heightPoints,
    this.paddingTopPoints = 0,
    this.paddingRightPoints = 0,
    this.paddingBottomPoints = 0,
    this.paddingLeftPoints = 0,
    this.placement = const ConversionObjectPlacement.inline(),
  });

  final List<ConversionBlock> blocks;
  final double? widthPoints;
  final double? heightPoints;
  final double paddingTopPoints;
  final double paddingRightPoints;
  final double paddingBottomPoints;
  final double paddingLeftPoints;
  final ConversionObjectPlacement placement;

  @override
  bool get isVisible => blocks.isNotEmpty;
}

enum ConversionShapeKind {
  rectangle,
  roundedRectangle,
  ellipse,
  line,

  /// VML/WordArt text-path shape. Word commonly stores text watermarks this
  /// way inside a header story rather than as ordinary paragraph text.
  textPath,
  unknown,
}

class ConversionShapeStyle {
  const ConversionShapeStyle({
    this.fillColorHex,
    this.strokeColorHex,
    this.strokeWidthPoints = 1,
    this.dashStyle,
    this.rotationDegrees = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });

  final String? fillColorHex;
  final String? strokeColorHex;
  final double strokeWidthPoints;
  final String? dashStyle;
  final double rotationDegrees;
  final bool flipHorizontal;
  final bool flipVertical;
}

class ConversionShapeRun extends ConversionInline {
  const ConversionShapeRun({
    required this.kind,
    required this.widthPoints,
    required this.heightPoints,
    this.blocks = const <ConversionBlock>[],
    this.style = const ConversionShapeStyle(),
    this.placement = const ConversionObjectPlacement.inline(),
    this.altText,
  });

  final ConversionShapeKind kind;
  final double widthPoints;
  final double heightPoints;
  final List<ConversionBlock> blocks;
  final ConversionShapeStyle style;
  final ConversionObjectPlacement placement;
  final String? altText;

  @override
  bool get isVisible => widthPoints > 0 && heightPoints > 0;
}

class ConversionImageCrop {
  const ConversionImageCrop({
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  /// Normalized crop fractions in the inclusive range 0..1.
  ///
  /// Word DrawingML stores these as 1/100000 percentages in `a:srcRect`.
  final double left;
  final double top;
  final double right;
  final double bottom;

  bool get isEmpty =>
      left <= 0 && top <= 0 && right <= 0 && bottom <= 0;

  double get visibleWidth => (1 - left - right).clamp(0.001, 1.0).toDouble();
  double get visibleHeight => (1 - top - bottom).clamp(0.001, 1.0).toDouble();
}

class ConversionImageRun extends ConversionInline {
  const ConversionImageRun({
    required this.bytes,
    required this.widthPoints,
    required this.heightPoints,
    this.altText,
    this.hyperlink,
    this.placement = const ConversionObjectPlacement.inline(),
    this.crop = const ConversionImageCrop(),
    this.rotationDegrees = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.sourceRelationshipId,
    this.sourcePartPath,
  });

  final List<int> bytes;
  final double widthPoints;
  final double heightPoints;
  final String? altText;
  final String? hyperlink;
  final ConversionObjectPlacement placement;

  /// Word picture crop geometry. Retained independently from the image bytes so
  /// the viewer/editor can reproduce the same visible source region.
  final ConversionImageCrop crop;

  /// DrawingML rotation in degrees. Word stores 1/60000 degree units.
  final double rotationDegrees;
  final bool flipHorizontal;
  final bool flipVertical;

  /// Original OOXML relationship provenance. These are preservation metadata;
  /// exporters may create new relationship ids while keeping the same media.
  final String? sourceRelationshipId;
  final String? sourcePartPath;

  @override
  bool get isVisible => bytes.isNotEmpty;
}

/// Positioning metadata for DrawingML/VML objects.
///
/// DF2 deliberately keeps the raw Word relative-origin strings because Word
/// supports many origins (`page`, `margin`, `column`, `paragraph`, etc.). The
/// fidelity renderer handles the page/margin variants exactly and degrades
/// paragraph/character-relative objects to inline placement rather than losing
/// them.
class ConversionObjectPlacement {
  const ConversionObjectPlacement.inline()
      : floating = false,
        horizontalRelativeFrom = null,
        verticalRelativeFrom = null,
        horizontalOffsetPoints = null,
        verticalOffsetPoints = null,
        horizontalAlignment = null,
        verticalAlignment = null,
        behindText = false,
        allowOverlap = true,
        wrapStyle = null,
        wrapText = null,
        distanceTopPoints = 0,
        distanceBottomPoints = 0,
        distanceLeftPoints = 0,
        distanceRightPoints = 0,
        relativeHeight = 0,
        layoutInCell = true,
        locked = false;

  const ConversionObjectPlacement.floating({
    this.horizontalRelativeFrom,
    this.verticalRelativeFrom,
    this.horizontalOffsetPoints,
    this.verticalOffsetPoints,
    this.horizontalAlignment,
    this.verticalAlignment,
    this.behindText = false,
    this.allowOverlap = true,
    this.wrapStyle,
    this.wrapText,
    this.distanceTopPoints = 0,
    this.distanceBottomPoints = 0,
    this.distanceLeftPoints = 0,
    this.distanceRightPoints = 0,
    this.relativeHeight = 0,
    this.layoutInCell = true,
    this.locked = false,
  }) : floating = true;

  final bool floating;
  final String? horizontalRelativeFrom;
  final String? verticalRelativeFrom;
  final double? horizontalOffsetPoints;
  final double? verticalOffsetPoints;
  final String? horizontalAlignment;
  final String? verticalAlignment;
  final bool behindText;
  final bool allowOverlap;

  /// Raw Word wrap element local name (`wrapSquare`, `wrapTight`, ...).
  final String? wrapStyle;
  final String? wrapText;
  final double distanceTopPoints;
  final double distanceBottomPoints;
  final double distanceLeftPoints;
  final double distanceRightPoints;

  /// DrawingML relativeHeight is Word's stable z-order key.
  final int relativeHeight;
  final bool layoutInCell;
  final bool locked;

  bool get isPagePositioned {
    if (!floating) return false;
    final horizontal = horizontalRelativeFrom?.toLowerCase();
    final vertical = verticalRelativeFrom?.toLowerCase();
    const pageHorizontal = {
      'page',
      'margin',
      'column',
      'leftmargin',
      'rightmargin',
      'insidemargin',
      'outsidemargin',
    };
    const pageVertical = {
      'page',
      'margin',
      'topmargin',
      'bottommargin',
      'insidemargin',
      'outsidemargin',
    };
    return pageHorizontal.contains(horizontal) && pageVertical.contains(vertical);
  }

  /// Whether the fidelity viewer can render this Word floating object on the
  /// page layer without degrading it to inline flow.
  ///
  /// WM5 originally limited the page layer to page/margin origins. Real Word
  /// documents also anchor drawings to the paragraph/line/character that owns
  /// the `wp:anchor`. The viewer keeps those anchors in page coordinates by
  /// combining the flow paragraph's measured Y offset with the OOXML offset.
  bool get isViewerPositioned {
    if (!floating) return false;
    final horizontal = horizontalRelativeFrom?.toLowerCase();
    final vertical = verticalRelativeFrom?.toLowerCase();
    const supportedHorizontal = {
      'page',
      'margin',
      'column',
      'character',
      'paragraph',
      'leftmargin',
      'rightmargin',
      'insidemargin',
      'outsidemargin',
    };
    const supportedVertical = {
      'page',
      'margin',
      'paragraph',
      'line',
      'character',
      'topmargin',
      'bottommargin',
      'insidemargin',
      'outsidemargin',
    };
    return supportedHorizontal.contains(horizontal) &&
        supportedVertical.contains(vertical);
  }

  /// Word wrap modes that reserve body-flow space around an anchored object.
  bool get affectsTextFlow {
    if (!isViewerPositioned || behindText) return false;
    final wrap = wrapStyle?.toLowerCase();
    return wrap == 'wrapsquare' ||
        wrap == 'wraptight' ||
        wrap == 'wrapthrough' ||
        wrap == 'wraptopandbottom';
  }
}

enum ConversionUnderlineStyle {
  none,
  single,
  doubleLine,
  dotted,
  dashed,
  wavy,
}

class ConversionTextStyle {
  const ConversionTextStyle({
    this.fontFamily,
    this.fontSizePoints = 11,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.underlineStyle = ConversionUnderlineStyle.none,
    this.strike = false,
    this.doubleStrike = false,
    this.allCaps = false,
    this.smallCaps = false,
    this.letterSpacingPoints = 0,
    this.colorHex,
    this.highlightHex,
  });

  final String? fontFamily;
  final double fontSizePoints;
  final bool bold;
  final bool italic;
  final bool underline;
  final ConversionUnderlineStyle underlineStyle;
  final bool strike;
  final bool doubleStrike;

  /// Word run case effects (`w:caps` / `w:smallCaps`). The canonical text is
  /// preserved; renderers decide how to display it.
  final bool allCaps;
  final bool smallCaps;

  /// Character spacing stored by Word in twentieths of a point.
  final double letterSpacingPoints;

  final String? colorHex;
  final String? highlightHex;

  ConversionTextStyle copyWith({
    String? fontFamily,
    double? fontSizePoints,
    bool? bold,
    bool? italic,
    bool? underline,
    ConversionUnderlineStyle? underlineStyle,
    bool? strike,
    bool? doubleStrike,
    bool? allCaps,
    bool? smallCaps,
    double? letterSpacingPoints,
    String? colorHex,
    String? highlightHex,
  }) {
    return ConversionTextStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSizePoints: fontSizePoints ?? this.fontSizePoints,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      underlineStyle: underlineStyle ?? this.underlineStyle,
      strike: strike ?? this.strike,
      doubleStrike: doubleStrike ?? this.doubleStrike,
      allCaps: allCaps ?? this.allCaps,
      smallCaps: smallCaps ?? this.smallCaps,
      letterSpacingPoints: letterSpacingPoints ?? this.letterSpacingPoints,
      colorHex: colorHex ?? this.colorHex,
      highlightHex: highlightHex ?? this.highlightHex,
    );
  }
}

enum ConversionTextAlignment { left, center, right, justify }
