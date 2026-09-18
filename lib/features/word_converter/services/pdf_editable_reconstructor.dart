import 'dart:math' as math;
import 'dart:ui';

import 'package:edusheet/features/word_converter/domain/models/editable_document.dart';

class PdfEditableDocumentReconstructor {
  const PdfEditableDocumentReconstructor();

  EditableDocument reconstruct(List<PdfLayoutPageInput> pages) {
    return EditableDocument(
      pages: pages.map(_reconstructPage).toList(growable: false),
    );
  }

  EditablePage _reconstructPage(PdfLayoutPageInput page) {
    final lines = page.lines
        .where((line) => line.text.trim().isNotEmpty)
        .map((line) => line.normalized())
        .toList(growable: false);

    if (lines.isEmpty) {
      return EditablePage(
        pageIndex: page.pageIndex,
        size: page.size,
        blocks: const [],
      );
    }

    final medianFontSize = _median(
      lines.map((line) => line.fontSizePoints).where((size) => size > 0).toList(),
      fallback: 11,
    );
    final margins = _inferMargins(page.size, lines);
    final columnSplit = _detectTwoColumnSplit(page.size, lines, medianFontSize);
    final orderedLines = _orderForReading(lines, columnSplit);
    final blocks = _buildBlocks(
      orderedLines,
      page.size,
      margins,
      medianFontSize,
    );

    return EditablePage(
      pageIndex: page.pageIndex,
      size: page.size,
      margins: margins,
      blocks: blocks,
    );
  }

  List<EditableBlock> _buildBlocks(
    List<PdfLayoutLineInput> lines,
    Size pageSize,
    EditablePageMargins margins,
    double medianFontSize,
  ) {
    final blocks = <EditableBlock>[];
    var index = 0;

    while (index < lines.length) {
      final table = _tryBuildTable(lines, index, pageSize, medianFontSize);
      if (table != null) {
        blocks.add(table.block);
        index = table.nextIndex;
        continue;
      }

      final first = lines[index];
      final kind = _paragraphKind(first, medianFontSize);
      final paragraphLines = <PdfLayoutLineInput>[first];
      var next = index + 1;

      while (next < lines.length) {
        if (_tryBuildTable(lines, next, pageSize, medianFontSize) != null) {
          break;
        }

        final candidate = lines[next];
        final candidateKind = _paragraphKind(candidate, medianFontSize);
        if (!_shouldJoinParagraph(
          paragraphLines.last,
          candidate,
          kind,
          candidateKind,
          medianFontSize,
        )) {
          break;
        }
        paragraphLines.add(candidate);
        next++;
      }

      blocks.add(
        _paragraphFromLines(
          paragraphLines,
          kind,
          pageSize,
          margins,
          medianFontSize,
        ),
      );
      index = next;
    }

    return blocks;
  }

  EditableParagraphBlock _paragraphFromLines(
    List<PdfLayoutLineInput> lines,
    EditableParagraphKind kind,
    Size pageSize,
    EditablePageMargins margins,
    double medianFontSize,
  ) {
    final runs = <EditableTextRun>[];

    for (var index = 0; index < lines.length; index++) {
      final lineRuns = _runsForLine(lines[index]);
      if (lineRuns.isEmpty) continue;

      if (runs.isNotEmpty) {
        final previousText = runs.last.text;
        final nextText = lineRuns.first.text;
        final dehyphenate = previousText.endsWith('-') &&
            _startsWithLowercase(nextText.trimLeft());
        if (dehyphenate) {
          runs[runs.length - 1] = EditableTextRun(
            text: previousText.substring(0, previousText.length - 1),
            style: runs.last.style,
          );
        } else if (!_endsWithWhitespace(previousText) &&
            !_startsWithClosingPunctuation(nextText)) {
          runs.add(
            EditableTextRun(
              text: ' ',
              style: lineRuns.first.style,
            ),
          );
        }
      }
      runs.addAll(lineRuns);
    }

    final first = lines.first;
    final contentLeft = margins.leftPoints;
    final indent = _maxDouble(0.0, first.bounds.left - contentLeft);
    final alignment = _inferAlignment(first.bounds, pageSize.width);
    final verticalGapAfter = _estimatedGapAfter(medianFontSize);

    return EditableParagraphBlock(
      runs: _coalesceRuns(runs),
      kind: kind,
      alignment: alignment,
      leftIndentPoints: _minDouble(indent, 72.0),
      spaceBeforePoints: kind == EditableParagraphKind.heading1
          ? 10
          : kind == EditableParagraphKind.heading2
          ? 7
          : 0,
      spaceAfterPoints: kind == EditableParagraphKind.heading1
          ? 7
          : kind == EditableParagraphKind.heading2
          ? 5
          : _maxDouble(3.0, _minDouble(verticalGapAfter, 8.0)),
    );
  }

  _TableBuildResult? _tryBuildTable(
    List<PdfLayoutLineInput> lines,
    int startIndex,
    Size pageSize,
    double medianFontSize,
  ) {
    if (startIndex >= lines.length) return null;
    final firstSegments = _splitLineIntoSegments(lines[startIndex], medianFontSize);
    if (firstSegments.length < 2 || firstSegments.length > 6) return null;

    final rows = <List<_PdfSegment>>[firstSegments];
    var nextIndex = startIndex + 1;
    while (nextIndex < lines.length) {
      final previousLine = lines[nextIndex - 1];
      final line = lines[nextIndex];
      final gap = line.bounds.top - previousLine.bounds.bottom;
      if (gap > _maxDouble(30.0, medianFontSize * 2.4)) break;

      final segments = _splitLineIntoSegments(line, medianFontSize);
      if (segments.length != firstSegments.length ||
          !_segmentsAlign(rows.first, segments, medianFontSize)) {
        break;
      }
      rows.add(segments);
      nextIndex++;
    }

    if (rows.length < 2) return null;

    final averageCellLength = rows
            .expand((row) => row)
            .map((segment) => segment.text.trim().length)
            .fold<int>(0, (sum, length) => sum + length) /
        rows.expand((row) => row).length;
    if (rows.first.length == 2 && averageCellLength > 55) {
      return null;
    }

    final columnStarts = List<double>.generate(rows.first.length, (column) {
      final values = rows.map((row) => row[column].bounds.left).toList();
      return values.reduce((a, b) => a + b) / values.length;
    });
    final rightEdge = rows
        .expand((row) => row)
        .map((segment) => segment.bounds.right)
        .reduce(_maxDouble);
    final widths = <double>[];
    for (var column = 0; column < columnStarts.length; column++) {
      final end = column + 1 < columnStarts.length
          ? columnStarts[column + 1]
          : _minDouble(pageSize.width, rightEdge + 12);
      widths.add(_maxDouble(36.0, end - columnStarts[column]));
    }

    final tableRows = rows.map((row) {
      return EditableTableRow(
        cells: row.map((segment) {
          final paragraph = EditableParagraphBlock(
            runs: _coalesceRuns(segment.runs),
            kind: EditableParagraphKind.body,
            spaceAfterPoints: 0,
          );
          return EditableTableCell(paragraphs: [paragraph]);
        }).toList(growable: false),
      );
    }).toList(growable: false);

    return _TableBuildResult(
      block: EditableTableBlock(
        rows: tableRows,
        columnWidthsPoints: widths,
      ),
      nextIndex: nextIndex,
    );
  }

  List<_PdfSegment> _splitLineIntoSegments(
    PdfLayoutLineInput line,
    double medianFontSize,
  ) {
    final words = [...line.words]
      ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
    if (words.length < 2) return const [];

    final threshold = _maxDouble(18.0, medianFontSize * 2.25);
    final groups = <List<PdfLayoutWordInput>>[];
    var current = <PdfLayoutWordInput>[words.first];

    for (var index = 1; index < words.length; index++) {
      final previous = words[index - 1];
      final word = words[index];
      final gap = word.bounds.left - previous.bounds.right;
      if (gap >= threshold) {
        groups.add(current);
        current = <PdfLayoutWordInput>[word];
      } else {
        current.add(word);
      }
    }
    groups.add(current);

    if (groups.length < 2) return const [];
    return groups.map((group) {
      final left = group.map((word) => word.bounds.left).reduce(_minDouble);
      final top = group.map((word) => word.bounds.top).reduce(_minDouble);
      final right = group.map((word) => word.bounds.right).reduce(_maxDouble);
      final bottom = group.map((word) => word.bounds.bottom).reduce(_maxDouble);
      return _PdfSegment(
        bounds: Rect.fromLTRB(left, top, right, bottom),
        text: group.map((word) => word.text).join(' '),
        runs: _runsForWords(group),
      );
    }).toList(growable: false);
  }

  bool _segmentsAlign(
    List<_PdfSegment> baseline,
    List<_PdfSegment> candidate,
    double medianFontSize,
  ) {
    final tolerance = _maxDouble(14.0, medianFontSize * 1.6);
    for (var index = 0; index < baseline.length; index++) {
      if ((baseline[index].bounds.left - candidate[index].bounds.left).abs() >
          tolerance) {
        return false;
      }
    }
    return true;
  }

  bool _shouldJoinParagraph(
    PdfLayoutLineInput previous,
    PdfLayoutLineInput current,
    EditableParagraphKind paragraphKind,
    EditableParagraphKind currentKind,
    double medianFontSize,
  ) {
    if (paragraphKind != EditableParagraphKind.body ||
        currentKind != EditableParagraphKind.body) {
      return false;
    }

    if (_likelyDifferentColumns(previous, current)) return false;

    final verticalGap = current.bounds.top - previous.bounds.bottom;
    final maxGap = _maxDouble(7.0, medianFontSize * 0.8);
    if (verticalGap > maxGap) return false;
    if (verticalGap < -medianFontSize * 0.7) return false;

    final leftDelta = (current.bounds.left - previous.bounds.left).abs();
    if (leftDelta > _maxDouble(10.0, medianFontSize * 1.1)) return false;

    final sizeDelta = (current.fontSizePoints - previous.fontSizePoints).abs();
    if (sizeDelta > _maxDouble(1.5, medianFontSize * 0.16)) return false;

    final previousBold = previous.bold;
    if (previousBold != current.bold && sizeDelta > 0.5) return false;
    return true;
  }

  bool _likelyDifferentColumns(
    PdfLayoutLineInput previous,
    PdfLayoutLineInput current,
  ) {
    final overlap = _minDouble(previous.bounds.right, current.bounds.right) -
        _maxDouble(previous.bounds.left, current.bounds.left);
    return overlap < 0 &&
        (previous.bounds.left - current.bounds.left).abs() >
            _maxDouble(previous.bounds.width, current.bounds.width) * 0.35;
  }

  EditableParagraphKind _paragraphKind(
    PdfLayoutLineInput line,
    double medianFontSize,
  ) {
    final text = line.text.trim();
    if (_isListItem(text)) return EditableParagraphKind.listItem;

    final shortEnough = text.length <= 120;
    if (!shortEnough) return EditableParagraphKind.body;

    if (line.fontSizePoints >= medianFontSize * 1.42) {
      return EditableParagraphKind.heading1;
    }
    if (line.fontSizePoints >= medianFontSize * 1.18 ||
        (line.bold && line.fontSizePoints >= medianFontSize * 1.04)) {
      return EditableParagraphKind.heading2;
    }
    return EditableParagraphKind.body;
  }

  bool _isListItem(String text) {
    return RegExp(
      r'^(?:[\u2022\u25CF\u25AA\u25E6\u2023\u2043\-\u2013\u2014]|\d+[.)]|[A-Za-z][.)])\s+',
    ).hasMatch(text);
  }

  List<EditableTextRun> _runsForLine(PdfLayoutLineInput line) {
    if (line.words.isEmpty) {
      return [
        EditableTextRun(
          text: line.text,
          style: line.style,
        ),
      ];
    }
    return _runsForWords(line.words);
  }

  List<EditableTextRun> _runsForWords(List<PdfLayoutWordInput> sourceWords) {
    final words = [...sourceWords]
      ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
    final runs = <EditableTextRun>[];

    for (var index = 0; index < words.length; index++) {
      final word = words[index];
      if (index > 0) {
        final previous = words[index - 1];
        final gap = word.bounds.left - previous.bounds.right;
        if (gap > 0.4 &&
            !_startsWithClosingPunctuation(word.text) &&
            !_endsWithOpeningPunctuation(previous.text)) {
          runs.add(EditableTextRun(text: ' ', style: word.style));
        }
      }
      runs.add(EditableTextRun(text: word.text, style: word.style));
    }

    return runs;
  }

  List<EditableTextRun> _coalesceRuns(List<EditableTextRun> runs) {
    if (runs.isEmpty) return const [];
    final result = <EditableTextRun>[];
    for (final run in runs) {
      if (run.text.isEmpty) continue;
      if (result.isNotEmpty && _sameStyle(result.last.style, run.style)) {
        result[result.length - 1] = EditableTextRun(
          text: '${result.last.text}${run.text}',
          style: result.last.style,
        );
      } else {
        result.add(run);
      }
    }
    return result;
  }

  bool _sameStyle(EditableTextStyle a, EditableTextStyle b) {
    return a.fontFamily == b.fontFamily &&
        (a.fontSizePoints - b.fontSizePoints).abs() < 0.05 &&
        a.bold == b.bold &&
        a.italic == b.italic &&
        a.underline == b.underline &&
        a.strike == b.strike;
  }

  List<PdfLayoutLineInput> _orderForReading(
    List<PdfLayoutLineInput> lines,
    double? split,
  ) {
    if (split == null) {
      return [...lines]..sort(_compareTopLeft);
    }

    final spanning = <PdfLayoutLineInput>[];
    final left = <PdfLayoutLineInput>[];
    final right = <PdfLayoutLineInput>[];
    final tolerance = 6.0;

    for (final line in lines) {
      if (line.bounds.right <= split - tolerance) {
        left.add(line);
      } else if (line.bounds.left >= split + tolerance) {
        right.add(line);
      } else {
        spanning.add(line);
      }
    }

    left.sort(_compareTopLeft);
    right.sort(_compareTopLeft);
    spanning.sort(_compareTopLeft);

    if (spanning.isEmpty) return [...left, ...right];

    final firstColumnTop = [
      if (left.isNotEmpty) left.first.bounds.top,
      if (right.isNotEmpty) right.first.bounds.top,
    ].reduce(_minDouble);
    final headers = spanning
        .where((line) => line.bounds.bottom <= firstColumnTop + 6)
        .toList();
    final remainingSpanning = spanning
        .where((line) => !headers.contains(line))
        .toList();

    return [...headers, ...left, ...right, ...remainingSpanning];
  }

  double? _detectTwoColumnSplit(
    Size pageSize,
    List<PdfLayoutLineInput> lines,
    double medianFontSize,
  ) {
    if (lines.length < 6 || pageSize.width <= 0) return null;

    double? bestSplit;
    double bestScore = double.negativeInfinity;
    for (var ratio = 0.34; ratio <= 0.66; ratio += 0.025) {
      final split = pageSize.width * ratio;
      final tolerance = _maxDouble(8.0, medianFontSize * 0.75);
      var leftCount = 0;
      var rightCount = 0;
      var crossingCount = 0;
      var nearestLeft = 0.0;
      var nearestRight = pageSize.width;

      for (final line in lines) {
        if (line.bounds.width > pageSize.width * 0.82) {
          crossingCount++;
          continue;
        }
        if (line.bounds.right <= split - tolerance) {
          leftCount++;
          nearestLeft = _maxDouble(nearestLeft, line.bounds.right);
        } else if (line.bounds.left >= split + tolerance) {
          rightCount++;
          nearestRight = _minDouble(nearestRight, line.bounds.left);
        } else {
          crossingCount++;
        }
      }

      if (leftCount < 3 || rightCount < 3) continue;
      if (crossingCount > math.max(2, (lines.length * 0.18).round())) continue;
      final gutter = nearestRight - nearestLeft;
      if (gutter < _maxDouble(18.0, medianFontSize * 1.6)) continue;

      final balance = math.min(leftCount, rightCount).toDouble();
      final score = balance * 6 + gutter - crossingCount * 10;
      if (score > bestScore) {
        bestScore = score;
        bestSplit = split;
      }
    }
    return bestSplit;
  }

  EditablePageMargins _inferMargins(
    Size pageSize,
    List<PdfLayoutLineInput> lines,
  ) {
    final left = lines.map((line) => line.bounds.left).reduce(_minDouble);
    final top = lines.map((line) => line.bounds.top).reduce(_minDouble);
    final right = lines.map((line) => line.bounds.right).reduce(_maxDouble);
    final bottom = lines.map((line) => line.bounds.bottom).reduce(_maxDouble);

    return EditablePageMargins(
      leftPoints: _safeMargin(left, pageSize.width),
      topPoints: _safeMargin(top, pageSize.height),
      rightPoints: _safeMargin(pageSize.width - right, pageSize.width),
      bottomPoints: _safeMargin(pageSize.height - bottom, pageSize.height),
    );
  }

  double _safeMargin(double value, double axisLength) {
    if (!value.isFinite || axisLength <= 0) return 36;
    return value.clamp(18.0, _minDouble(72.0, axisLength * 0.18)).toDouble();
  }

  EditableParagraphAlignment _inferAlignment(Rect bounds, double pageWidth) {
    if (pageWidth <= 0) return EditableParagraphAlignment.left;
    final centerDelta = (bounds.center.dx - pageWidth / 2).abs();
    if (bounds.width < pageWidth * 0.82 && centerDelta <= pageWidth * 0.055) {
      return EditableParagraphAlignment.center;
    }
    if (bounds.left > pageWidth * 0.45 &&
        (pageWidth - bounds.right).abs() <= pageWidth * 0.08) {
      return EditableParagraphAlignment.right;
    }
    return EditableParagraphAlignment.left;
  }

  double _estimatedGapAfter(double medianFontSize) {
    return _maxDouble(3.0, medianFontSize * 0.45);
  }

  int _compareTopLeft(PdfLayoutLineInput a, PdfLayoutLineInput b) {
    final topDelta = a.bounds.top - b.bounds.top;
    final tolerance = _maxDouble(2.0, _minDouble(a.bounds.height, b.bounds.height) * 0.35);
    if (topDelta.abs() <= tolerance) {
      return a.bounds.left.compareTo(b.bounds.left);
    }
    return a.bounds.top.compareTo(b.bounds.top);
  }

  double _maxDouble(double a, double b) => a >= b ? a : b;

  double _minDouble(double a, double b) => a <= b ? a : b;

  double _median(List<double> values, {required double fallback}) {
    if (values.isEmpty) return fallback;
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  bool _startsWithLowercase(String value) {
    if (value.isEmpty) return false;
    final first = String.fromCharCode(value.runes.first);
    return first.toLowerCase() == first && first.toUpperCase() != first;
  }

  bool _endsWithWhitespace(String value) =>
      value.isNotEmpty && RegExp(r'\s$').hasMatch(value);

  bool _startsWithClosingPunctuation(String value) =>
      RegExp(r'^[,.;:!?%)\]\}]').hasMatch(value.trimLeft());

  bool _endsWithOpeningPunctuation(String value) =>
      RegExp(r'[(\[\{/]$').hasMatch(value.trimRight());
}

class PdfLayoutPageInput {
  const PdfLayoutPageInput({
    required this.pageIndex,
    required this.size,
    required this.lines,
  });

  final int pageIndex;
  final Size size;
  final List<PdfLayoutLineInput> lines;
}

class PdfLayoutLineInput {
  const PdfLayoutLineInput({
    required this.text,
    required this.bounds,
    required this.fontSizePoints,
    required this.fontFamily,
    required this.words,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
  });

  final String text;
  final Rect bounds;
  final double fontSizePoints;
  final String? fontFamily;
  final List<PdfLayoutWordInput> words;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;

  EditableTextStyle get style => EditableTextStyle(
    fontFamily: _cleanFontFamily(fontFamily),
    fontSizePoints: fontSizePoints <= 0 ? 11 : fontSizePoints,
    bold: bold,
    italic: italic,
    underline: underline,
    strike: strike,
  );

  PdfLayoutLineInput normalized() {
    final normalizedText = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final normalizedWords = words
        .where((word) => word.text.trim().isNotEmpty)
        .map((word) => word.normalized())
        .toList(growable: false);
    return PdfLayoutLineInput(
      text: normalizedText,
      bounds: bounds,
      fontSizePoints: fontSizePoints,
      fontFamily: fontFamily,
      words: normalizedWords,
      bold: bold,
      italic: italic,
      underline: underline,
      strike: strike,
    );
  }

  static String? _cleanFontFamily(String? value) {
    if (value == null) return null;
    var cleaned = value.trim();
    if (cleaned.isEmpty) return null;
    final subsetSeparator = cleaned.indexOf('+');
    if (subsetSeparator > 0 && subsetSeparator < cleaned.length - 1) {
      cleaned = cleaned.substring(subsetSeparator + 1);
    }
    cleaned = cleaned
        .replaceAll(RegExp(r'[-_](Bold|Italic|Oblique|Regular|Roman|MT).*$'), '')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }
}

class PdfLayoutWordInput {
  const PdfLayoutWordInput({
    required this.text,
    required this.bounds,
    required this.style,
  });

  final String text;
  final Rect bounds;
  final EditableTextStyle style;

  PdfLayoutWordInput normalized() {
    return PdfLayoutWordInput(
      text: text.replaceAll(RegExp(r'\s+'), ' ').trim(),
      bounds: bounds,
      style: style.copyWith(
        fontFamily: PdfLayoutLineInput._cleanFontFamily(style.fontFamily),
        fontSizePoints: style.fontSizePoints <= 0 ? 11 : style.fontSizePoints,
      ),
    );
  }
}

class _PdfSegment {
  const _PdfSegment({
    required this.bounds,
    required this.text,
    required this.runs,
  });

  final Rect bounds;
  final String text;
  final List<EditableTextRun> runs;
}

class _TableBuildResult {
  const _TableBuildResult({required this.block, required this.nextIndex});

  final EditableTableBlock block;
  final int nextIndex;
}
