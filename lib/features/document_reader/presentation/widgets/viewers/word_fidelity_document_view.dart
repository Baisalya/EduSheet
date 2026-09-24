import 'dart:math' as math;
import 'dart:typed_data';

import 'package:edusheet/features/document_reader/domain/services/word_visual_compatibility_profile.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' as rendering;

/// High-fidelity fallback renderer for layout-heavy DOCX files.
///
/// DF2 extends the DF1 renderer with Word page-layer behavior: headers and
/// footers no longer consume body flow, table spans/margins/row heights are
/// respected, and page/margin anchored DrawingML/VML objects are positioned on
/// the page instead of being flattened into the paragraph stream.
class WordFidelityDocumentView extends StatefulWidget {
  const WordFidelityDocumentView({
    super.key,
    required this.document,
    required this.pageWidth,
    this.searchQuery = '',
  });

  final ConversionDocument document;
  final double pageWidth;
  final String searchQuery;

  static bool shouldUseFor(ConversionDocument document) {
    if (document.sections.length > 1 || document.backgroundColorHex != null) {
      return true;
    }
    for (final section in document.sections) {
      if (_blocksNeedFidelity(section.blocks) ||
          _blocksNeedFidelity(section.headerBlocks) ||
          _blocksNeedFidelity(section.footerBlocks) ||
          _blocksNeedFidelity(section.firstPageHeaderBlocks) ||
          _blocksNeedFidelity(section.firstPageFooterBlocks) ||
          _blocksNeedFidelity(section.evenPageHeaderBlocks) ||
          _blocksNeedFidelity(section.evenPageFooterBlocks)) {
        return true;
      }
    }
    return false;
  }

  static bool _blocksNeedFidelity(List<ConversionBlock> blocks) {
    for (final block in blocks) {
      if (block is ConversionTable || block is ConversionOpaqueOoxmlBlock) {
        return true;
      }
      if (block is ConversionParagraph &&
          (block.hasAdvancedLayout ||
              block.listLabel?.isNotEmpty == true ||
              block.inlines.any(
                (inline) =>
                    inline is ConversionImageRun ||
                    inline is ConversionTextBoxRun ||
                    inline is ConversionShapeRun ||
                    inline is ConversionFieldRun ||
                    inline is ConversionMathRun ||
                    inline is ConversionNoteReferenceRun ||
                    inline is ConversionCommentMarkerRun ||
                    inline is ConversionBookmarkMarkerRun ||
                    inline is ConversionOpaqueOoxmlRun,
              ))) {
        return true;
      }
    }
    return false;
  }

  static int countMatches(ConversionDocument document, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return 0;
    var count = 0;

    void visit(List<ConversionBlock> blocks) {
      for (final block in blocks) {
        if (block is ConversionParagraph) {
          final text = _paragraphPlainText(block).toLowerCase();
          var start = 0;
          while (true) {
            final index = text.indexOf(query, start);
            if (index < 0) break;
            count++;
            start = index + math.max(1, query.length);
          }
          for (final inline in block.inlines) {
            if (inline is ConversionTextBoxRun) visit(inline.blocks);
            if (inline is ConversionShapeRun) visit(inline.blocks);
          }
        } else if (block is ConversionOpaqueOoxmlBlock) {
          visit(block.fallbackBlocks);
        } else if (block is ConversionTable) {
          for (final row in block.rows) {
            for (final cell in row.cells) {
              visit(cell.blocks);
            }
          }
        }
      }
    }

    for (final section in document.sections) {
      visit(section.headerBlocks);
      visit(section.firstPageHeaderBlocks);
      visit(section.evenPageHeaderBlocks);
      visit(section.blocks);
      visit(section.footerBlocks);
      visit(section.firstPageFooterBlocks);
      visit(section.evenPageFooterBlocks);
    }
    return count;
  }

  @override
  State<WordFidelityDocumentView> createState() =>
      _WordFidelityDocumentViewState();
}

class _WordFidelityDocumentViewState extends State<WordFidelityDocumentView> {
  late List<_FidelityPage> _cachedPages;
  late WordVisualCompatibilityProfile _compatibilityProfile;

  @override
  void initState() {
    super.initState();
    _compatibilityProfile = WordVisualCompatibilityProfile.analyze(widget.document);
    _cachedPages = _pages(widget.document, profile: _compatibilityProfile);
  }

  @override
  void didUpdateWidget(covariant WordFidelityDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.document, widget.document)) {
      _compatibilityProfile = WordVisualCompatibilityProfile.analyze(widget.document);
      _cachedPages = _pages(widget.document, profile: _compatibilityProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _cachedPages;
    return LayoutBuilder(
      builder: (context, constraints) {
        final workspaceWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : widget.pageWidth;
        final contentWidth = math.max(workspaceWidth, widget.pageWidth);

        if (constraints.maxHeight.isFinite && constraints.maxHeight > 0) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentWidth,
              height: constraints.maxHeight,
              child: ListView.builder(
                key: const ValueKey('word-fidelity-lazy-page-list'),
                padding: const EdgeInsets.only(top: 16, bottom: 20),
                scrollCacheExtent: rendering.ScrollCacheExtent.pixels(
                  math.max(800.0, constraints.maxHeight * 1.5).toDouble(),
                ),
                itemCount: pages.length,
                addAutomaticKeepAlives: false,
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.only(
                    bottom: index == pages.length - 1 ? 0 : 16,
                  ),
                  child: Center(
                    child: RepaintBoundary(
                      key: ValueKey('word-fidelity-page-boundary-$index'),
                      child: _WordFidelitySectionPage(
                        page: pages[index],
                        pageCount: pages.length,
                        pageWidth: widget.pageWidth,
                        searchQuery: widget.searchQuery,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Defensive fallback for unusual unbounded hosts. The normal reader
        // supplies a bounded Expanded viewport and therefore uses the lazy path.
        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentWidth,
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    for (var i = 0; i < pages.length; i++) ...[
                      RepaintBoundary(
                        child: _WordFidelitySectionPage(
                          page: pages[i],
                          pageCount: pages.length,
                          pageWidth: widget.pageWidth,
                          searchQuery: widget.searchQuery,
                        ),
                      ),
                      if (i != pages.length - 1) const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FidelityPage {
  const _FidelityPage({
    required this.section,
    required this.columns,
    required this.pageIndexInSection,
    required this.absolutePageNumber,
    required this.displayPageNumber,
    required this.evenAndOddHeaders,
    required this.mirrorMargins,
    required this.gutterAtTop,
    this.backgroundColorHex,
    this.isParityBlank = false,
  });

  final ConversionSection section;
  final List<List<ConversionBlock>> columns;
  final int pageIndexInSection;
  final int absolutePageNumber;
  final int displayPageNumber;
  final bool evenAndOddHeaders;
  final bool mirrorMargins;
  final bool gutterAtTop;
  final String? backgroundColorHex;
  final bool isParityBlank;

  List<ConversionBlock> get blocks =>
      columns.expand((column) => column).toList(growable: false);
}

// Flow fragments synthesized by the fidelity renderer never leave the visual
// pagination path. They intentionally remain ordinary blocks so several legal
// continuation fragments can share the same Word page when their measured
// geometry fits.
class _TableFlowFragmentMeta {
  const _TableFlowFragmentMeta({
    required this.hasPrevious,
    required this.hasNext,
  });

  final bool hasPrevious;
  final bool hasNext;
}

final Expando<_TableFlowFragmentMeta> _tableFlowFragmentMeta =
    Expando<_TableFlowFragmentMeta>();

List<ConversionBlock> _blocksForPageFlow(
  List<ConversionBlock> source,
  double widthPoints,
  double maxHeightPoints, {
  WordVisualCompatibilityProfile? profile,
}) {
  final result = <ConversionBlock>[];
  for (final block in source) {
    if (block is ConversionOpaqueOoxmlBlock &&
        block.fallbackBlocks.isNotEmpty) {
      // Preserve-only OOXML stays authoritative in the canonical model/export
      // path. For visual page flow, render its readable fallback as normal Word
      // blocks so a large content control/AlternateContent wrapper can span
      // pages instead of becoming one indivisible mega-widget.
      result.addAll(
        _blocksForPageFlow(
          block.fallbackBlocks,
          widthPoints,
          maxHeightPoints,
          profile: profile,
        ),
      );
      continue;
    }
    if (block is ConversionTable) {
      result.addAll(
        _tableFragmentsForPageFlow(
          block,
          widthPoints,
          maxHeightPoints,
          profile: profile,
        ),
      );
      continue;
    }
    if (block is ConversionParagraph) {
      result.addAll(
        _paragraphFragmentsForPageFlow(
          block,
          widthPoints,
          maxHeightPoints,
          profile: profile,
        ),
      );
      continue;
    }
    result.add(block);
  }
  return result;
}

List<ConversionBlock> _paragraphFragmentsForPageFlow(
  ConversionParagraph paragraph,
  double widthPoints,
  double maxHeightPoints, {
  WordVisualCompatibilityProfile? profile,
}) {
  // `keepLines` is Word's explicit instruction that the paragraph must not be
  // split between pages. Manual page/column breaks also belong only to the
  // source paragraph and therefore stay atomic here.
  if (paragraph.keepLines ||
      paragraph.pageBreakBefore ||
      paragraph.columnBreakBefore ||
      !_supportsSafeParagraphFragmentation(paragraph)) {
    return <ConversionBlock>[paragraph];
  }

  final fullHeight = _estimateBlockHeight(paragraph, widthPoints);
  final printable = math.max(36.0, maxHeightPoints);
  // Short paragraphs are better moved intact. Long prose paragraphs are the
  // ones where Word's widow/orphan pagination materially differs from an
  // indivisible Flutter widget.
  if (fullHeight <= printable * 0.52 ||
      _paragraphLineCount(paragraph, widthPoints) < 6) {
    return <ConversionBlock>[paragraph];
  }

  final targetFraction =
      profile?.paragraphFragmentTargetFraction ?? 0.44;
  final targetHeight = math.max(36.0, printable * targetFraction);
  final pieces = <ConversionParagraph>[];
  var remaining = paragraph;
  var guard = 0;

  while (_estimateBlockHeight(remaining, widthPoints) > targetHeight &&
      guard++ < 64) {
    final split = _splitParagraphToHeight(
      remaining,
      widthPoints,
      targetHeight,
    );
    if (split == null) break;

    if (paragraph.widowControl) {
      final firstLines = _paragraphLineCount(split.$1, widthPoints);
      final remainingLines = _paragraphLineCount(split.$2, widthPoints);
      // Word's default widow/orphan rule keeps at least two lines at both
      // sides of a page break. If a legal split cannot satisfy that rule, keep
      // the source paragraph atomic instead of fabricating a one-line widow.
      if (firstLines < 2 || remainingLines < 2) {
        break;
      }
    }

    pieces.add(split.$1);
    remaining = split.$2;
  }

  if (pieces.isEmpty) return <ConversionBlock>[paragraph];
  pieces.add(remaining);

  final finalized = <ConversionParagraph>[];
  for (var index = 0; index < pieces.length; index++) {
    final sourcePiece = pieces[index];
    finalized.add(
      _copyParagraph(
        sourcePiece,
        spaceBeforePoints: index == 0 ? paragraph.spaceBeforePoints : 0,
        spaceAfterPoints:
            index == pieces.length - 1 ? paragraph.spaceAfterPoints : 0,
        pageBreakBefore: index == 0 && paragraph.pageBreakBefore,
        columnBreakBefore: index == 0 && paragraph.columnBreakBefore,
        keepWithNext:
            index == pieces.length - 1 && paragraph.keepWithNext,
        borders: ConversionBorders(
          top: index == 0 ? paragraph.borders.top : null,
          right: paragraph.borders.right,
          bottom: index == pieces.length - 1 ? paragraph.borders.bottom : null,
          left: paragraph.borders.left,
          insideHorizontal: paragraph.borders.insideHorizontal,
          insideVertical: paragraph.borders.insideVertical,
          between: paragraph.borders.between,
          bar: paragraph.borders.bar,
        ),
        listLabel: index == 0 ? paragraph.listLabel : null,
        listLabelStyle: index == 0 ? paragraph.listLabelStyle : null,
        overrideListMetadata: true,
      ),
    );
  }
  return List<ConversionBlock>.unmodifiable(finalized);
}

bool _supportsSafeParagraphFragmentation(ConversionParagraph paragraph) {
  var hasText = false;
  for (final inline in paragraph.inlines) {
    if (inline is ConversionTextRun) {
      hasText = hasText || inline.text.isNotEmpty;
      continue;
    }
    // Non-printing anchors can safely move with the nearest text fragment.
    if (inline is ConversionBookmarkMarkerRun ||
        inline is ConversionCommentMarkerRun) {
      continue;
    }
    return false;
  }
  return hasText;
}

(ConversionParagraph, ConversionParagraph)? _splitParagraphToHeight(
  ConversionParagraph paragraph,
  double widthPoints,
  double targetHeight,
) {
  final plainText = paragraph.inlines
      .whereType<ConversionTextRun>()
      .map((run) => run.text)
      .join();
  if (plainText.trim().isEmpty || plainText.length < 4) return null;

  var low = 1;
  var high = plainText.length - 1;
  var best = -1;
  while (low <= high) {
    final middle = (low + high) >> 1;
    final candidateOffset = _paragraphBreakBefore(plainText, middle);
    if (candidateOffset <= 0 || candidateOffset >= plainText.length) {
      high = middle - 1;
      continue;
    }
    final split = _splitParagraphInlines(paragraph.inlines, candidateOffset);
    final first = _copyParagraph(
      paragraph,
      inlines: split.$1,
      spaceAfterPoints: 0,
      keepWithNext: false,
    );
    final height = _estimateBlockHeight(first, widthPoints);
    if (height <= targetHeight) {
      best = math.max(best, candidateOffset);
      low = middle + 1;
    } else {
      high = middle - 1;
    }
  }

  if (best <= 0 || best >= plainText.length) return null;
  final inlines = _splitParagraphInlines(paragraph.inlines, best);
  if (inlines.$1.whereType<ConversionTextRun>().every((run) => run.text.isEmpty) ||
      inlines.$2.whereType<ConversionTextRun>().every((run) => run.text.isEmpty)) {
    return null;
  }
  return (
    _copyParagraph(
      paragraph,
      inlines: inlines.$1,
      spaceAfterPoints: 0,
      keepWithNext: false,
    ),
    _copyParagraph(
      paragraph,
      inlines: inlines.$2,
      spaceBeforePoints: 0,
      pageBreakBefore: false,
      columnBreakBefore: false,
      listLabel: null,
      listLabelStyle: null,
      overrideListMetadata: true,
    ),
  );
}

int _paragraphBreakBefore(String text, int preferred) {
  var cursor = preferred.clamp(1, text.length - 1).toInt();
  final floor = math.max(1, cursor - 96);
  while (cursor > floor) {
    final code = text.codeUnitAt(cursor - 1);
    if (code == 0x20 || code == 0x09 || code == 0x0A || code == 0x2D) {
      return cursor;
    }
    cursor--;
  }
  return preferred.clamp(1, text.length - 1).toInt();
}

(List<ConversionInline>, List<ConversionInline>) _splitParagraphInlines(
  List<ConversionInline> source,
  int textOffset,
) {
  final first = <ConversionInline>[];
  final second = <ConversionInline>[];
  var consumed = 0;
  for (final inline in source) {
    if (inline is ConversionTextRun) {
      final length = inline.text.length;
      final local = (textOffset - consumed).clamp(0, length).toInt();
      if (local > 0) {
        first.add(
          ConversionTextRun(
            text: inline.text.substring(0, local),
            style: inline.style,
            hyperlink: inline.hyperlink,
          ),
        );
      }
      if (local < length) {
        second.add(
          ConversionTextRun(
            text: inline.text.substring(local),
            style: inline.style,
            hyperlink: inline.hyperlink,
          ),
        );
      }
      consumed += length;
      continue;
    }
    if (consumed <= textOffset) {
      first.add(inline);
    } else {
      second.add(inline);
    }
  }
  return (
    List<ConversionInline>.unmodifiable(first),
    List<ConversionInline>.unmodifiable(second),
  );
}

ConversionParagraph _copyParagraph(
  ConversionParagraph source, {
  List<ConversionInline>? inlines,
  double? spaceBeforePoints,
  double? spaceAfterPoints,
  bool? pageBreakBefore,
  bool? columnBreakBefore,
  bool? keepWithNext,
  ConversionBorders? borders,
  String? listLabel,
  ConversionTextStyle? listLabelStyle,
  bool overrideListMetadata = false,
}) {
  return ConversionParagraph(
    inlines: inlines ?? source.inlines,
    styleId: source.styleId,
    alignment: source.alignment,
    spaceBeforePoints: spaceBeforePoints ?? source.spaceBeforePoints,
    spaceAfterPoints: spaceAfterPoints ?? source.spaceAfterPoints,
    leftIndentPoints: source.leftIndentPoints,
    rightIndentPoints: source.rightIndentPoints,
    firstLineIndentPoints: source.firstLineIndentPoints,
    lineSpacingMultiple: source.lineSpacingMultiple,
    exactLineSpacingPoints: source.exactLineSpacingPoints,
    pageBreakBefore: pageBreakBefore ?? source.pageBreakBefore,
    columnBreakBefore: columnBreakBefore ?? source.columnBreakBefore,
    keepWithNext: keepWithNext ?? source.keepWithNext,
    keepLines: source.keepLines,
    widowControl: source.widowControl,
    contextualSpacing: source.contextualSpacing,
    tabStops: source.tabStops,
    shadingHex: source.shadingHex,
    borders: borders ?? source.borders,
    listLabel: overrideListMetadata ? listLabel : source.listLabel,
    listLabelStyle:
        overrideListMetadata ? listLabelStyle : source.listLabelStyle,
  );
}

int _paragraphLineCount(
  ConversionParagraph paragraph,
  double widthPoints,
) {
  final spans = <TextSpan>[];
  if (paragraph.listLabel?.isNotEmpty == true) {
    spans.add(
      TextSpan(
        text: paragraph.listLabel,
        style: _wordMeasurementTextStyle(
          paragraph.listLabelStyle ?? const ConversionTextStyle(),
          paragraph,
        ),
      ),
    );
  }
  for (final inline in paragraph.inlines) {
    if (inline is ConversionTextRun) {
      spans.add(
        TextSpan(
          text: _displayRunText(inline.text, inline.style),
          style: _wordMeasurementTextStyle(inline.style, paragraph),
        ),
      );
    }
  }
  if (spans.isEmpty) return 1;
  final painter = TextPainter(
    text: TextSpan(children: List<InlineSpan>.from(spans)),
    textDirection: TextDirection.ltr,
    textAlign: _alignment(paragraph.alignment),
  )..layout(maxWidth: math.max(1.0, widthPoints));
  return math.max(1, painter.computeLineMetrics().length).toInt();
}

List<ConversionBlock> _tableFragmentsForPageFlow(
  ConversionTable table,
  double widthPoints,
  double maxHeightPoints, {
  WordVisualCompatibilityProfile? profile,
}) {
  if (table.rows.isEmpty) return <ConversionBlock>[table];

  final pageHeight = math.max(36.0, maxHeightPoints - 4.0);
  final result = <ConversionBlock>[];
  var pendingRows = <ConversionTableRow>[];

  void flushPending() {
    if (pendingRows.isEmpty) return;
    result.add(_copyTable(table, rows: pendingRows));
    pendingRows = <ConversionTableRow>[];
  }

  for (final row in table.rows) {
    final cellWidths = _estimatedTableCellWidths(table, row, widthPoints);
    final normalizedCells = <ConversionTableCell>[];
    for (var i = 0; i < row.cells.length; i++) {
      final cell = row.cells[i];
      final cellWidth = i < cellWidths.length
          ? cellWidths[i]
          : widthPoints / math.max(1, row.cells.length);
      normalizedCells.add(
        _copyTableCell(
          cell,
          blocks: _blocksForPageFlow(
            cell.blocks,
            math.max(24.0, cellWidth),
            math.max(
              24.0,
              pageHeight -
                  cell.paddingTopPoints -
                  cell.paddingBottomPoints,
            ),
            profile: profile,
          ),
        ),
      );
    }

    final normalizedRow = _copyTableRow(row, cells: normalizedCells);
    final normalizedHeight = _estimateBlockHeight(
      _copyTable(table, rows: <ConversionTableRow>[normalizedRow]),
      widthPoints,
    );

    if (normalizedHeight <= pageHeight) {
      final candidate = <ConversionTableRow>[...pendingRows, normalizedRow];
      final candidateHeight = _estimateBlockHeight(
        _copyTable(table, rows: candidate),
        widthPoints,
      );
      if (pendingRows.isNotEmpty && candidateHeight > pageHeight) {
        flushPending();
      }
      pendingRows.add(normalizedRow);
      continue;
    }

    // A row taller than the printable body is split into continuation rows.
    // Flush ordinary rows first and emit every continuation fragment as its own
    // flow block. Do NOT repack sibling fragments together afterwards: text
    // measurement here is intentionally approximate, and re-packing fragments
    // based on those estimates can recreate a row that is taller than the real
    // Flutter page at runtime (the production CV/resume failure caught by the
    // viewer runtime gate).
    flushPending();
    final fragments = _splitOversizedTableRow(
      table,
      normalizedRow,
      widthPoints,
      pageHeight,
      profile: profile,
    );
    for (var fragmentIndex = 0;
        fragmentIndex < fragments.length;
        fragmentIndex++) {
      final fragmentTable = _copyTable(
        table,
        rows: <ConversionTableRow>[fragments[fragmentIndex]],
      );
      _tableFlowFragmentMeta[fragmentTable] = _TableFlowFragmentMeta(
        hasPrevious: fragmentIndex > 0,
        hasNext: fragmentIndex + 1 < fragments.length,
      );
      result.add(fragmentTable);
    }
  }

  flushPending();
  return result.isEmpty ? <ConversionBlock>[table] : result;
}

List<ConversionTableRow> _splitOversizedTableRow(
  ConversionTable table,
  ConversionTableRow row,
  double widthPoints,
  double maxHeightPoints, {
  WordVisualCompatibilityProfile? profile,
}) {
  if (row.cells.isEmpty) return <ConversionTableRow>[row];

  final widths = _estimatedTableCellWidths(table, row, widthPoints);
  final positions = List<int>.filled(row.cells.length, 0);
  final pieces = <ConversionTableRow>[];
  var guard = 0;

  bool hasRemaining() {
    for (var i = 0; i < row.cells.length; i++) {
      if (positions[i] < row.cells[i].blocks.length) return true;
    }
    return false;
  }

  while (hasRemaining() && guard++ < 10000) {
    final fragmentCells = <ConversionTableCell>[];
    var progressed = false;

    for (var i = 0; i < row.cells.length; i++) {
      final cell = row.cells[i];
      final blocks = cell.blocks;
      final start = positions[i];
      final selected = <ConversionBlock>[];
      final cellWidth = i < widths.length
          ? widths[i]
          : widthPoints / math.max(1, row.cells.length);
      // Word can continue a splittable table row inside the remainder of the
      // current page. Keep continuation slices below roughly half a printable
      // page so two measured fragments can naturally share a page instead of
      // recreating the old resume/CV blank-area artifact. Rich TextPainter
      // metrics and seam-aware borders keep this conservative without wasting
      // an entire page per fragment.
      final budget = math.max(
        24.0,
        maxHeightPoints *
                (profile?.tableContinuationTargetFraction ?? 0.46) -
            cell.paddingTopPoints -
            cell.paddingBottomPoints -
            8.0,
      );
      var used = 0.0;
      var cursor = start;

      final innerCellWidth = _cellInnerWidthPoints(cell, cellWidth);
      while (cursor < blocks.length) {
        final candidate = <ConversionBlock>[...selected, blocks[cursor]];
        final candidateHeight = _estimateBlocksHeight(candidate, innerCellWidth);
        if (selected.isNotEmpty && candidateHeight > budget) break;
        selected.add(blocks[cursor]);
        used = candidateHeight;
        cursor++;
        progressed = true;
        if (used >= budget) break;
      }

      positions[i] = cursor;
      fragmentCells.add(_copyTableCell(cell, blocks: selected));
    }

    if (!progressed) break;
    pieces.add(
      ConversionTableRow(
        cells: List<ConversionTableCell>.unmodifiable(fragmentCells),
        isHeader: row.isHeader && pieces.isEmpty,
        cantSplit: false,
        // Exact/atLeast row heights from the source apply to the logical row,
        // not to each continuation fragment.
        heightPoints: null,
        heightRule: ConversionTableRowHeightRule.auto,
      ),
    );
  }

  return pieces.isEmpty ? <ConversionTableRow>[row] : pieces;
}

List<double> _estimatedTableCellWidths(
  ConversionTable table,
  ConversionTableRow row,
  double availableWidth,
) {
  if (row.cells.isEmpty) return const <double>[];
  final tableWidth = table.widthPoints != null && table.widthPoints! > 0
      ? math.min(availableWidth, table.widthPoints!)
      : table.widthPercent != null
          ? availableWidth *
              (table.widthPercent! / 100).clamp(0.01, 1.0).toDouble()
          : availableWidth;
  final usable = math.max(
    24.0,
    tableWidth -
        math.max(0.0, table.cellSpacingPoints) *
            math.max(0, row.cells.length - 1),
  );

  if (table.gridColumnWidths.isNotEmpty) {
    final widths = <double>[];
    var gridIndex = 0;
    for (final cell in row.cells) {
      var width = 0.0;
      final span = math.max(1, cell.gridSpan).toInt();
      for (var j = 0;
          j < span && gridIndex < table.gridColumnWidths.length;
          j++) {
        width += math.max(0.0, table.gridColumnWidths[gridIndex]);
        gridIndex++;
      }
      widths.add(width > 0 ? width : usable / row.cells.length);
    }
    final total = widths.fold<double>(0, (sum, value) => sum + value);
    if (total > 0) {
      return widths.map((value) => usable * value / total).toList();
    }
  }

  final explicit = row.cells
      .map(
        (cell) => cell.widthPoints ??
            (cell.widthPercent == null
                ? 0.0
                : usable *
                    (cell.widthPercent! / 100).clamp(0.0, 1.0).toDouble()),
      )
      .toList();
  final explicitTotal = explicit.fold<double>(0, (sum, value) => sum + value);
  if (explicitTotal > 0) {
    return explicit
        .map(
          (value) => value > 0
              ? usable * value / explicitTotal
              : usable / row.cells.length,
        )
        .toList();
  }

  return List<double>.filled(row.cells.length, usable / row.cells.length);
}

ConversionTable _copyTable(
  ConversionTable source, {
  required List<ConversionTableRow> rows,
}) {
  return ConversionTable(
    rows: List<ConversionTableRow>.unmodifiable(rows),
    showBorders: source.showBorders,
    styleId: source.styleId,
    shadingHex: source.shadingHex,
    borders: source.borders,
    layout: source.layout,
    widthPoints: source.widthPoints,
    widthPercent: source.widthPercent,
    indentPoints: source.indentPoints,
    cellSpacingPoints: source.cellSpacingPoints,
    gridColumnWidths: source.gridColumnWidths,
    alignment: source.alignment,
  );
}

ConversionTableRow _copyTableRow(
  ConversionTableRow source, {
  required List<ConversionTableCell> cells,
}) {
  return ConversionTableRow(
    cells: List<ConversionTableCell>.unmodifiable(cells),
    isHeader: source.isHeader,
    cantSplit: source.cantSplit,
    heightPoints: source.heightPoints,
    heightRule: source.heightRule,
  );
}

ConversionTableCell _copyTableCell(
  ConversionTableCell source, {
  required List<ConversionBlock> blocks,
}) {
  return ConversionTableCell(
    blocks: List<ConversionBlock>.unmodifiable(blocks),
    shadingHex: source.shadingHex,
    borders: source.borders,
    widthPoints: source.widthPoints,
    widthPercent: source.widthPercent,
    gridSpan: source.gridSpan,
    paddingTopPoints: source.paddingTopPoints,
    paddingRightPoints: source.paddingRightPoints,
    paddingBottomPoints: source.paddingBottomPoints,
    paddingLeftPoints: source.paddingLeftPoints,
    verticalAlignment: source.verticalAlignment,
    verticalMerge: source.verticalMerge,
    noWrap: source.noWrap,
  );
}

List<ConversionSection> _visualSections(List<ConversionSection> source) {
  if (source.length < 2) return source;
  final result = <ConversionSection>[];
  for (final section in source) {
    if (result.isEmpty ||
        (section.breakType != ConversionSectionBreakType.continuous &&
            section.breakType != ConversionSectionBreakType.nextColumn)) {
      result.add(section);
      continue;
    }

    final previous = result.last;
    if (!_canCoalesceVisualSections(previous, section)) {
      result.add(section);
      continue;
    }

    final blocks = <ConversionBlock>[...previous.blocks];
    if (section.breakType == ConversionSectionBreakType.nextColumn) {
      // Section breaks are formatting commands rather than printable
      // paragraphs. Use a zero-height synthetic paragraph to advance the flow
      // to the next Word column without creating visible blank text.
      blocks.add(
        const ConversionParagraph(
          inlines: <ConversionInline>[],
          columnBreakBefore: true,
          exactLineSpacingPoints: 0,
          spaceBeforePoints: 0,
          spaceAfterPoints: 0,
        ),
      );
    }
    blocks.addAll(section.blocks);

    result[result.length - 1] = ConversionSection(
      page: previous.page,
      blocks: List<ConversionBlock>.unmodifiable(blocks),
      headerBlocks: previous.headerBlocks,
      footerBlocks: previous.footerBlocks,
      firstPageHeaderBlocks: previous.firstPageHeaderBlocks,
      firstPageFooterBlocks: previous.firstPageFooterBlocks,
      evenPageHeaderBlocks: previous.evenPageHeaderBlocks,
      evenPageFooterBlocks: previous.evenPageFooterBlocks,
      breakType: previous.breakType,
      titlePage: previous.titlePage,
      columns: previous.columns,
      pageNumberStart: previous.pageNumberStart,
      pageNumberFormat: previous.pageNumberFormat,
    );
  }
  return List<ConversionSection>.unmodifiable(result);
}

bool _canCoalesceVisualSections(
  ConversionSection previous,
  ConversionSection current,
) {
  if (!_samePageSettings(previous.page, current.page) ||
      !_sameColumns(previous.columns, current.columns) ||
      previous.titlePage != current.titlePage ||
      current.pageNumberStart != null ||
      current.pageNumberFormat != previous.pageNumberFormat) {
    return false;
  }

  return _storyFingerprint(previous.headerBlocks) ==
          _storyFingerprint(current.headerBlocks) &&
      _storyFingerprint(previous.footerBlocks) ==
          _storyFingerprint(current.footerBlocks) &&
      _storyFingerprint(previous.firstPageHeaderBlocks) ==
          _storyFingerprint(current.firstPageHeaderBlocks) &&
      _storyFingerprint(previous.firstPageFooterBlocks) ==
          _storyFingerprint(current.firstPageFooterBlocks) &&
      _storyFingerprint(previous.evenPageHeaderBlocks) ==
          _storyFingerprint(current.evenPageHeaderBlocks) &&
      _storyFingerprint(previous.evenPageFooterBlocks) ==
          _storyFingerprint(current.evenPageFooterBlocks);
}

bool _samePageSettings(ConversionPageSettings a, ConversionPageSettings b) {
  bool close(double x, double y) => (x - y).abs() < 0.01;
  return close(a.widthPoints, b.widthPoints) &&
      close(a.heightPoints, b.heightPoints) &&
      close(a.marginTopPoints, b.marginTopPoints) &&
      close(a.marginRightPoints, b.marginRightPoints) &&
      close(a.marginBottomPoints, b.marginBottomPoints) &&
      close(a.marginLeftPoints, b.marginLeftPoints) &&
      close(a.headerDistancePoints, b.headerDistancePoints) &&
      close(a.footerDistancePoints, b.footerDistancePoints) &&
      close(a.gutterPoints, b.gutterPoints) &&
      a.pageBorders.offsetFrom == b.pageBorders.offsetFrom &&
      a.pageBorders.display == b.pageBorders.display &&
      a.pageBorders.zOrder == b.pageBorders.zOrder &&
      _sameBorders(a.pageBorders.borders, b.pageBorders.borders);
}

bool _sameBorders(ConversionBorders a, ConversionBorders b) {
  bool sameSide(ConversionBorderSide? x, ConversionBorderSide? y) {
    if (x == null || y == null) return x == null && y == null;
    return x.style == y.style &&
        (x.widthPoints - y.widthPoints).abs() < 0.01 &&
        x.colorHex == y.colorHex &&
        (x.spacePoints - y.spacePoints).abs() < 0.01;
  }

  return sameSide(a.top, b.top) &&
      sameSide(a.right, b.right) &&
      sameSide(a.bottom, b.bottom) &&
      sameSide(a.left, b.left) &&
      sameSide(a.insideHorizontal, b.insideHorizontal) &&
      sameSide(a.insideVertical, b.insideVertical) &&
      sameSide(a.between, b.between) &&
      sameSide(a.bar, b.bar);
}

bool _sameColumns(ConversionColumns a, ConversionColumns b) {
  if (a.count != b.count ||
      a.equalWidth != b.equalWidth ||
      (a.spacingPoints - b.spacingPoints).abs() >= 0.01 ||
      a.separator != b.separator ||
      a.columns.length != b.columns.length) {
    return false;
  }
  for (var index = 0; index < a.columns.length; index++) {
    final left = a.columns[index];
    final right = b.columns[index];
    if (((left.widthPoints ?? 0) - (right.widthPoints ?? 0)).abs() >= 0.01 ||
        ((left.spacingPoints ?? 0) - (right.spacingPoints ?? 0)).abs() >=
            0.01) {
      return false;
    }
  }
  return true;
}

String _storyFingerprint(List<ConversionBlock> blocks) {
  final buffer = StringBuffer();
  void visit(List<ConversionBlock> values) {
    for (final block in values) {
      if (block is ConversionParagraph) {
        buffer.write('P:${block.styleId}:${block.alignment.name}|');
        for (final inline in block.inlines) {
          if (inline is ConversionTextRun) {
            buffer.write('T:${inline.text}:${inline.style.fontFamily}|');
          } else if (inline is ConversionDynamicFieldRun) {
            buffer.write('D:${inline.field.name}|');
          } else if (inline is ConversionFieldRun) {
            buffer.write('F:${inline.instruction}:${inline.resultText}|');
          } else if (inline is ConversionImageRun) {
            buffer.write('I:${inline.sourcePartPath}:${inline.widthPoints}|');
          } else if (inline is ConversionTextBoxRun) {
            buffer.write('X:${inline.widthPoints}:${inline.heightPoints}|');
            visit(inline.blocks);
          } else if (inline is ConversionShapeRun) {
            buffer.write('S:${inline.kind.name}:${inline.widthPoints}|');
            visit(inline.blocks);
          }
        }
      } else if (block is ConversionTable) {
        buffer.write('TB:${block.rows.length}|');
        for (final row in block.rows) {
          for (final cell in row.cells) {
            visit(cell.blocks);
          }
        }
      } else if (block is ConversionOpaqueOoxmlBlock) {
        buffer.write('O:${block.featureKind}:${block.rawXml.hashCode}|');
      }
    }
  }

  visit(blocks);
  return buffer.toString();
}

List<_FidelityPage> _pages(
  ConversionDocument document, {
  required WordVisualCompatibilityProfile profile,
}) {
  final result = <_FidelityPage>[];
  var absolutePage = 1;
  var nextDisplayPage = 1;
  var previousSectionPageCount = 0;
  final sections = _visualSections(document.sections);

  for (var sectionIndex = 0;
      sectionIndex < sections.length;
      sectionIndex++) {
    final section = sections[sectionIndex];

    // `w:type` describes how the *current* section begins relative to the
    // previous section. Insert an automatic parity page before this section
    // when an odd/even-page section start requires one.
    if (sectionIndex > 0 &&
        (section.breakType == ConversionSectionBreakType.oddPage ||
            section.breakType == ConversionSectionBreakType.evenPage)) {
      final wantsOdd = section.breakType == ConversionSectionBreakType.oddPage;
      if (absolutePage.isOdd != wantsOdd) {
        final previous = sections[sectionIndex - 1];
        final previousColumnCount = math.max(1, previous.columns.count).toInt();
        result.add(
          _FidelityPage(
            section: previous,
            columns: List<List<ConversionBlock>>.unmodifiable(
              List<List<ConversionBlock>>.generate(
                previousColumnCount,
                (_) => const <ConversionBlock>[],
              ),
            ),
            pageIndexInSection: previousSectionPageCount,
            absolutePageNumber: absolutePage,
            displayPageNumber: nextDisplayPage,
            evenAndOddHeaders: document.evenAndOddHeaders,
            mirrorMargins: document.mirrorMargins,
            gutterAtTop: document.gutterAtTop,
            backgroundColorHex: document.backgroundColorHex,
            isParityBlank: true,
          ),
        );
        absolutePage++;
        nextDisplayPage++;
        previousSectionPageCount++;
      }
    }

    final columnCount = math.max(1, section.columns.count).toInt();
    final pageHeight = section.page.heightPoints <= 0
        ? 792.0
        : section.page.heightPoints;
    final contentHeight = math.max(
      72.0,
      pageHeight -
          section.page.marginTopPoints -
          section.page.marginBottomPoints -
          (document.gutterAtTop ? section.page.gutterPoints : 0),
    );
    final pageWidth = section.page.widthPoints <= 0
        ? 612.0
        : section.page.widthPoints;
    final contentWidth = math.max(
      72.0,
      pageWidth -
          section.page.marginLeftPoints -
          section.page.marginRightPoints -
          (document.gutterAtTop ? 0 : section.page.gutterPoints),
    );
    final widths = _columnWidthsPoints(section.columns, contentWidth);

    var localPageIndex = 0;
    var displayPage = section.pageNumberStart ?? nextDisplayPage;
    var columns = List<List<ConversionBlock>>.generate(
      columnCount,
      (_) => <ConversionBlock>[],
    );
    var used = List<double>.filled(columnCount, 0);
    var columnIndex = 0;

    bool hasAnyContent() => columns.any((column) => column.isNotEmpty);

    void commitPage({bool force = false}) {
      if (!force && !hasAnyContent()) return;
      result.add(
        _FidelityPage(
          section: section,
          columns: List<List<ConversionBlock>>.unmodifiable(
            columns
                .map((items) => List<ConversionBlock>.unmodifiable(items))
                .toList(growable: false),
          ),
          pageIndexInSection: localPageIndex,
          absolutePageNumber: absolutePage,
          displayPageNumber: displayPage,
          evenAndOddHeaders: document.evenAndOddHeaders,
          mirrorMargins: document.mirrorMargins,
          gutterAtTop: document.gutterAtTop,
          backgroundColorHex: document.backgroundColorHex,
        ),
      );
      localPageIndex++;
      absolutePage++;
      displayPage++;
      columns = List<List<ConversionBlock>>.generate(
        columnCount,
        (_) => <ConversionBlock>[],
      );
      used = List<double>.filled(columnCount, 0);
      columnIndex = 0;
    }

    void advanceFlow() {
      if (columnIndex + 1 < columnCount) {
        columnIndex++;
      } else {
        commitPage(force: true);
      }
    }

    final blocks = _blocksForPageFlow(
      section.blocks,
      widths.isEmpty ? contentWidth : widths.first,
      contentHeight,
      profile: profile,
    );
    for (var blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
      final block = blocks[blockIndex];
      final beginsNewPage = block is ConversionParagraph && block.pageBreakBefore;
      final beginsNewColumn =
          block is ConversionParagraph && block.columnBreakBefore;
      if (beginsNewPage && hasAnyContent()) {
        commitPage(force: true);
      } else if (beginsNewColumn) {
        // A manual column break is an explicit flow command. Preserve an
        // intentionally empty leading column instead of discarding the break.
        if (columnCount > 1) {
          advanceFlow();
        } else {
          commitPage(force: true);
        }
      }

      final width = widths[math.min(columnIndex, widths.length - 1)];
      var blockHeight = _estimateBlockHeightInSequence(
        blocks,
        blockIndex,
        width,
      );
      if (block is ConversionParagraph &&
          block.keepWithNext &&
          blockIndex + 1 < blocks.length) {
        var lookAhead = blockIndex + 1;
        while (lookAhead < blocks.length) {
          blockHeight += _estimateBlockHeightInSequence(
            blocks,
            lookAhead,
            width,
          );
          final next = blocks[lookAhead];
          if (next is! ConversionParagraph || !next.keepWithNext) break;
          lookAhead++;
        }
      }

      final remaining = contentHeight - used[columnIndex];
      if (blockHeight > remaining && columns[columnIndex].isNotEmpty) {
        advanceFlow();
      }

      columns[columnIndex].add(block);
      used[columnIndex] += _estimateBlockHeightInSequence(
        blocks,
        blockIndex,
        widths[math.min(columnIndex, widths.length - 1)],
      );
    }

    commitPage(force: true);
    nextDisplayPage = displayPage;
    previousSectionPageCount = localPageIndex;

    // Continuous/next-column sections with compatible page/story geometry are
    // coalesced by `_visualSections` before pagination. Incompatible section
    // property changes intentionally remain a fresh visual page rather than
    // flattening Word semantics incorrectly.
  }
  return result;
}

List<double> _columnWidthsPoints(
  ConversionColumns columns,
  double availableWidth,
) {
  final count = math.max(1, columns.count).toInt();
  if (count == 1) return <double>[availableWidth];

  if (!columns.equalWidth && columns.columns.isNotEmpty) {
    final explicit = <double>[];
    for (var index = 0; index < count; index++) {
      final spec = index < columns.columns.length ? columns.columns[index] : null;
      explicit.add(math.max(1.0, spec?.widthPoints ?? 1.0));
    }
    final totalSpacing = List<double>.generate(
      math.max(0, count - 1).toInt(),
      (index) => index < columns.columns.length
          ? columns.columns[index].spacingPoints ?? columns.spacingPoints
          : columns.spacingPoints,
    ).fold<double>(0, (sum, value) => sum + value);
    final target = math.max(1.0, availableWidth - totalSpacing);
    final rawTotal = explicit.fold<double>(0, (sum, value) => sum + value);
    if (rawTotal <= 0) return List<double>.filled(count, target / count);
    return explicit.map((value) => target * value / rawTotal).toList();
  }

  final spacing = math.max(0.0, columns.spacingPoints) * (count - 1);
  final width = math.max(1.0, availableWidth - spacing) / count;
  return List<double>.filled(count, width);
}

List<double> _columnSpacingsPoints(ConversionColumns columns) {
  final count = math.max(1, columns.count).toInt();
  if (count <= 1) return const <double>[];
  return List<double>.generate(count - 1, (index) {
    if (!columns.equalWidth && index < columns.columns.length) {
      return math.max(
        0.0,
        columns.columns[index].spacingPoints ?? columns.spacingPoints,
      );
    }
    return math.max(0.0, columns.spacingPoints);
  });
}

double _estimateBlockHeight(
  ConversionBlock block,
  double widthPoints, {
  double? spaceBeforeOverride,
  double? spaceAfterOverride,
}) {
  if (block is ConversionParagraph) {
    var maxFont = 11.0;
    for (final inline in block.inlines) {
      ConversionTextStyle? style;
      if (inline is ConversionTextRun) {
        style = inline.style;
      } else if (inline is ConversionDynamicFieldRun) {
        style = inline.style;
      } else if (inline is ConversionFieldRun) {
        style = inline.style;
      } else if (inline is ConversionMathRun) {
        style = inline.style;
      } else if (inline is ConversionNoteReferenceRun) {
        style = inline.style;
      } else if (inline is ConversionOpaqueOoxmlRun) {
        style = inline.style;
      }
      if (style != null) maxFont = math.max(maxFont, style.fontSizePoints);
    }

    final available = math.max(
      12.0,
      widthPoints -
          block.leftIndentPoints -
          block.rightIndentPoints -
          (block.tabStops.isEmpty
              ? math.max(0.0, block.firstLineIndentPoints)
              : 0.0),
    );
    final contentHeight = _measureParagraphContentHeight(
      block,
      available,
      fallbackFontSize: maxFont,
    );
    final borderSpace = (block.borders.top?.spacePoints ?? 0) +
        (block.borders.bottom?.spacePoints ?? 0) +
        (block.borders.top?.widthPoints ?? 0) +
        (block.borders.bottom?.widthPoints ?? 0);
    return contentHeight +
        (spaceBeforeOverride ?? block.spaceBeforePoints) +
        (spaceAfterOverride ?? block.spaceAfterPoints) +
        borderSpace;
  }

  if (block is ConversionOpaqueOoxmlBlock) {
    if (block.fallbackBlocks.isEmpty) return 28.0;
    return math.max(
      28.0,
      _estimateBlocksHeight(block.fallbackBlocks, widthPoints),
    );
  }

  if (block is ConversionTable) {
    var total = 4.0; // _WordTableView top + bottom flow padding at 1x scale.
    for (var rowIndex = 0; rowIndex < block.rows.length; rowIndex++) {
      final row = block.rows[rowIndex];
      final widths = _estimatedTableCellWidths(block, row, widthPoints);
      var rowHeight = 0.0;
      for (var cellIndex = 0; cellIndex < row.cells.length; cellIndex++) {
        final cell = row.cells[cellIndex];
        final outerCellWidth = cellIndex < widths.length
            ? widths[cellIndex]
            : widthPoints / math.max(1, row.cells.length);
        final innerCellWidth = _cellInnerWidthPoints(cell, outerCellWidth);
        rowHeight = math.max(
          rowHeight,
          _estimateBlocksHeight(cell.blocks, innerCellWidth) +
              cell.paddingTopPoints +
              cell.paddingBottomPoints,
        );
      }
      if (row.heightPoints != null) {
        rowHeight = row.heightRule == ConversionTableRowHeightRule.exact
            ? row.heightPoints!
            : math.max(rowHeight, row.heightPoints!);
      }
      if (rowIndex > 0) total += math.max(0.0, block.cellSpacingPoints);
      total += math.max(12.0, rowHeight);
    }
    return total;
  }
  return 14.0;
}

double _cellInnerWidthPoints(
  ConversionTableCell cell,
  double outerWidthPoints,
) =>
    math.max(
      12.0,
      outerWidthPoints - cell.paddingLeftPoints - cell.paddingRightPoints,
    );

double _estimateBlockHeightInSequence(
  List<ConversionBlock> blocks,
  int index,
  double widthPoints,
) {
  final block = blocks[index];
  if (block is! ConversionParagraph) {
    return _estimateBlockHeight(block, widthPoints);
  }
  final previous = index > 0 ? blocks[index - 1] : null;
  final next = index + 1 < blocks.length ? blocks[index + 1] : null;
  final sameStyleAsPrevious = previous is ConversionParagraph &&
      previous.styleId == block.styleId;
  final sameStyleAsNext = next is ConversionParagraph &&
      next.styleId == block.styleId;
  return _estimateBlockHeight(
    block,
    widthPoints,
    spaceBeforeOverride:
        block.contextualSpacing && sameStyleAsPrevious ? 0.0 : null,
    spaceAfterOverride:
        block.contextualSpacing && sameStyleAsNext ? 0.0 : null,
  );
}

double _estimateBlocksHeight(
  List<ConversionBlock> blocks,
  double widthPoints,
) {
  var total = 0.0;
  for (var index = 0; index < blocks.length; index++) {
    total += _estimateBlockHeightInSequence(blocks, index, widthPoints);
  }
  return total;
}

double _measureParagraphContentHeight(
  ConversionParagraph paragraph,
  double widthPoints, {
  required double fallbackFontSize,
}) {
  final wrapReservation = _paragraphWrapReservation(paragraph, widthPoints);
  final measuredWidth = math.max(
    8.0,
    widthPoints -
        wrapReservation.leftInsetPoints -
        wrapReservation.rightInsetPoints,
  );
  final spans = <TextSpan>[];
  var total = 0.0;
  var hasVisibleObject = false;

  void flushSpans() {
    if (spans.isEmpty) return;
    total += _measureTextSpanHeight(
      paragraph,
      List<TextSpan>.from(spans),
      measuredWidth,
      fallbackFontSize,
    );
    spans.clear();
  }

  if (paragraph.listLabel?.isNotEmpty == true) {
    final markerStyle = paragraph.listLabelStyle ??
        ConversionTextStyle(fontSizePoints: fallbackFontSize);
    spans.add(
      TextSpan(
        text: paragraph.listLabel,
        style: _wordMeasurementTextStyle(markerStyle, paragraph),
      ),
    );
  }

  for (final inline in paragraph.inlines) {
    if (inline is ConversionTextRun) {
      spans.add(
        TextSpan(
          text: _displayRunText(inline.text, inline.style),
          style: _wordMeasurementTextStyle(inline.style, paragraph),
        ),
      );
    } else if (inline is ConversionDynamicFieldRun) {
      spans.add(
        TextSpan(
          text: inline.field == ConversionDynamicField.pageNumber ? '1' : '9',
          style: _wordMeasurementTextStyle(inline.style, paragraph),
        ),
      );
    } else if (inline is ConversionFieldRun) {
      spans.add(
        TextSpan(
          text: inline.resultText.isEmpty
              ? '{${inline.fieldName.isEmpty ? 'FIELD' : inline.fieldName}}'
              : inline.resultText,
          style: _wordMeasurementTextStyle(inline.style, paragraph),
        ),
      );
    } else if (inline is ConversionMathRun) {
      spans.add(
        TextSpan(
          text: inline.plainText.isEmpty ? '∑' : inline.plainText,
          style: _wordMeasurementTextStyle(
            inline.style.copyWith(fontFamily: 'Cambria Math'),
            paragraph,
          ),
        ),
      );
    } else if (inline is ConversionNoteReferenceRun) {
      spans.add(
        TextSpan(
          text: _superscript(inline.displayLabel ?? inline.noteId),
          style: _wordMeasurementTextStyle(inline.style, paragraph).copyWith(
            fontSize: math.max(7.0, inline.style.fontSizePoints * 0.72),
          ),
        ),
      );
    } else if (inline is ConversionOpaqueOoxmlRun) {
      final fallback = inline.fallbackText.trim();
      spans.add(
        TextSpan(
          text: fallback.isEmpty
              ? '[Word ${inline.featureKind} preserved]'
              : fallback,
          style: _wordMeasurementTextStyle(inline.style, paragraph),
        ),
      );
    } else if (inline is ConversionImageRun &&
        !inline.placement.isViewerPositioned) {
      flushSpans();
      total += math.max(0.0, inline.heightPoints);
      hasVisibleObject = true;
    } else if (inline is ConversionTextBoxRun &&
        !inline.placement.isViewerPositioned) {
      flushSpans();
      total += math.max(
        0.0,
        inline.heightPoints ??
            _estimateBlocksHeight(
              inline.blocks,
              math.max(12.0, inline.widthPoints ?? widthPoints),
            ),
      );
      hasVisibleObject = true;
    } else if (inline is ConversionShapeRun &&
        !inline.placement.isViewerPositioned) {
      flushSpans();
      total += math.max(0.0, inline.heightPoints);
      hasVisibleObject = true;
    }
  }
  flushSpans();

  if (total <= 0 && !hasVisibleObject) {
    final exact = paragraph.exactLineSpacingPoints;
    total = exact ??
        fallbackFontSize * 1.15 * (paragraph.lineSpacingMultiple ?? 1.0);
  }
  return math.max(
    total + wrapReservation.topInsetPoints,
    wrapReservation.minimumHeightPoints,
  );
}

class _ParagraphWrapReservation {
  const _ParagraphWrapReservation({
    this.leftInsetPoints = 0,
    this.rightInsetPoints = 0,
    this.topInsetPoints = 0,
    this.minimumHeightPoints = 0,
  });

  final double leftInsetPoints;
  final double rightInsetPoints;
  final double topInsetPoints;
  final double minimumHeightPoints;
}

_ParagraphWrapReservation _paragraphWrapReservation(
  ConversionParagraph paragraph,
  double widthPoints,
) {
  var leftInset = 0.0;
  var rightInset = 0.0;
  var topInset = 0.0;
  var minimumHeight = 0.0;

  for (final inline in paragraph.inlines) {
    ConversionObjectPlacement? placement;
    double objectWidth = 0;
    double objectHeight = 0;
    if (inline is ConversionImageRun) {
      placement = inline.placement;
      objectWidth = inline.widthPoints;
      objectHeight = inline.heightPoints;
    } else if (inline is ConversionTextBoxRun) {
      placement = inline.placement;
      objectWidth = inline.widthPoints ?? 160;
      objectHeight = inline.heightPoints ?? 80;
    } else if (inline is ConversionShapeRun) {
      placement = inline.placement;
      objectWidth = inline.widthPoints;
      objectHeight = inline.heightPoints;
    }
    if (placement == null || !placement.affectsTextFlow) continue;

    final wrap = placement.wrapStyle?.toLowerCase();
    final reserveHeight = math.max(
      0.0,
      objectHeight +
          placement.distanceTopPoints +
          placement.distanceBottomPoints,
    );
    minimumHeight = math.max(minimumHeight, reserveHeight);
    if (wrap == 'wraptopandbottom') {
      topInset = math.max(topInset, reserveHeight);
      continue;
    }

    final reserveWidth = math.min(
      math.max(0.0, widthPoints - 8.0),
      objectWidth +
          placement.distanceLeftPoints +
          placement.distanceRightPoints,
    );
    final wrapText = placement.wrapText?.toLowerCase();
    final alignment = placement.horizontalAlignment?.toLowerCase();
    final offset = placement.horizontalOffsetPoints ?? 0;
    final objectLikelyRight = alignment == 'right' ||
        alignment == 'outside' ||
        (alignment == null && offset > widthPoints * 0.45);

    if (wrapText == 'left') {
      rightInset = math.max(rightInset, reserveWidth);
    } else if (wrapText == 'right') {
      leftInset = math.max(leftInset, reserveWidth);
    } else if (wrapText == 'largest') {
      // Word selects the larger free side. Without the final glyph geometry at
      // model time, the anchor alignment is the most stable predictor.
      if (objectLikelyRight) {
        rightInset = math.max(rightInset, reserveWidth);
      } else {
        leftInset = math.max(leftInset, reserveWidth);
      }
    } else if (objectLikelyRight) {
      rightInset = math.max(rightInset, reserveWidth);
    } else {
      leftInset = math.max(leftInset, reserveWidth);
    }
  }

  if (leftInset + rightInset > widthPoints - 8.0) {
    if (leftInset >= rightInset) {
      leftInset = math.max(0.0, widthPoints - 8.0);
      rightInset = 0;
    } else {
      rightInset = math.max(0.0, widthPoints - 8.0);
      leftInset = 0;
    }
  }
  return _ParagraphWrapReservation(
    leftInsetPoints: leftInset,
    rightInsetPoints: rightInset,
    topInsetPoints: topInset,
    minimumHeightPoints: minimumHeight,
  );
}

double _measureTextSpanHeight(
  ConversionParagraph paragraph,
  List<TextSpan> spans,
  double widthPoints,
  double fallbackFontSize,
) {
  if (spans.isEmpty) return 0.0;
  final exact = paragraph.exactLineSpacingPoints;
  final painter = TextPainter(
    text: TextSpan(
      style: _wordMeasurementTextStyle(
        ConversionTextStyle(fontSizePoints: fallbackFontSize),
        paragraph,
      ),
      children: List<InlineSpan>.from(spans),
    ),
    textDirection: TextDirection.ltr,
    textAlign: _alignment(paragraph.alignment),
    strutStyle: exact == null
        ? null
        : StrutStyle(
            fontSize: math.max(1.0, exact),
            height: 1,
            forceStrutHeight: true,
          ),
  )..layout(maxWidth: math.max(1.0, widthPoints));

  final minimum = exact ??
      fallbackFontSize * 1.15 * (paragraph.lineSpacingMultiple ?? 1.0);
  return math.max(minimum, painter.height);
}

TextStyle _wordMeasurementTextStyle(
  ConversionTextStyle style,
  ConversionParagraph paragraph,
) {
  final exact = paragraph.exactLineSpacingPoints;
  final lineMultiple = paragraph.lineSpacingMultiple ?? 1.0;
  final smallCapsScale = style.smallCaps && !style.allCaps ? 0.86 : 1.0;
  return TextStyle(
    fontFamily: style.fontFamily,
    fontFamilyFallback: _wordFontFallbacks(style.fontFamily),
    fontSize: math.max(1.0, style.fontSizePoints * smallCapsScale),
    fontWeight: style.bold ? FontWeight.w700 : FontWeight.normal,
    fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: style.letterSpacingPoints,
    height: exact == null
        ? math.max(0.5, 1.15 * lineMultiple)
        : math.max(0.5, exact / math.max(1.0, style.fontSizePoints)),
  );
}

List<String> _wordFontFallbacks(String? fontFamily) {
  final normalized = (fontFamily ?? '').toLowerCase();
  if (normalized.contains('times') ||
      normalized.contains('cambria') ||
      normalized.contains('georgia') ||
      normalized.contains('garamond') ||
      normalized.contains('serif')) {
    return const <String>[
      'Times New Roman',
      'Cambria',
      'Georgia',
      'Noto Serif',
    ];
  }
  if (normalized.contains('courier') ||
      normalized.contains('consolas') ||
      normalized.contains('mono')) {
    return const <String>[
      'Consolas',
      'Courier New',
      'Roboto Mono',
      'Noto Sans Mono',
    ];
  }
  return const <String>[
    'Aptos',
    'Calibri',
    'Century Gothic',
    'Segoe UI',
    'Arial',
    'Roboto',
    'Noto Sans',
  ];
}

class _EffectivePageMargins {
  const _EffectivePageMargins({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

_EffectivePageMargins _effectivePageMargins(
  _FidelityPage page,
  ConversionPageSettings settings,
) {
  var left = settings.marginLeftPoints;
  var right = settings.marginRightPoints;
  var top = settings.marginTopPoints;
  final bottom = settings.marginBottomPoints;

  if (page.mirrorMargins && page.absolutePageNumber.isEven) {
    final swap = left;
    left = right;
    right = swap;
  }
  if (settings.gutterPoints > 0) {
    if (page.gutterAtTop) {
      top += settings.gutterPoints;
    } else if (page.mirrorMargins && page.absolutePageNumber.isEven) {
      right += settings.gutterPoints;
    } else {
      left += settings.gutterPoints;
    }
  }
  return _EffectivePageMargins(
    left: left,
    top: top,
    right: right,
    bottom: bottom,
  );
}

class _WordFidelitySectionPage extends StatelessWidget {
  const _WordFidelitySectionPage({
    required this.page,
    required this.pageCount,
    required this.pageWidth,
    required this.searchQuery,
  });

  final _FidelityPage page;
  final int pageCount;
  final double pageWidth;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final section = page.section;
    final sourcePageWidth =
        section.page.widthPoints <= 0 ? 612.0 : section.page.widthPoints;
    final sourcePageHeight =
        section.page.heightPoints <= 0 ? 792.0 : section.page.heightPoints;
    final scale = pageWidth / sourcePageWidth;
    final pageHeight = sourcePageHeight * scale;
    final margins = _effectivePageMargins(page, section.page);
    final left = margins.left * scale;
    final right = margins.right * scale;
    final top = margins.top * scale;
    final bottom = margins.bottom * scale;
    final theme = Theme.of(context);
    final headerBlocks = section.headerForPage(
      pageIndexInSection: page.pageIndexInSection,
      evenAndOddHeaders: page.evenAndOddHeaders,
    );
    final footerBlocks = section.footerForPage(
      pageIndexInSection: page.pageIndexInSection,
      evenAndOddHeaders: page.evenAndOddHeaders,
    );
    final noteReferences = _collectNoteReferences(page.blocks);

    final availableWidthPoints = math.max(
      1.0,
      sourcePageWidth - margins.left - margins.right,
    );
    final columnWidths = _columnWidthsPoints(section.columns, availableWidthPoints);
    final columnSpacings = _columnSpacingsPoints(section.columns);
    final floating = <_FloatingObject>[];
    floating.addAll(
      _collectFloating(
        headerBlocks,
        flowWidthPoints: availableWidthPoints,
        anchorBaseTopPoints: section.page.headerDistancePoints,
        stableIndexSeed: floating.length,
      ),
    );
    for (var columnIndex = 0;
        columnIndex < page.columns.length;
        columnIndex++) {
      floating.addAll(
        _collectFloating(
          page.columns[columnIndex],
          flowColumnIndex: columnIndex,
          flowWidthPoints:
              columnWidths[math.min(columnIndex, columnWidths.length - 1)],
          anchorBaseTopPoints: margins.top,
          stableIndexSeed: floating.length,
        ),
      );
    }
    final footerHeight = footerBlocks.isEmpty
        ? 0.0
        : _estimateBlocksHeight(footerBlocks, availableWidthPoints);
    floating.addAll(
      _collectFloating(
        footerBlocks,
        flowWidthPoints: availableWidthPoints,
        anchorBaseTopPoints: math.max(
          margins.top,
          sourcePageHeight - section.page.footerDistancePoints - footerHeight,
        ),
        stableIndexSeed: floating.length,
      ),
    );
    floating.sort((a, b) {
      final z = a.placement.relativeHeight.compareTo(b.placement.relativeHeight);
      return z != 0 ? z : a.stableIndex.compareTo(b.stableIndex);
    });
    final resolvedFloating = _resolveFloatingObjects(
      floating,
      scale,
      pageWidth,
      pageHeight,
      margins,
      columnWidthsPoints: columnWidths,
      columnSpacingsPoints: columnSpacings,
    );
    final behind = resolvedFloating
        .where((item) => item.object.placement.behindText)
        .toList(growable: false);
    final inFront = resolvedFloating
        .where((item) => !item.object.placement.behindText)
        .toList(growable: false);
    final body = Positioned.fill(
      child: Padding(
        padding: EdgeInsets.fromLTRB(left, top, right, bottom),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var columnIndex = 0;
                columnIndex < page.columns.length;
                columnIndex++) ...[
              if (columnIndex > 0)
                SizedBox(
                  width: columnSpacings[math.min(
                        columnIndex - 1,
                        columnSpacings.length - 1,
                      )] *
                      scale,
                ),
              SizedBox(
                key: ValueKey('word-column-$columnIndex'),
                width: columnWidths[
                        math.min(columnIndex, columnWidths.length - 1)] *
                    scale,
                child: _WordBlockList(
                  blocks: page.columns[columnIndex],
                  scale: scale,
                  searchQuery: searchQuery,
                  skipPageFloating: true,
                  pageNumber: page.displayPageNumber,
                  pageCount: pageCount,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final pageBorder = _pageBorderWidget(
      section.page.pageBorders,
      page: page,
      scale: scale,
      margins: margins,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
    );
    final borderBehind = section.page.pageBorders.zOrder.toLowerCase() == 'back';

    // Keep the visual page border out of the child's layout metrics. A
    // Container with a BoxDecoration border contributes the border insets as
    // decoration padding; the Word column geometry below is intentionally
    // calculated against the full physical page width. Deflating the Stack by
    // one pixel on each side therefore made an exact-width multi-column row
    // overflow by 2 px at common zoom levels. DecoratedBox paints the same
    // border/shadow without changing the child's constraints.
    return SizedBox(
      key: const ValueKey('word-fidelity-page'),
      width: pageWidth,
      height: pageHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _hexColor(page.backgroundColorHex) ?? Colors.white,
          border: Border.all(color: const Color(0xFFD8DDE7)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 7,
              offset: Offset(0, 2),
              color: Color(0x1F000000),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87) ??
              const TextStyle(color: Colors.black87, fontSize: 14),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              if (borderBehind && pageBorder != null) pageBorder,
              for (final object in behind)
                _buildPositionedFloating(
                  object,
                  scale,
                  searchQuery,
                  pageNumber: page.displayPageNumber,
                  pageCount: pageCount,
                ),
              body,
              if (section.columns.separator && page.columns.length > 1)
                ..._columnSeparators(
                  columnWidths,
                  columnSpacings,
                  left: left,
                  top: top,
                  bottom: bottom,
                  scale: scale,
                  pageHeight: pageHeight,
                ),
              if (headerBlocks.isNotEmpty)
                Positioned(
                  left: left,
                  right: right,
                  top: math.max(0, section.page.headerDistancePoints * scale),
                  child: _WordBlockList(
                    key: page.absolutePageNumber == 1
                        ? const ValueKey('word-fidelity-header')
                        : ValueKey(
                            'word-fidelity-header-${page.pageIndexInSection}-${page.absolutePageNumber}',
                          ),
                    blocks: headerBlocks,
                    scale: scale,
                    searchQuery: searchQuery,
                    skipPageFloating: true,
                    pageNumber: page.displayPageNumber,
                    pageCount: pageCount,
                  ),
                ),
              if (noteReferences.isNotEmpty)
                Positioned(
                  key: const ValueKey('word-note-area'),
                  left: left,
                  right: right,
                  bottom: math.max(
                    bottom,
                    (section.page.footerDistancePoints + 18) * scale,
                  ),
                  child: _WordNoteArea(
                    notes: noteReferences,
                    scale: scale,
                    searchQuery: searchQuery,
                    pageNumber: page.displayPageNumber,
                    pageCount: pageCount,
                  ),
                ),
              if (footerBlocks.isNotEmpty)
                Positioned(
                  left: left,
                  right: right,
                  bottom: math.max(0, section.page.footerDistancePoints * scale),
                  child: _WordBlockList(
                    key: page.absolutePageNumber == 1
                        ? const ValueKey('word-fidelity-footer')
                        : ValueKey(
                            'word-fidelity-footer-${page.pageIndexInSection}-${page.absolutePageNumber}',
                          ),
                    blocks: footerBlocks,
                    scale: scale,
                    searchQuery: searchQuery,
                    skipPageFloating: true,
                    pageNumber: page.displayPageNumber,
                    pageCount: pageCount,
                  ),
                ),
              for (final object in inFront)
                _buildPositionedFloating(
                  object,
                  scale,
                  searchQuery,
                  pageNumber: page.displayPageNumber,
                  pageCount: pageCount,
                ),
              if (!borderBehind && pageBorder != null) pageBorder,
              if (page.isParityBlank)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: SizedBox.expand(
                      key: ValueKey('word-section-parity-blank-page'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

List<ConversionNoteReferenceRun> _collectNoteReferences(
  List<ConversionBlock> blocks,
) {
  final result = <ConversionNoteReferenceRun>[];
  final seen = <String>{};

  void visit(List<ConversionBlock> values) {
    for (final block in values) {
      if (block is ConversionParagraph) {
        for (final inline in block.inlines) {
          if (inline is ConversionNoteReferenceRun) {
            final key = '${inline.type.name}:${inline.noteId}';
            if (seen.add(key)) result.add(inline);
          } else if (inline is ConversionTextBoxRun) {
            visit(inline.blocks);
          } else if (inline is ConversionShapeRun) {
            visit(inline.blocks);
          }
        }
      } else if (block is ConversionOpaqueOoxmlBlock) {
        visit(block.fallbackBlocks);
      } else if (block is ConversionTable) {
        for (final row in block.rows) {
          for (final cell in row.cells) {
            visit(cell.blocks);
          }
        }
      }
    }
  }

  visit(blocks);
  return List<ConversionNoteReferenceRun>.unmodifiable(result);
}

class _WordNoteArea extends StatelessWidget {
  const _WordNoteArea({
    required this.notes,
    required this.scale,
    required this.searchQuery,
    required this.pageNumber,
    required this.pageCount,
  });

  final List<ConversionNoteReferenceRun> notes;
  final double scale;
  final String searchQuery;
  final int pageNumber;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: math.max(54, 170 * scale)),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF666666), width: 0.6)),
      ),
      padding: EdgeInsets.only(top: math.max(2, 4 * scale)),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          key: const ValueKey('word-footnote-endnote-list'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final note in notes)
              Padding(
                padding: EdgeInsets.only(bottom: math.max(1, 2 * scale)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: math.max(14, 18 * scale),
                      child: Text(
                        note.displayLabel ?? note.noteId,
                        key: ValueKey(
                          'word-${note.type.name}-reference-${note.noteId}',
                        ),
                        style: TextStyle(
                          fontSize: math.max(7, 8 * scale),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _WordBlockList(
                        blocks: note.blocks,
                        scale: math.max(0.65, scale * 0.78),
                        searchQuery: searchQuery,
                        skipPageFloating: true,
                        pageNumber: pageNumber,
                        pageCount: pageCount,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _columnSeparators(
  List<double> widths,
  List<double> spacings, {
  required double left,
  required double top,
  required double bottom,
  required double scale,
  required double pageHeight,
}) {
  final result = <Widget>[];
  var x = left;
  for (var index = 0; index < widths.length - 1; index++) {
    x += widths[index] * scale;
    final gap = spacings[math.min(index, spacings.length - 1)];
    final separatorX = x + gap * scale / 2;
    result.add(
      Positioned(
        key: ValueKey('word-column-separator-$index'),
        left: separatorX,
        top: top,
        height: math.max(0, pageHeight - top - bottom),
        child: Container(width: math.max(0.5, 0.75 * scale), color: Colors.black54),
      ),
    );
    x += gap * scale;
  }
  return result;
}

Widget? _pageBorderWidget(
  ConversionPageBorders pageBorders, {
  required _FidelityPage page,
  required double scale,
  required _EffectivePageMargins margins,
  required double pageWidth,
  required double pageHeight,
}) {
  if (pageBorders.isEmpty) return null;
  final display = pageBorders.display.toLowerCase();
  if (display == 'firstpage' && page.pageIndexInSection != 0) return null;
  if (display == 'notfirstpage' && page.pageIndexInSection == 0) return null;

  final fromText = pageBorders.offsetFrom.toLowerCase() == 'text';
  final left = fromText ? margins.left * scale : 0.0;
  final right = fromText ? margins.right * scale : 0.0;
  final top = fromText ? margins.top * scale : 0.0;
  final bottom = fromText ? margins.bottom * scale : 0.0;
  return Positioned(
    key: const ValueKey('word-page-border'),
    left: left,
    right: right,
    top: top,
    bottom: bottom,
    child: IgnorePointer(
      child: CustomPaint(
        foregroundPainter: _WordBorderPainter(
          pageBorders.borders,
          scale: scale,
          respectSideSpaceInsets: true,
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _WordBlockList extends StatelessWidget {
  const _WordBlockList({
    super.key,
    required this.blocks,
    required this.scale,
    required this.searchQuery,
    this.skipPageFloating = false,
    this.noWrapText = false,
    this.pageNumber = 1,
    this.pageCount = 1,
  });

  final List<ConversionBlock> blocks;
  final double scale;
  final String searchQuery;
  final bool skipPageFloating;
  final bool noWrapText;
  final int pageNumber;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      if (block is ConversionParagraph) {
        final previous = index > 0 ? blocks[index - 1] : null;
        final next = index + 1 < blocks.length ? blocks[index + 1] : null;
        final sameStyleAsPrevious = previous is ConversionParagraph &&
            previous.styleId == block.styleId;
        final sameStyleAsNext = next is ConversionParagraph &&
            next.styleId == block.styleId;
        final suppressBefore = block.contextualSpacing && sameStyleAsPrevious;
        final suppressAfter = block.contextualSpacing && sameStyleAsNext;
        final effectiveBorders = ConversionBorders(
          top: sameStyleAsPrevious ? null : block.borders.top,
          right: block.borders.right,
          bottom: sameStyleAsNext && (block.borders.between?.isVisible ?? false)
              ? block.borders.between
              : sameStyleAsNext
                  ? null
                  : block.borders.bottom,
          left: block.borders.left,
          insideHorizontal: block.borders.insideHorizontal,
          insideVertical: block.borders.insideVertical,
          between: block.borders.between,
          bar: block.borders.bar,
        );
        children.add(
          _WordParagraphView(
            paragraph: block,
            scale: scale,
            searchQuery: searchQuery,
            skipPageFloating: skipPageFloating,
            noWrapText: noWrapText,
            spaceBeforeOverride: suppressBefore ? 0 : null,
            spaceAfterOverride: suppressAfter ? 0 : null,
            bordersOverride: effectiveBorders,
            pageNumber: pageNumber,
            pageCount: pageCount,
          ),
        );
      } else if (block is ConversionOpaqueOoxmlBlock) {
        children.add(
          Container(
            key: ValueKey(
              'word-preserved-block-${block.featureKind}-$index',
            ),
            margin: EdgeInsets.symmetric(vertical: math.max(2, 4 * scale)),
            padding: EdgeInsets.all(math.max(4, 6 * scale)),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFB8C2CC), width: 0.8),
              borderRadius: BorderRadius.circular(math.max(3, 4 * scale)),
            ),
            child: block.fallbackBlocks.isNotEmpty
                ? _WordBlockList(
                    blocks: block.fallbackBlocks,
                    scale: scale,
                    searchQuery: searchQuery,
                    skipPageFloating: skipPageFloating,
                    pageNumber: pageNumber,
                    pageCount: pageCount,
                  )
                : Text(
                    '[Word ${block.featureKind} preserved]',
                    style: TextStyle(
                      fontSize: math.max(8, 9 * scale),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
          ),
        );
      } else if (block is ConversionTable) {
        children.add(
          _WordTableView(
            table: block,
            scale: scale,
            searchQuery: searchQuery,
            skipPageFloating: skipPageFloating,
            pageNumber: pageNumber,
            pageCount: pageCount,
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _WordParagraphView extends StatelessWidget {
  const _WordParagraphView({
    required this.paragraph,
    required this.scale,
    required this.searchQuery,
    required this.skipPageFloating,
    this.noWrapText = false,
    this.spaceBeforeOverride,
    this.spaceAfterOverride,
    this.bordersOverride,
    this.pageNumber = 1,
    this.pageCount = 1,
  });

  final ConversionParagraph paragraph;
  final double scale;
  final String searchQuery;
  final bool skipPageFloating;
  final bool noWrapText;
  final double? spaceBeforeOverride;
  final double? spaceAfterOverride;
  final ConversionBorders? bordersOverride;
  final int pageNumber;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final textRuns = <TextSpan>[];
    final paragraphHasTabs = (paragraph.listLabel?.contains('\t') ?? false) ||
        paragraph.inlines.whereType<ConversionTextRun>().any(
              (run) => run.text.contains('\t'),
            );

    void flushTextRuns() {
      if (textRuns.isEmpty) return;
      final exact = paragraph.exactLineSpacingPoints;
      Widget textWidget;
      if (_textSpansContainTab(textRuns)) {
        textWidget = _WordTabText(
          key: const ValueKey('word-tab-layout'),
          segments: _splitTextSpansAtTabs(textRuns),
          tabStops: paragraph.tabStops,
          firstSegmentOffsetPoints: math.max(
            0.0,
            paragraph.leftIndentPoints + paragraph.firstLineIndentPoints,
          ),
          scale: scale,
          minLineHeight: exact == null ? null : exact * scale,
          textDirection: Directionality.of(context),
        );
      } else {
        textWidget = RichText(
          textAlign: _alignment(paragraph.alignment),
          softWrap: !noWrapText,
          overflow: noWrapText ? TextOverflow.visible : TextOverflow.clip,
          strutStyle: exact == null
              ? null
              : StrutStyle(
                  fontSize: math.max(1, exact * scale),
                  height: 1,
                  forceStrutHeight: true,
                ),
          text: TextSpan(
            style: const TextStyle(color: Colors.black87),
            children: List<InlineSpan>.from(textRuns),
          ),
        );
      }

      final firstLineOffset = paragraphHasTabs
          ? 0.0
          : math.max(0.0, paragraph.firstLineIndentPoints * scale);
      children.add(
        firstLineOffset == 0
            ? textWidget
            : Padding(
                padding: EdgeInsets.only(left: firstLineOffset),
                child: textWidget,
              ),
      );
      textRuns.clear();
    }

    if (paragraph.listLabel?.isNotEmpty == true) {
      final markerStyle = paragraph.listLabelStyle ??
          const ConversionTextStyle(fontSizePoints: 11);
      textRuns.add(
        TextSpan(
          text: paragraph.listLabel,
          style: _runStyle(
            markerStyle,
            scale,
            lineHeight: paragraph.lineSpacingMultiple,
          ),
        ),
      );
    }

    for (final inline in paragraph.inlines) {
      if (inline is ConversionTextRun) {
        textRuns.addAll(
          _highlightedSpans(
            _displayRunText(inline.text, inline.style),
            _runStyle(
              inline.style,
              scale,
              lineHeight: paragraph.lineSpacingMultiple,
            ),
            searchQuery,
          ).whereType<TextSpan>(),
        );
      } else if (inline is ConversionDynamicFieldRun) {
        final text = inline.field == ConversionDynamicField.pageNumber
            ? pageNumber.toString()
            : pageCount.toString();
        textRuns.add(
          TextSpan(
            text: text,
            style: _runStyle(
              inline.style,
              scale,
              lineHeight: paragraph.lineSpacingMultiple,
            ),
          ),
        );
      } else if (inline is ConversionFieldRun) {
        final visible = inline.resultText.isNotEmpty
            ? inline.resultText
            : '{${inline.fieldName.isEmpty ? 'FIELD' : inline.fieldName}}';
        textRuns.add(
          TextSpan(
            text: visible,
            style: _runStyle(
              inline.style,
              scale,
              lineHeight: paragraph.lineSpacingMultiple,
            ),
          ),
        );
      } else if (inline is ConversionMathRun) {
        textRuns.add(
          TextSpan(
            text: inline.plainText.isEmpty ? '∑' : inline.plainText,
            style: _runStyle(
              inline.style,
              scale,
              lineHeight: paragraph.lineSpacingMultiple,
            ).copyWith(fontFamily: 'Cambria Math'),
          ),
        );
      } else if (inline is ConversionNoteReferenceRun) {
        textRuns.add(
          TextSpan(
            text: _superscript(inline.displayLabel ?? inline.noteId),
            style: _runStyle(
              inline.style,
              scale,
              lineHeight: paragraph.lineSpacingMultiple,
            ).copyWith(
              fontSize: math.max(7, inline.style.fontSizePoints * scale * 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else if (inline is ConversionCommentMarkerRun ||
          inline is ConversionBookmarkMarkerRun) {
        // Comments/bookmarks are non-printing anchors in Word. The canonical
        // model keeps them for navigation/review and DOCX round-trip without
        // injecting visible placeholder text into the fidelity viewer.
      } else if (inline is ConversionOpaqueOoxmlRun) {
        final fallback = inline.fallbackText.trim();
        textRuns.add(
          TextSpan(
            text: fallback.isEmpty
                ? '[Word ${inline.featureKind} preserved]'
                : fallback,
            style: _runStyle(
              inline.style,
              scale,
              lineHeight: paragraph.lineSpacingMultiple,
            ).copyWith(
              decoration: fallback.isEmpty ? TextDecoration.underline : null,
              decorationStyle: TextDecorationStyle.dotted,
            ),
          ),
        );
      } else if (inline is ConversionTextBoxRun) {
        if (skipPageFloating && inline.placement.isViewerPositioned) continue;
        flushTextRuns();
        children.add(
          _inlineTextBox(
            inline,
            scale: scale,
            searchQuery: searchQuery,
            alignment: paragraph.alignment,
            skipPageFloating: skipPageFloating,
            pageNumber: pageNumber,
            pageCount: pageCount,
          ),
        );
      } else if (inline is ConversionShapeRun) {
        if (skipPageFloating && inline.placement.isViewerPositioned) continue;
        flushTextRuns();
        children.add(
          Align(
            alignment: _inlineAlignment(paragraph.alignment),
            child: _shapeWidget(
              inline,
              scale: scale,
              searchQuery: searchQuery,
              skipPageFloating: skipPageFloating,
              pageNumber: pageNumber,
              pageCount: pageCount,
            ),
          ),
        );
      } else if (inline is ConversionImageRun) {
        if (skipPageFloating && inline.placement.isViewerPositioned) continue;
        flushTextRuns();
        children.add(
          Align(
            alignment: _inlineAlignment(paragraph.alignment),
            child: _imageWidget(inline, scale),
          ),
        );
      }
    }
    flushTextRuns();

    final effectiveBorders = bordersOverride ?? paragraph.borders;
    final borderSpace = EdgeInsets.fromLTRB(
      math.max(0, (effectiveBorders.left?.spacePoints ?? 0) * scale),
      math.max(0, (effectiveBorders.top?.spacePoints ?? 0) * scale),
      math.max(0, (effectiveBorders.right?.spacePoints ?? 0) * scale),
      math.max(0, (effectiveBorders.bottom?.spacePoints ?? 0) * scale),
    );

    Widget content = children.isEmpty
        ? SizedBox(height: 11 * scale)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          );
    if (borderSpace != EdgeInsets.zero) {
      content = Padding(padding: borderSpace, child: content);
    }
    final paragraphShading = _hexColor(paragraph.shadingHex);
    if (paragraphShading != null) {
      content = ColoredBox(
        key: const ValueKey('word-paragraph-shading'),
        color: paragraphShading,
        child: content,
      );
    }
    if (!effectiveBorders.isEmpty) {
      content = CustomPaint(
        key: const ValueKey('word-paragraph-border'),
        foregroundPainter: _WordBorderPainter(
          effectiveBorders,
          scale: scale,
        ),
        child: content,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidthPoints = constraints.maxWidth.isFinite
            ? math.max(8.0, constraints.maxWidth / math.max(0.001, scale))
            : 612.0;
        final reservation = _paragraphWrapReservation(
          paragraph,
          availableWidthPoints,
        );
        Widget wrappedContent = content;
        if (reservation.topInsetPoints > 0 ||
            reservation.leftInsetPoints > 0 ||
            reservation.rightInsetPoints > 0) {
          wrappedContent = Padding(
            key: const ValueKey('word-anchor-wrap-reservation'),
            padding: EdgeInsets.only(
              top: reservation.topInsetPoints * scale,
              left: reservation.leftInsetPoints * scale,
              right: reservation.rightInsetPoints * scale,
            ),
            child: wrappedContent,
          );
        }
        if (reservation.minimumHeightPoints > 0) {
          wrappedContent = ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: reservation.minimumHeightPoints * scale,
            ),
            child: wrappedContent,
          );
        }
        return Padding(
          padding: EdgeInsets.only(
            top: (spaceBeforeOverride ?? paragraph.spaceBeforePoints) * scale,
            bottom:
                (spaceAfterOverride ?? paragraph.spaceAfterPoints) * scale,
            left: paragraphHasTabs
                ? 0
                : math.max(0, paragraph.leftIndentPoints * scale),
            right: math.max(0, paragraph.rightIndentPoints * scale),
          ),
          child: wrappedContent,
        );
      },
    );
  }
}

class _WordTableView extends StatelessWidget {
  const _WordTableView({
    required this.table,
    required this.scale,
    required this.searchQuery,
    required this.skipPageFloating,
    this.pageNumber = 1,
    this.pageCount = 1,
  });

  final ConversionTable table;
  final double scale;
  final String searchQuery;
  final bool skipPageFloating;
  final int pageNumber;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    final fragmentMeta = _tableFlowFragmentMeta[table];
    final alignment = switch (table.alignment) {
      ConversionTextAlignment.center => Alignment.center,
      ConversionTextAlignment.right => Alignment.centerRight,
      _ => Alignment.centerLeft,
    };

    final rows = Container(
      key: ObjectKey(table),
      color: _hexColor(table.shadingHex),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var rowIndex = 0;
              rowIndex < table.rows.length;
              rowIndex++)
            _WordTableRowView(
              table: table,
              row: table.rows[rowIndex],
              rowIndex: rowIndex,
              scale: scale,
              searchQuery: searchQuery,
              skipPageFloating: skipPageFloating,
              pageNumber: pageNumber,
              pageCount: pageCount,
              suppressTopBorder:
                  fragmentMeta?.hasPrevious == true && rowIndex == 0,
              suppressBottomBorder: fragmentMeta?.hasNext == true &&
                  rowIndex == table.rows.length - 1,
            ),
        ],
      ),
    );

    Widget content;
    final widthPercent = table.widthPercent;
    final widthPoints = table.widthPoints;

    if (widthPercent != null) {
      content = FractionallySizedBox(
        alignment: alignment,
        widthFactor: (widthPercent / 100).clamp(0.01, 1.0).toDouble(),
        child: rows,
      );
    } else if (widthPoints != null && widthPoints > 0) {
      content = Align(
        alignment: alignment,
        child: SizedBox(
          width: math.max(1.0, widthPoints * scale),
          child: rows,
        ),
      );
    } else {
      content = rows;
    }

    return Padding(
      padding: EdgeInsets.only(
        top: fragmentMeta?.hasPrevious == true ? 0 : 2 * scale,
        bottom: fragmentMeta?.hasNext == true ? 0 : 2 * scale,
        left: math.max(0.0, table.indentPoints * scale),
      ),
      child: content,
    );
  }
}

class _WordTableRowView extends StatelessWidget {
  const _WordTableRowView({
    required this.table,
    required this.row,
    required this.rowIndex,
    required this.scale,
    required this.searchQuery,
    required this.skipPageFloating,
    this.pageNumber = 1,
    this.pageCount = 1,
    this.suppressTopBorder = false,
    this.suppressBottomBorder = false,
  });

  final ConversionTable table;
  final ConversionTableRow row;
  final int rowIndex;
  final double scale;
  final String searchQuery;
  final bool skipPageFloating;
  final int pageNumber;
  final int pageCount;
  final bool suppressTopBorder;
  final bool suppressBottomBorder;

  @override
  Widget build(BuildContext context) {
    final flexes = _cellFlexes(table, row);
    final spacing = math.max(0.0, table.cellSpacingPoints * scale);
    Widget rowWidget = _WordEqualHeightRow(
      flexes: flexes,
      spacing: spacing,
      children: [
        for (var i = 0; i < row.cells.length; i++)
          _WordTableCellView(
            cell: row.cells[i],
            scale: scale,
            searchQuery: searchQuery,
            showBorder: table.showBorders,
            skipPageFloating: skipPageFloating,
            rowIndex: rowIndex,
            cellIndex: i,
            pageNumber: pageNumber,
            pageCount: pageCount,
            suppressTopBorder: suppressTopBorder,
            suppressBottomBorder: suppressBottomBorder,
          ),
      ],
    );

    final height = row.heightPoints;
    if (height != null && height > 0) {
      final pixels = height * scale;
      rowWidget = row.heightRule == ConversionTableRowHeightRule.exact
          ? SizedBox(height: pixels, child: rowWidget)
          : ConstrainedBox(
              constraints: BoxConstraints(minHeight: pixels),
              child: rowWidget,
            );
    }
    return rowWidget;
  }
}


class _WordEqualHeightRow extends MultiChildRenderObjectWidget {
  const _WordEqualHeightRow({
    required this.flexes,
    required this.spacing,
    required super.children,
  });

  final List<int> flexes;
  final double spacing;

  @override
  rendering.RenderObject createRenderObject(BuildContext context) =>
      _RenderWordEqualHeightRow(
        flexes: flexes,
        spacing: spacing,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderWordEqualHeightRow renderObject,
  ) {
    renderObject
      ..flexes = flexes
      ..spacing = spacing;
  }
}

class _WordEqualHeightParentData
    extends rendering.ContainerBoxParentData<rendering.RenderBox> {}

class _RenderWordEqualHeightRow extends rendering.RenderBox
    with
        rendering.ContainerRenderObjectMixin<
          rendering.RenderBox,
          _WordEqualHeightParentData
        >,
        rendering.RenderBoxContainerDefaultsMixin<
          rendering.RenderBox,
          _WordEqualHeightParentData
        > {
  _RenderWordEqualHeightRow({
    required List<int> flexes,
    required double spacing,
  })  : _flexes = List<int>.from(flexes),
        _spacing = spacing;

  List<int> _flexes;
  double _spacing;

  set flexes(List<int> value) {
    if (_listEquals(_flexes, value)) return;
    _flexes = List<int>.from(value);
    markNeedsLayout();
  }

  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void setupParentData(rendering.RenderBox child) {
    if (child.parentData is! _WordEqualHeightParentData) {
      child.parentData = _WordEqualHeightParentData();
    }
  }

  @override
  void performLayout() {
    final count = childCount;
    if (count == 0) {
      size = constraints.constrain(Size.zero);
      return;
    }

    final boundedWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : math.max(constraints.minWidth, count * 100.0);
    final gap = math.max(0.0, _spacing);
    final usableWidth = math.max(0.0, boundedWidth - gap * (count - 1));
    var totalFlex = 0;
    for (var i = 0; i < count; i++) {
      totalFlex += i < _flexes.length ? math.max(1, _flexes[i]) : 1;
    }
    totalFlex = math.max(1, totalFlex);

    final widths = <double>[];
    var maxChildHeight = 0.0;
    var child = firstChild;
    var index = 0;
    while (child != null) {
      final flex = index < _flexes.length ? math.max(1, _flexes[index]) : 1;
      final width = usableWidth * flex / totalFlex;
      widths.add(width);
      child.layout(
        BoxConstraints(
          minWidth: width,
          maxWidth: width,
          minHeight: 0,
          maxHeight: double.infinity,
        ),
        parentUsesSize: true,
      );
      maxChildHeight = math.max(maxChildHeight, child.size.height);
      final parentData = child.parentData! as _WordEqualHeightParentData;
      child = parentData.nextSibling;
      index++;
    }

    final targetHeight = constraints.constrainHeight(maxChildHeight);
    final targetWidth = constraints.constrainWidth(boundedWidth);
    var x = 0.0;
    child = firstChild;
    index = 0;
    while (child != null) {
      final width = widths[index];
      child.layout(
        BoxConstraints.tightFor(width: width, height: targetHeight),
        parentUsesSize: true,
      );
      final parentData = child.parentData! as _WordEqualHeightParentData;
      parentData.offset = Offset(x, 0);
      x += width + gap;
      child = parentData.nextSibling;
      index++;
    }

    size = Size(targetWidth, targetHeight);
  }

  @override
  void paint(rendering.PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(
    rendering.BoxHitTestResult result, {
    required Offset position,
  }) =>
      defaultHitTestChildren(result, position: position);
}

class _WordTableCellView extends StatelessWidget {
  const _WordTableCellView({
    required this.cell,
    required this.scale,
    required this.searchQuery,
    required this.showBorder,
    required this.skipPageFloating,
    required this.rowIndex,
    required this.cellIndex,
    this.pageNumber = 1,
    this.pageCount = 1,
    this.suppressTopBorder = false,
    this.suppressBottomBorder = false,
  });

  final ConversionTableCell cell;
  final double scale;
  final String searchQuery;
  final bool showBorder;
  final bool skipPageFloating;
  final int rowIndex;
  final int cellIndex;
  final int pageNumber;
  final int pageCount;
  final bool suppressTopBorder;
  final bool suppressBottomBorder;

  @override
  Widget build(BuildContext context) {
    final isContinuation =
        cell.verticalMerge == ConversionVerticalMerge.continuation;
    final alignment = switch (cell.verticalAlignment) {
      ConversionTableCellVerticalAlignment.center => Alignment.centerLeft,
      ConversionTableCellVerticalAlignment.bottom => Alignment.bottomLeft,
      ConversionTableCellVerticalAlignment.top => Alignment.topLeft,
    };

    var effectiveBorders = cell.borders;
    if (effectiveBorders.isEmpty && showBorder) {
      const fallback = ConversionBorderSide(
        style: ConversionBorderStyle.single,
        widthPoints: 0.7,
        colorHex: 'B9BEC9',
      );
      effectiveBorders = const ConversionBorders(
        top: fallback,
        right: fallback,
        bottom: fallback,
        left: fallback,
      );
    }
    if (suppressTopBorder || suppressBottomBorder) {
      effectiveBorders = ConversionBorders(
        top: suppressTopBorder ? null : effectiveBorders.top,
        right: effectiveBorders.right,
        bottom: suppressBottomBorder ? null : effectiveBorders.bottom,
        left: effectiveBorders.left,
        insideHorizontal: effectiveBorders.insideHorizontal,
        insideVertical: effectiveBorders.insideVertical,
        between: effectiveBorders.between,
        bar: effectiveBorders.bar,
      );
    }

    final content = Container(
      key: ValueKey('word-table-cell-$rowIndex-$cellIndex-span-${cell.gridSpan}'),
      color: _hexColor(cell.shadingHex),
      padding: EdgeInsets.fromLTRB(
        math.max(0, cell.paddingLeftPoints * scale),
        suppressTopBorder ? 0 : math.max(0, cell.paddingTopPoints * scale),
        math.max(0, cell.paddingRightPoints * scale),
        suppressBottomBorder ? 0 : math.max(0, cell.paddingBottomPoints * scale),
      ),
      child: Align(
        alignment: alignment,
        child: isContinuation
            ? const SizedBox.shrink()
            : SizedBox(
                width: double.infinity,
                child: _WordBlockList(
                  blocks: cell.blocks,
                  scale: scale,
                  searchQuery: searchQuery,
                  skipPageFloating: skipPageFloating,
                  noWrapText: cell.noWrap,
                  pageNumber: pageNumber,
                  pageCount: pageCount,
                ),
              ),
      ),
    );

    if (effectiveBorders.isEmpty) return content;
    return CustomPaint(
      key: ValueKey('word-table-cell-border-$rowIndex-$cellIndex'),
      foregroundPainter: _WordBorderPainter(
        effectiveBorders,
        scale: scale,
      ),
      child: content,
    );
  }
}

class _FloatingObject {
  const _FloatingObject({
    required this.inline,
    required this.placement,
    required this.anchorTopPoints,
    required this.stableIndex,
    this.flowColumnIndex,
  });

  final ConversionInline inline;
  final ConversionObjectPlacement placement;
  final int? flowColumnIndex;

  /// Absolute page-space Y coordinate of the paragraph/row that owns this
  /// anchor, in Word points. Page/margin anchored objects ignore this value;
  /// paragraph/line/character anchored objects use it as their vertical origin.
  final double anchorTopPoints;

  /// Stable page-local identity used for deterministic z-order/widget keys.
  final int stableIndex;
}

class _ResolvedFloatingObject {
  const _ResolvedFloatingObject({
    required this.object,
    required this.left,
    required this.top,
    required this.size,
  });

  final _FloatingObject object;
  final double left;
  final double top;
  final Size size;

  Rect get rect => Rect.fromLTWH(left, top, size.width, size.height);
}

List<_FloatingObject> _collectFloating(
  List<ConversionBlock> blocks, {
  int? flowColumnIndex,
  required double flowWidthPoints,
  required double anchorBaseTopPoints,
  int stableIndexSeed = 0,
}) {
  final result = <_FloatingObject>[];
  var nextStableIndex = stableIndexSeed;

  void addObject(
    ConversionInline inline,
    ConversionObjectPlacement placement,
    double anchorTopPoints,
  ) {
    result.add(
      _FloatingObject(
        inline: inline,
        placement: placement,
        flowColumnIndex: flowColumnIndex,
        anchorTopPoints: anchorTopPoints,
        stableIndex: nextStableIndex++,
      ),
    );
  }

  void visit(
    List<ConversionBlock> items,
    double widthPoints,
    double localBaseTopPoints,
  ) {
    var used = 0.0;
    for (var blockIndex = 0; blockIndex < items.length; blockIndex++) {
      final block = items[blockIndex];
      final blockTop = localBaseTopPoints + used;
      if (block is ConversionParagraph) {
        for (final inline in block.inlines) {
          if (inline is ConversionImageRun && inline.placement.isViewerPositioned) {
            addObject(inline, inline.placement, blockTop);
          } else if (inline is ConversionTextBoxRun) {
            if (inline.placement.isViewerPositioned) {
              addObject(inline, inline.placement, blockTop);
            }
            visit(
              inline.blocks,
              math.max(24.0, inline.widthPoints ?? widthPoints),
              blockTop,
            );
          } else if (inline is ConversionShapeRun) {
            if (inline.placement.isViewerPositioned) {
              addObject(inline, inline.placement, blockTop);
            }
            visit(
              inline.blocks,
              math.max(24.0, inline.widthPoints),
              blockTop,
            );
          }
        }
      } else if (block is ConversionOpaqueOoxmlBlock) {
        visit(block.fallbackBlocks, widthPoints, blockTop);
      } else if (block is ConversionTable) {
        // Cell-relative anchors are approximated from the table's page-flow Y
        // position. This is materially closer to Word than degrading them to
        // inline content, while `layoutInCell` continues to preserve the
        // object's table ownership in the canonical model/export path.
        for (final row in block.rows) {
          final cellWidths = _estimatedTableCellWidths(block, row, widthPoints);
          for (var cellIndex = 0; cellIndex < row.cells.length; cellIndex++) {
            final cell = row.cells[cellIndex];
            final cellWidth = cellIndex < cellWidths.length
                ? cellWidths[cellIndex]
                : widthPoints / math.max(1, row.cells.length);
            visit(
              cell.blocks,
              _cellInnerWidthPoints(cell, cellWidth),
              blockTop + cell.paddingTopPoints,
            );
          }
        }
      }
      used += _estimateBlockHeightInSequence(items, blockIndex, widthPoints);
    }
  }

  visit(blocks, flowWidthPoints, anchorBaseTopPoints);
  return result;
}

List<_ResolvedFloatingObject> _resolveFloatingObjects(
  List<_FloatingObject> objects,
  double scale,
  double pageWidth,
  double pageHeight,
  _EffectivePageMargins margins, {
  required List<double> columnWidthsPoints,
  required List<double> columnSpacingsPoints,
}) {
  final resolved = <_ResolvedFloatingObject>[];
  for (final object in objects) {
    final size = _floatingSize(object.inline, scale);
    var left = _horizontalPosition(
      object.placement,
      scale,
      pageWidth,
      size.width,
      margins,
      flowColumnIndex: object.flowColumnIndex,
      columnWidthsPoints: columnWidthsPoints,
      columnSpacingsPoints: columnSpacingsPoints,
    );
    var top = _verticalPosition(
      object.placement,
      scale,
      pageHeight,
      size.height,
      margins,
      anchorTopPoints: object.anchorTopPoints,
    );

    if (!object.placement.allowOverlap && size.width > 0 && size.height > 0) {
      var guard = 0;
      while (guard++ < 128) {
        final expanded = Rect.fromLTWH(
          left - object.placement.distanceLeftPoints * scale,
          top - object.placement.distanceTopPoints * scale,
          size.width +
              (object.placement.distanceLeftPoints +
                      object.placement.distanceRightPoints) *
                  scale,
          size.height +
              (object.placement.distanceTopPoints +
                      object.placement.distanceBottomPoints) *
                  scale,
        );
        final collision = resolved.where((candidate) {
          final candidatePlacement = candidate.object.placement;
          if (candidatePlacement.behindText != object.placement.behindText) {
            return false;
          }
          return expanded.overlaps(candidate.rect);
        }).firstOrNull;
        if (collision == null) break;
        top = collision.rect.bottom +
            math.max(1.0, object.placement.distanceTopPoints * scale);
      }
    }

    // Word lets objects extend into page margins, but not infinitely outside
    // the physical sheet. Clamp only the fully-off-page cases and preserve
    // partial bleed/crop behavior.
    left = left.clamp(-size.width + 1, pageWidth - 1).toDouble();
    top = top.clamp(-size.height + 1, pageHeight - 1).toDouble();
    resolved.add(
      _ResolvedFloatingObject(
        object: object,
        left: left,
        top: top,
        size: size,
      ),
    );
  }
  return List<_ResolvedFloatingObject>.unmodifiable(resolved);
}

Widget _buildPositionedFloating(
  _ResolvedFloatingObject resolved,
  double scale,
  String searchQuery, {
  required int pageNumber,
  required int pageCount,
}) {
  final object = resolved.object;
  return Positioned(
    key: ValueKey('word-floating-${object.stableIndex}-${object.placement.relativeHeight}'),
    left: resolved.left,
    top: resolved.top,
    child: switch (object.inline) {
      ConversionImageRun image => _imageWidget(image, scale),
      ConversionTextBoxRun textBox => _textBoxWidget(
          textBox,
          scale: scale,
          searchQuery: searchQuery,
          skipPageFloating: true,
          pageNumber: pageNumber,
          pageCount: pageCount,
        ),
      ConversionShapeRun shape => _shapeWidget(
          shape,
          scale: scale,
          searchQuery: searchQuery,
          skipPageFloating: true,
          pageNumber: pageNumber,
          pageCount: pageCount,
        ),
      _ => const SizedBox.shrink(),
    },
  );
}

Size _floatingSize(ConversionInline inline, double scale) {
  if (inline is ConversionImageRun) {
    return Size(
      math.max(1, inline.widthPoints) * scale,
      math.max(1, inline.heightPoints) * scale,
    );
  }
  if (inline is ConversionTextBoxRun) {
    return Size(
      math.max(1, inline.widthPoints ?? 160) * scale,
      math.max(1, inline.heightPoints ?? 80) * scale,
    );
  }
  if (inline is ConversionShapeRun) {
    return Size(
      math.max(1, inline.widthPoints) * scale,
      math.max(1, inline.heightPoints) * scale,
    );
  }
  return Size.zero;
}

double _horizontalPosition(
  ConversionObjectPlacement placement,
  double scale,
  double pageWidth,
  double objectWidth,
  _EffectivePageMargins margins, {
  int? flowColumnIndex,
  required List<double> columnWidthsPoints,
  required List<double> columnSpacingsPoints,
}) {
  final relative = placement.horizontalRelativeFrom?.toLowerCase();
  final usesPage = relative == 'page';
  final useRightMargin = relative == 'rightmargin' || relative == 'outsidemargin';

  double origin;
  double areaWidth;
  if ((relative == 'column' ||
          relative == 'paragraph' ||
          relative == 'character') &&
      flowColumnIndex != null &&
      columnWidthsPoints.isNotEmpty) {
    final columnIndex = flowColumnIndex
        .clamp(0, columnWidthsPoints.length - 1)
        .toInt();
    origin = margins.left * scale;
    for (var index = 0; index < columnIndex; index++) {
      origin += columnWidthsPoints[index] * scale;
      if (index < columnSpacingsPoints.length) {
        origin += columnSpacingsPoints[index] * scale;
      }
    }
    areaWidth = columnWidthsPoints[columnIndex] * scale;
  } else {
    origin = usesPage
        ? 0.0
        : useRightMargin
            ? pageWidth - margins.right * scale
            : margins.left * scale;
    areaWidth = usesPage
        ? pageWidth
        : (relative == 'leftmargin' ||
                relative == 'rightmargin' ||
                relative == 'insidemargin' ||
                relative == 'outsidemargin')
            ? math.max(
                0,
                (useRightMargin ? margins.right : margins.left) * scale,
              )
            : math.max(
                0,
                pageWidth - (margins.left + margins.right) * scale,
              );
  }
  final alignment = placement.horizontalAlignment?.toLowerCase();
  final aligned = switch (alignment) {
    'center' => origin + (areaWidth - objectWidth) / 2,
    'right' || 'outside' => origin + areaWidth - objectWidth,
    _ => origin,
  };
  return aligned + (placement.horizontalOffsetPoints ?? 0) * scale;
}

double _verticalPosition(
  ConversionObjectPlacement placement,
  double scale,
  double pageHeight,
  double objectHeight,
  _EffectivePageMargins margins, {
  required double anchorTopPoints,
}) {
  final relative = placement.verticalRelativeFrom?.toLowerCase();
  final usesPage = relative == 'page';
  final useBottomMargin = relative == 'bottommargin' || relative == 'outsidemargin';
  final usesFlowAnchor = relative == 'paragraph' ||
      relative == 'line' ||
      relative == 'character';
  final origin = usesFlowAnchor
      ? anchorTopPoints * scale
      : usesPage
          ? 0.0
          : useBottomMargin
              ? pageHeight - margins.bottom * scale
              : margins.top * scale;
  final areaHeight = usesFlowAnchor
      ? math.max(0, pageHeight - origin - margins.bottom * scale)
      : usesPage
          ? pageHeight
          : (relative == 'topmargin' ||
                  relative == 'bottommargin' ||
                  relative == 'insidemargin' ||
                  relative == 'outsidemargin')
              ? math.max(
                  0,
                  (useBottomMargin ? margins.bottom : margins.top) * scale,
                )
              : math.max(
                  0,
                  pageHeight - (margins.top + margins.bottom) * scale,
                );
  final alignment = placement.verticalAlignment?.toLowerCase();
  final aligned = switch (alignment) {
    'center' => origin + (areaHeight - objectHeight) / 2,
    'bottom' || 'outside' => origin + areaHeight - objectHeight,
    _ => origin,
  };
  return aligned + (placement.verticalOffsetPoints ?? 0) * scale;
}

Widget _inlineTextBox(
  ConversionTextBoxRun inline, {
  required double scale,
  required String searchQuery,
  required ConversionTextAlignment alignment,
  required bool skipPageFloating,
  int pageNumber = 1,
  int pageCount = 1,
}) {
  return Align(
    alignment: _inlineAlignment(alignment),
    child: _textBoxWidget(
      inline,
      scale: scale,
      searchQuery: searchQuery,
      skipPageFloating: skipPageFloating,
      pageNumber: pageNumber,
      pageCount: pageCount,
    ),
  );
}

Widget _textBoxWidget(
  ConversionTextBoxRun inline, {
  required double scale,
  required String searchQuery,
  required bool skipPageFloating,
  int pageNumber = 1,
  int pageCount = 1,
}) {
  final content = Padding(
    padding: EdgeInsets.fromLTRB(
      math.max(0, inline.paddingLeftPoints * scale),
      math.max(0, inline.paddingTopPoints * scale),
      math.max(0, inline.paddingRightPoints * scale),
      math.max(0, inline.paddingBottomPoints * scale),
    ),
    child: _WordBlockList(
      blocks: inline.blocks,
      scale: scale,
      searchQuery: searchQuery,
      skipPageFloating: skipPageFloating,
      pageNumber: pageNumber,
      pageCount: pageCount,
    ),
  );
  if (inline.widthPoints == null && inline.heightPoints == null) return content;
  return SizedBox(
    width: inline.widthPoints == null ? null : inline.widthPoints! * scale,
    height: inline.heightPoints == null ? null : inline.heightPoints! * scale,
    child: content,
  );
}

Widget _shapeWidget(
  ConversionShapeRun inline, {
  required double scale,
  required String searchQuery,
  required bool skipPageFloating,
  int pageNumber = 1,
  int pageCount = 1,
}) {
  final width = math.max(1.0, inline.widthPoints * scale);
  final height = math.max(1.0, inline.heightPoints * scale);
  Widget content = CustomPaint(
    key: const ValueKey('word-shape-visual'),
    painter: _WordShapePainter(inline, scale: scale),
    child: inline.blocks.isEmpty
        ? SizedBox(width: width, height: height)
        : SizedBox(
            width: width,
            height: height,
            child: Padding(
              padding: EdgeInsets.all(math.max(2.0, 4 * scale)),
              child: _WordBlockList(
                blocks: inline.blocks,
                scale: scale,
                searchQuery: searchQuery,
                skipPageFloating: skipPageFloating,
                pageNumber: pageNumber,
                pageCount: pageCount,
              ),
            ),
          ),
  );
  if (inline.style.flipHorizontal || inline.style.flipVertical) {
    content = Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(
        inline.style.flipHorizontal ? -1.0 : 1.0,
        inline.style.flipVertical ? -1.0 : 1.0,
        1,
      ),
      child: content,
    );
  }
  if (inline.style.rotationDegrees != 0) {
    content = Transform.rotate(
      angle: inline.style.rotationDegrees * math.pi / 180,
      alignment: Alignment.center,
      child: content,
    );
  }
  return SizedBox(width: width, height: height, child: content);
}

class _WordShapePainter extends CustomPainter {
  const _WordShapePainter(this.shape, {required this.scale});

  final ConversionShapeRun shape;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final style = shape.style;
    final fill = _hexColor(style.fillColorHex);
    final stroke = _hexColor(style.strokeColorHex) ?? Colors.black87;
    final strokeWidth = math.max(0.5, style.strokeWidthPoints * scale);
    final fillPaint = fill == null
        ? null
        : (Paint()
          ..color = fill
          ..style = PaintingStyle.fill);
    final strokePaint = Paint()
      ..color = stroke
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      math.max(0, size.width - strokeWidth),
      math.max(0, size.height - strokeWidth),
    );

    late final Path path;
    var closed = true;
    switch (shape.kind) {
      case ConversionShapeKind.ellipse:
        path = Path()..addOval(rect);
        break;
      case ConversionShapeKind.roundedRectangle:
        final radius = Radius.circular(math.min(size.width, size.height) * 0.12);
        path = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));
        break;
      case ConversionShapeKind.line:
        path = Path()
          ..moveTo(rect.left, rect.top)
          ..lineTo(rect.right, rect.bottom);
        closed = false;
        break;
      case ConversionShapeKind.textPath:
        // WordArt/text watermarks carry their visible glyphs in the nested
        // text-path content. Painting a fallback rectangle would turn a
        // watermark into a large box, so geometry stays transparent here.
        return;
      case ConversionShapeKind.rectangle:
      case ConversionShapeKind.unknown:
        path = Path()..addRect(rect);
        break;
    }

    if (closed && fillPaint != null) canvas.drawPath(path, fillPaint);
    _drawWordShapeStroke(
      canvas,
      path,
      strokePaint,
      style.dashStyle,
      scale,
    );
  }

  @override
  bool shouldRepaint(covariant _WordShapePainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.scale != scale;
}

void _drawWordShapeStroke(
  Canvas canvas,
  Path path,
  Paint paint,
  String? rawDashStyle,
  double scale,
) {
  final dashStyle = rawDashStyle?.trim().toLowerCase();
  if (dashStyle == null ||
      dashStyle.isEmpty ||
      dashStyle == 'solid') {
    canvas.drawPath(path, paint);
    return;
  }

  final pattern = switch (dashStyle) {
    'dot' || 'sysdot' => <double>[1.0, 2.2],
    'dashdot' || 'sysdashdot' => <double>[5.0, 2.5, 1.0, 2.5],
    'lgdashdot' => <double>[8.0, 2.8, 1.0, 2.8],
    'lgdashdotdot' || 'sysdashdotdot' =>
      <double>[8.0, 2.5, 1.0, 2.5, 1.0, 2.5],
    'lgdash' => <double>[8.0, 3.0],
    _ => <double>[5.0, 3.0],
  };
  final scaled = pattern
      .map((value) => math.max(0.8, value * math.max(0.5, scale)))
      .toList(growable: false);

  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    var patternIndex = 0;
    while (distance < metric.length) {
      final length = scaled[patternIndex % scaled.length];
      final next = math.min(metric.length, distance + length);
      if (patternIndex.isEven) {
        canvas.drawPath(metric.extractPath(distance, next), paint);
      }
      distance = next;
      patternIndex++;
    }
  }
}

Widget _imageWidget(ConversionImageRun inline, double scale) {
  final sourceWidth = inline.widthPoints <= 0 ? 160.0 : inline.widthPoints;
  final sourceHeight = inline.heightPoints <= 0 ? 120.0 : inline.heightPoints;
  final frameWidth = math.max(1.0, sourceWidth * scale);
  final frameHeight = math.max(1.0, sourceHeight * scale);
  final crop = inline.crop;

  Widget image;
  if (crop.isEmpty) {
    image = Image.memory(
      Uint8List.fromList(inline.bytes),
      width: frameWidth,
      height: frameHeight,
      fit: BoxFit.fill,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  } else {
    final visibleWidth = crop.visibleWidth;
    final visibleHeight = crop.visibleHeight;
    final expandedWidth = frameWidth / visibleWidth;
    final expandedHeight = frameHeight / visibleHeight;
    image = ClipRect(
      key: const ValueKey('word-image-crop-clip'),
      child: SizedBox(
        width: frameWidth,
        height: frameHeight,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: -crop.left * expandedWidth,
              top: -crop.top * expandedHeight,
              width: expandedWidth,
              height: expandedHeight,
              child: Image.memory(
                Uint8List.fromList(inline.bytes),
                width: expandedWidth,
                height: expandedHeight,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  if (inline.flipHorizontal || inline.flipVertical) {
    image = Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(
        inline.flipHorizontal ? -1.0 : 1.0,
        inline.flipVertical ? -1.0 : 1.0,
        1,
      ),
      child: image,
    );
  }
  if (inline.rotationDegrees != 0) {
    image = Transform.rotate(
      angle: inline.rotationDegrees * math.pi / 180,
      alignment: Alignment.center,
      child: image,
    );
  }

  return SizedBox(
    width: frameWidth,
    height: frameHeight,
    child: image,
  );
}

Alignment _inlineAlignment(ConversionTextAlignment alignment) => switch (alignment) {
      ConversionTextAlignment.center => Alignment.center,
      ConversionTextAlignment.right => Alignment.centerRight,
      _ => Alignment.centerLeft,
    };

List<int> _cellFlexes(ConversionTable table, ConversionTableRow row) {
  final result = <int>[];
  var gridIndex = 0;
  for (final cell in row.cells) {
    double width = cell.widthPoints ?? cell.widthPercent ?? 0;
    if (table.gridColumnWidths.isNotEmpty) {
      final end = (gridIndex + cell.gridSpan)
          .clamp(0, table.gridColumnWidths.length)
          .toInt();
      if (gridIndex < end) {
        width = table.gridColumnWidths
            .sublist(gridIndex, end)
            .fold<double>(0, (sum, value) => sum + value);
      }
    }
    if (width <= 0) width = math.max(1, cell.gridSpan).toDouble();
    result.add(math.max(1, (width * 10).round()));
    gridIndex += cell.gridSpan;
  }
  return result;
}

bool _textSpansContainTab(List<TextSpan> spans) =>
    spans.any((span) => (span.text ?? '').contains('\t'));

List<TextSpan> _splitTextSpansAtTabs(List<TextSpan> spans) {
  final groups = <List<InlineSpan>>[<InlineSpan>[]];
  for (final span in spans) {
    final text = span.text ?? '';
    if (!text.contains('\t')) {
      groups.last.add(span);
      continue;
    }
    final parts = text.split('\t');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        groups.last.add(
          TextSpan(
            text: parts[i],
            style: span.style,
            recognizer: span.recognizer,
          ),
        );
      }
      if (i != parts.length - 1) groups.add(<InlineSpan>[]);
    }
  }
  return groups
      .map((children) => TextSpan(children: List<InlineSpan>.from(children)))
      .toList(growable: false);
}

class _WordTabText extends LeafRenderObjectWidget {
  const _WordTabText({
    super.key,
    required this.segments,
    required this.tabStops,
    required this.firstSegmentOffsetPoints,
    required this.scale,
    required this.textDirection,
    this.minLineHeight,
  });

  final List<TextSpan> segments;
  final List<ConversionTabStop> tabStops;
  final double firstSegmentOffsetPoints;
  final double scale;
  final TextDirection textDirection;
  final double? minLineHeight;

  @override
  rendering.RenderBox createRenderObject(BuildContext context) =>
      _RenderWordTabText(
        segments: segments,
        tabStops: tabStops,
        firstSegmentOffsetPoints: firstSegmentOffsetPoints,
        scale: scale,
        textDirection: textDirection,
        minLineHeight: minLineHeight,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderWordTabText renderObject,
  ) {
    renderObject
      ..segments = segments
      ..tabStops = tabStops
      ..firstSegmentOffsetPoints = firstSegmentOffsetPoints
      ..scale = scale
      ..textDirection = textDirection
      ..minLineHeight = minLineHeight;
  }
}

class _RenderWordTabText extends rendering.RenderBox {
  _RenderWordTabText({
    required List<TextSpan> segments,
    required List<ConversionTabStop> tabStops,
    required double firstSegmentOffsetPoints,
    required double scale,
    required TextDirection textDirection,
    double? minLineHeight,
  })  : _segments = segments,
        _tabStops = tabStops,
        _firstSegmentOffsetPoints = firstSegmentOffsetPoints,
        _scale = scale,
        _textDirection = textDirection,
        _minLineHeight = minLineHeight;

  List<TextSpan> _segments;
  List<ConversionTabStop> _tabStops;
  double _firstSegmentOffsetPoints;
  double _scale;
  TextDirection _textDirection;
  double? _minLineHeight;
  List<TextPainter> _painters = const <TextPainter>[];
  List<Offset> _offsets = const <Offset>[];
  List<double> _tabXs = const <double>[];

  set segments(List<TextSpan> value) {
    if (identical(value, _segments)) return;
    _segments = value;
    markNeedsLayout();
  }

  set tabStops(List<ConversionTabStop> value) {
    if (identical(value, _tabStops)) return;
    _tabStops = value;
    markNeedsLayout();
  }

  set firstSegmentOffsetPoints(double value) {
    if (value == _firstSegmentOffsetPoints) return;
    _firstSegmentOffsetPoints = value;
    markNeedsLayout();
  }

  set scale(double value) {
    if (value == _scale) return;
    _scale = value;
    markNeedsLayout();
  }

  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  set minLineHeight(double? value) {
    if (value == _minLineHeight) return;
    _minLineHeight = value;
    markNeedsLayout();
  }

  _TabMeasure _measure(double rawMaxWidth) {
    final finite = rawMaxWidth.isFinite && rawMaxWidth > 0;
    final maxWidth = finite ? rawMaxWidth : 100000.0;
    final painters = <TextPainter>[];
    final xs = <double>[];
    final tabXs = <double>[];
    final baselines = <double>[];
    var maxEnd = 0.0;
    var maxBaseline = 0.0;
    var maxBelowBaseline = 0.0;

    for (var i = 0; i < _segments.length; i++) {
      final painter = TextPainter(
        text: _segments[i],
        textDirection: _textDirection,
        maxLines: 1,
      )..layout(maxWidth: maxWidth);
      painters.add(painter);

      double x;
      if (i == 0) {
        x = math.max(0.0, _firstSegmentOffsetPoints * _scale);
      } else {
        final previousEnd = xs[i - 1] + painters[i - 1].width;
        final stop = i - 1 < _tabStops.length ? _tabStops[i - 1] : null;
        final defaultInterval = 36.0 * _scale;
        final stopX = stop == null
            ? ((previousEnd / defaultInterval).floor() + 1) * defaultInterval
            : stop.positionPoints * _scale;
        tabXs.add(stopX);
        x = switch (stop?.alignment ?? ConversionTabAlignment.left) {
          ConversionTabAlignment.center => stopX - painter.width / 2,
          ConversionTabAlignment.right => stopX - painter.width,
          ConversionTabAlignment.decimal =>
            stopX - _decimalAnchorWidth(_segments[i], _textDirection),
          _ => stopX,
        };
        if (x < previousEnd &&
            (stop?.alignment ?? ConversionTabAlignment.left) ==
                ConversionTabAlignment.left) {
          x = previousEnd;
        }
      }
      if (finite) {
        x = x.clamp(0.0, math.max(0.0, maxWidth - painter.width)).toDouble();
      }
      xs.add(x);
      maxEnd = math.max(maxEnd, x + painter.width);

      final metrics = painter.computeLineMetrics();
      final baseline = metrics.isEmpty ? painter.height : metrics.first.baseline;
      baselines.add(baseline);
      maxBaseline = math.max(maxBaseline, baseline);
      maxBelowBaseline = math.max(
        maxBelowBaseline,
        math.max(0.0, painter.height - baseline),
      );
    }

    final height = math.max(
      _minLineHeight ?? 0,
      maxBaseline + maxBelowBaseline,
    );
    final offsets = <Offset>[
      for (var i = 0; i < painters.length; i++)
        Offset(xs[i], math.max(0, maxBaseline - baselines[i])),
    ];
    return _TabMeasure(
      painters: painters,
      offsets: offsets,
      tabXs: tabXs,
      width: finite ? maxWidth : maxEnd,
      height: height,
    );
  }

  double _decimalAnchorWidth(TextSpan span, TextDirection direction) {
    final plain = span.toPlainText();
    final index = plain.indexOf(RegExp(r'[.,]'));
    if (index < 0) {
      final painter = TextPainter(text: span, textDirection: direction)
        ..layout(maxWidth: 100000);
      return painter.width;
    }
    final prefix = plain.substring(0, index);
    final painter = TextPainter(
      text: TextSpan(text: prefix, style: span.style),
      textDirection: direction,
    )..layout(maxWidth: 100000);
    return painter.width;
  }

  @override
  void performLayout() {
    final measured = _measure(constraints.maxWidth);
    size = constraints.constrain(Size(measured.width, measured.height));
    _painters = measured.painters;
    _offsets = measured.offsets;
    _tabXs = measured.tabXs;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final measured = _measure(constraints.maxWidth);
    return constraints.constrain(Size(measured.width, measured.height));
  }

  @override
  double computeMinIntrinsicHeight(double width) => _measure(width).height;

  @override
  double computeMaxIntrinsicHeight(double width) => _measure(width).height;

  @override
  double computeMinIntrinsicWidth(double height) => _measure(double.infinity).width;

  @override
  double computeMaxIntrinsicWidth(double height) => _measure(double.infinity).width;

  @override
  void paint(rendering.PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    for (var i = 1; i < _painters.length; i++) {
      final stop = i - 1 < _tabStops.length ? _tabStops[i - 1] : null;
      final stopX = i - 1 < _tabXs.length ? _tabXs[i - 1] : _offsets[i].dx;
      if (stop?.alignment == ConversionTabAlignment.bar) {
        final paint = Paint()
          ..color = Colors.black87
          ..strokeWidth = math.max(0.5, _scale);
        canvas.drawLine(
          offset + Offset(stopX, 0),
          offset + Offset(stopX, size.height),
          paint,
        );
      }
      if (stop != null && stop.leader != ConversionTabLeader.none) {
        final start = _offsets[i - 1].dx + _painters[i - 1].width + 2 * _scale;
        final end = _offsets[i].dx - 2 * _scale;
        if (end > start) {
          _paintTabLeader(
            canvas,
            Offset(offset.dx + start, offset.dy + size.height * 0.78),
            Offset(offset.dx + end, offset.dy + size.height * 0.78),
            stop.leader,
            _scale,
          );
        }
      }
    }
    for (var i = 0; i < _painters.length; i++) {
      _painters[i].paint(canvas, offset + _offsets[i]);
    }
  }

}

class _TabMeasure {
  const _TabMeasure({
    required this.painters,
    required this.offsets,
    required this.tabXs,
    required this.width,
    required this.height,
  });

  final List<TextPainter> painters;
  final List<Offset> offsets;
  final List<double> tabXs;
  final double width;
  final double height;
}

void _paintTabLeader(
  Canvas canvas,
  Offset start,
  Offset end,
  ConversionTabLeader leader,
  double scale,
) {
  final paint = Paint()
    ..color = Colors.black54
    ..strokeWidth = math.max(0.5, 0.8 * scale)
    ..strokeCap = StrokeCap.round;
  final length = end.dx - start.dx;
  if (length <= 0) return;
  if (leader == ConversionTabLeader.underscore ||
      leader == ConversionTabLeader.heavy) {
    paint.strokeWidth = leader == ConversionTabLeader.heavy
        ? math.max(1.0, 1.4 * scale)
        : math.max(0.5, 0.8 * scale);
    canvas.drawLine(start, end, paint);
    return;
  }
  final step = switch (leader) {
    ConversionTabLeader.dot => 4.0 * scale,
    ConversionTabLeader.middleDot => 5.0 * scale,
    _ => 7.0 * scale,
  };
  final dash = leader == ConversionTabLeader.hyphen ? 3.5 * scale : 0.8 * scale;
  for (double x = start.dx; x < end.dx; x += math.max(2.0, step)) {
    canvas.drawLine(
      Offset(x, start.dy),
      Offset(math.min(end.dx, x + dash), start.dy),
      paint,
    );
  }
}

class _WordBorderPainter extends CustomPainter {
  const _WordBorderPainter(
    this.borders, {
    required this.scale,
    this.respectSideSpaceInsets = false,
  });

  final ConversionBorders borders;
  final double scale;
  final bool respectSideSpaceInsets;

  @override
  void paint(Canvas canvas, Size size) {
    final topInset = respectSideSpaceInsets
        ? math.max(0.0, (borders.top?.spacePoints ?? 0) * scale)
        : 0.0;
    final rightInset = respectSideSpaceInsets
        ? math.max(0.0, (borders.right?.spacePoints ?? 0) * scale)
        : 0.0;
    final bottomInset = respectSideSpaceInsets
        ? math.max(0.0, (borders.bottom?.spacePoints ?? 0) * scale)
        : 0.0;
    final leftInset = respectSideSpaceInsets
        ? math.max(0.0, (borders.left?.spacePoints ?? 0) * scale)
        : 0.0;
    _paintSide(
      canvas,
      borders.top,
      Offset(leftInset, topInset),
      Offset(math.max(leftInset, size.width - rightInset), topInset),
    );
    _paintSide(
      canvas,
      borders.bottom,
      Offset(leftInset, math.max(topInset, size.height - bottomInset)),
      Offset(
        math.max(leftInset, size.width - rightInset),
        math.max(topInset, size.height - bottomInset),
      ),
    );
    _paintSide(
      canvas,
      borders.left,
      Offset(leftInset, topInset),
      Offset(leftInset, math.max(topInset, size.height - bottomInset)),
    );
    _paintSide(
      canvas,
      borders.right,
      Offset(math.max(leftInset, size.width - rightInset), topInset),
      Offset(
        math.max(leftInset, size.width - rightInset),
        math.max(topInset, size.height - bottomInset),
      ),
    );
    if (borders.bar?.isVisible ?? false) {
      final inset = (borders.bar!.spacePoints + 1) * scale;
      _paintSide(
        canvas,
        borders.bar,
        Offset(inset, 0),
        Offset(inset, size.height),
      );
    }
  }

  void _paintSide(
    Canvas canvas,
    ConversionBorderSide? side,
    Offset start,
    Offset end,
  ) {
    if (side == null || !side.isVisible) return;
    final width = math.max(0.5, side.widthPoints * scale);
    final paint = Paint()
      ..color = _hexColor(side.colorHex) ?? Colors.black87
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    if (side.style == ConversionBorderStyle.doubleLine) {
      final horizontal = start.dy == end.dy;
      final delta = math.max(1.0, width * 0.85);
      final shift = horizontal ? Offset(0, delta) : Offset(delta, 0);
      paint.strokeWidth = math.max(0.5, width / 2.5);
      canvas.drawLine(start - shift / 2, end - shift / 2, paint);
      canvas.drawLine(start + shift / 2, end + shift / 2, paint);
      return;
    }

    if (side.style == ConversionBorderStyle.dotted ||
        side.style == ConversionBorderStyle.dashed ||
        side.style == ConversionBorderStyle.dashDot ||
        side.style == ConversionBorderStyle.dashDotDot ||
        side.style == ConversionBorderStyle.wave) {
      _paintDashedBorder(canvas, start, end, paint, side.style, scale);
      return;
    }

    if (side.style == ConversionBorderStyle.thick) {
      paint.strokeWidth = math.max(width, 1.5 * scale);
    }
    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant _WordBorderPainter oldDelegate) =>
      oldDelegate.borders != borders ||
      oldDelegate.scale != scale ||
      oldDelegate.respectSideSpaceInsets != respectSideSpaceInsets;
}

void _paintDashedBorder(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint,
  ConversionBorderStyle style,
  double scale,
) {
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final length = math.sqrt(dx * dx + dy * dy);
  if (length <= 0) return;
  final ux = dx / length;
  final uy = dy / length;
  final dash = switch (style) {
    ConversionBorderStyle.dotted => math.max(0.8, paint.strokeWidth),
    ConversionBorderStyle.wave => 2.5 * scale,
    _ => 5.0 * scale,
  };
  final gap = switch (style) {
    ConversionBorderStyle.dotted => 2.5 * scale,
    ConversionBorderStyle.dashDot || ConversionBorderStyle.dashDotDot =>
      2.5 * scale,
    _ => 3.0 * scale,
  };
  var cursor = 0.0;
  var phase = 0;
  while (cursor < length) {
    var drawLength = dash;
    if (style == ConversionBorderStyle.dashDot && phase.isOdd) {
      drawLength = math.max(0.8, paint.strokeWidth);
    } else if (style == ConversionBorderStyle.dashDotDot && phase % 3 != 0) {
      drawLength = math.max(0.8, paint.strokeWidth);
    }
    final endCursor = math.min(length, cursor + drawLength);
    canvas.drawLine(
      Offset(start.dx + ux * cursor, start.dy + uy * cursor),
      Offset(start.dx + ux * endCursor, start.dy + uy * endCursor),
      paint,
    );
    cursor = endCursor + gap;
    phase++;
  }
}

TextStyle _runStyle(
  ConversionTextStyle style,
  double scale, {
  double? lineHeight,
}) {
  final decorations = <TextDecoration>[];
  if (style.underline) decorations.add(TextDecoration.underline);
  if (style.strike || style.doubleStrike) {
    decorations.add(TextDecoration.lineThrough);
  }
  final decorationStyle = switch (style.underlineStyle) {
    ConversionUnderlineStyle.doubleLine => TextDecorationStyle.double,
    ConversionUnderlineStyle.dotted => TextDecorationStyle.dotted,
    ConversionUnderlineStyle.dashed => TextDecorationStyle.dashed,
    ConversionUnderlineStyle.wavy => TextDecorationStyle.wavy,
    _ => TextDecorationStyle.solid,
  };
  final smallCapsScale = style.smallCaps && !style.allCaps ? 0.86 : 1.0;
  return TextStyle(
    color: _hexColor(style.colorHex) ?? Colors.black87,
    backgroundColor: _hexColor(style.highlightHex),
    fontFamily: style.fontFamily,
    fontFamilyFallback: _wordFontFallbacks(style.fontFamily),
    fontSize: math.max(1, style.fontSizePoints * scale * smallCapsScale),
    fontWeight: style.bold ? FontWeight.w700 : FontWeight.normal,
    fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: style.letterSpacingPoints * scale,
    decoration:
        decorations.isEmpty ? null : TextDecoration.combine(decorations),
    decorationStyle: decorations.isEmpty ? null : decorationStyle,
    height: lineHeight ?? 1.15,
  );
}

String _displayRunText(String text, ConversionTextStyle style) {
  if (style.allCaps || style.smallCaps) return text.toUpperCase();
  return text;
}

List<InlineSpan> _highlightedSpans(
  String text,
  TextStyle style,
  String rawQuery,
) {
  final query = rawQuery.trim();
  if (query.isEmpty || text.isEmpty) {
    return <InlineSpan>[TextSpan(text: text, style: style)];
  }
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final spans = <InlineSpan>[];
  var start = 0;
  while (start < text.length) {
    final index = lowerText.indexOf(lowerQuery, start);
    if (index < 0) {
      spans.add(TextSpan(text: text.substring(start), style: style));
      break;
    }
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index), style: style));
    }
    spans.add(
      TextSpan(
        text: text.substring(index, index + query.length),
        style: style.copyWith(backgroundColor: const Color(0xFFFFEB80)),
      ),
    );
    start = index + query.length;
  }
  return spans;
}

String _paragraphPlainText(ConversionParagraph paragraph) {
  final buffer = StringBuffer(paragraph.listLabel ?? '');
  for (final inline in paragraph.inlines) {
    if (inline is ConversionTextRun) {
      buffer.write(_displayRunText(inline.text, inline.style));
    } else if (inline is ConversionDynamicFieldRun) {
      buffer.write(
        inline.field == ConversionDynamicField.pageNumber
            ? '{PAGE}'
            : '{NUMPAGES}',
      );
    } else if (inline is ConversionFieldRun) {
      buffer.write(inline.resultText.isEmpty
          ? '{${inline.fieldName.isEmpty ? 'FIELD' : inline.fieldName}}'
          : inline.resultText);
    } else if (inline is ConversionMathRun) {
      buffer.write(inline.plainText);
    } else if (inline is ConversionNoteReferenceRun) {
      buffer.write(inline.displayLabel ?? inline.noteId);
    } else if (inline is ConversionCommentMarkerRun) {
      if (inline.kind == ConversionWordMarkerKind.reference) {
        buffer.write(inline.comment?.text ?? '');
      }
    } else if (inline is ConversionBookmarkMarkerRun) {
      // Non-printing navigation anchor.
    } else if (inline is ConversionOpaqueOoxmlRun) {
      buffer.write(inline.fallbackText.isEmpty
          ? '[Word ${inline.featureKind} preserved]'
          : inline.fallbackText);
    } else if (inline is ConversionTextBoxRun) {
      for (final block in inline.blocks) {
        if (block is ConversionParagraph) {
          buffer.write(_paragraphPlainText(block));
          buffer.write(' ');
        } else if (block is ConversionTable) {
          for (final row in block.rows) {
            for (final cell in row.cells) {
              for (final child in cell.blocks) {
                if (child is ConversionParagraph) {
                  buffer.write(_paragraphPlainText(child));
                  buffer.write(' ');
                }
              }
            }
          }
        }
      }
    } else if (inline is ConversionShapeRun) {
      final alt = inline.altText?.trim();
      if (alt != null && alt.isNotEmpty) buffer.write(alt);
      for (final block in inline.blocks) {
        if (block is ConversionParagraph) {
          buffer.write(_paragraphPlainText(block));
          buffer.write(' ');
        }
      }
    } else if (inline is ConversionImageRun) {
      final alt = inline.altText?.trim();
      if (alt != null && alt.isNotEmpty) buffer.write(alt);
    }
  }
  return buffer.toString();
}

String _superscript(String value) {
  const digits = <String, String>{
    '0': '⁰',
    '1': '¹',
    '2': '²',
    '3': '³',
    '4': '⁴',
    '5': '⁵',
    '6': '⁶',
    '7': '⁷',
    '8': '⁸',
    '9': '⁹',
    '-': '⁻',
  };
  return value.split('').map((character) => digits[character] ?? character).join();
}

TextAlign _alignment(ConversionTextAlignment alignment) => switch (alignment) {
      ConversionTextAlignment.center => TextAlign.center,
      ConversionTextAlignment.right => TextAlign.right,
      ConversionTextAlignment.justify => TextAlign.justify,
      ConversionTextAlignment.left => TextAlign.left,
    };

Color? _hexColor(String? value) {
  if (value == null) return null;
  final normalized = value.replaceAll('#', '').trim();
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized)) return null;
  return Color(0xFF000000 | int.parse(normalized, radix: 16));
}
