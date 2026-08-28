import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/services/document_file_read_service.dart';
import '../../../data/services/spreadsheet_parser_service.dart';
import '../../../domain/models/document_model.dart';
import '../../../domain/models/spreadsheet_model.dart';

class SpreadsheetDocumentViewer extends StatefulWidget {
  final DocumentFile document;
  final SpreadsheetParserService? parserService;

  const SpreadsheetDocumentViewer({
    super.key,
    required this.document,
    this.parserService,
  });

  @override
  State<SpreadsheetDocumentViewer> createState() =>
      _SpreadsheetDocumentViewerState();
}

class _SpreadsheetDocumentViewerState extends State<SpreadsheetDocumentViewer> {
  late final SpreadsheetParserService _parserService;
  late Future<SpreadsheetWorkbook> _future;
  int _selectedSheet = 0;
  double _zoom = 1;

  @override
  void initState() {
    super.initState();
    _parserService = widget.parserService ?? SpreadsheetParserService();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant SpreadsheetDocumentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.path != widget.document.path) {
      _selectedSheet = 0;
      _future = _load();
    }
  }

  Future<SpreadsheetWorkbook> _load() {
    return _parserService.load(
      File(widget.document.path),
      widget.document.extension,
    );
  }

  void _retry() {
    final nextLoad = Completer<SpreadsheetWorkbook>();

    setState(() {
      _future = nextLoad.future;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || nextLoad.isCompleted) return;
      try {
        final result = await _load();
        if (!mounted || nextLoad.isCompleted) return;
        nextLoad.complete(result);
      } catch (error, stackTrace) {
        if (!mounted || nextLoad.isCompleted) return;
        nextLoad.completeError(error, stackTrace);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SpreadsheetWorkbook>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SpreadsheetLoadingState();
        }
        if (snapshot.hasError) {
          return _SpreadsheetErrorState(error: snapshot.error, onRetry: _retry);
        }

        final workbook = snapshot.data!;
        if (workbook.sheets.isEmpty || workbook.isEmpty) {
          return const Center(
            child: Text('No readable spreadsheet cells found.'),
          );
        }
        if (_selectedSheet >= workbook.sheets.length) _selectedSheet = 0;
        final sheet = workbook.sheets[_selectedSheet];

        return Column(
          children: [
            _SpreadsheetToolbar(
              workbook: workbook,
              selectedIndex: _selectedSheet,
              zoom: _zoom,
              onSelected: (index) => setState(() => _selectedSheet = index),
              onZoomOut: _zoom > 0.7
                  ? () => setState(
                      () => _zoom = math.max(0.7, _zoom - 0.1).toDouble(),
                    )
                  : null,
              onZoomIn: _zoom < 1.8
                  ? () => setState(
                      () => _zoom = math.min(1.8, _zoom + 0.1).toDouble(),
                    )
                  : null,
            ),
            if (workbook.truncated) const _SpreadsheetLimitBanner(),
            Expanded(
              child: _VirtualSpreadsheetGrid(
                key: ValueKey('${widget.document.path}-${sheet.name}'),
                sheet: sheet,
                zoom: _zoom,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpreadsheetToolbar extends StatelessWidget {
  final SpreadsheetWorkbook workbook;
  final int selectedIndex;
  final double zoom;
  final ValueChanged<int> onSelected;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomIn;

  const _SpreadsheetToolbar({
    required this.workbook,
    required this.selectedIndex,
    required this.zoom,
    required this.onSelected,
    required this.onZoomOut,
    required this.onZoomIn,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1B1F26) : Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 8),
                const Icon(Icons.grid_on, size: 18, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${workbook.sheets[selectedIndex].rows.length} populated rows • '
                    '${workbook.sheets[selectedIndex].columnCount} columns',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Zoom out',
                  onPressed: onZoomOut,
                  icon: const Icon(Icons.remove),
                ),
                Text(
                  '${(zoom * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  tooltip: 'Zoom in',
                  onPressed: onZoomIn,
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          if (workbook.sheets.length > 1)
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: workbook.sheets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  return ChoiceChip(
                    selected: selectedIndex == index,
                    onSelected: (_) => onSelected(index),
                    selectedColor: Colors.green.withValues(alpha: 0.18),
                    label: Text(
                      workbook.sheets[index].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _VirtualSpreadsheetGrid extends StatefulWidget {
  final SpreadsheetSheet sheet;
  final double zoom;

  const _VirtualSpreadsheetGrid({
    super.key,
    required this.sheet,
    required this.zoom,
  });

  @override
  State<_VirtualSpreadsheetGrid> createState() =>
      _VirtualSpreadsheetGridState();
}

class _VirtualSpreadsheetGridState extends State<_VirtualSpreadsheetGrid> {
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final columnWidth = 140.0 * widget.zoom;
    final rowHeaderWidth = 58.0 * widget.zoom;
    final rowHeight = 38.0 * widget.zoom;
    final headerHeight = 40.0 * widget.zoom;
    final columnCount = math.max(1, widget.sheet.columnCount);
    final totalWidth = rowHeaderWidth + columnWidth * columnCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _horizontal,
          thumbVisibility: constraints.maxWidth >= 700,
          notificationPredicate: (notification) => notification.depth == 0,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalWidth,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  SizedBox(
                    height: headerHeight,
                    child: _SpreadsheetPaintedHeader(
                      horizontalController: _horizontal,
                      viewportWidth: constraints.maxWidth,
                      rowHeaderWidth: rowHeaderWidth,
                      columnWidth: columnWidth,
                      columnCount: columnCount,
                      isDark: isDark,
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: _vertical,
                      thumbVisibility: constraints.maxWidth >= 700,
                      child: ListView.builder(
                        controller: _vertical,
                        itemExtent: rowHeight,
                        itemCount: widget.sheet.rows.length,
                        itemBuilder: (context, index) {
                          return _SpreadsheetPaintedRow(
                            row: widget.sheet.rows[index],
                            rowListIndex: index,
                            horizontalController: _horizontal,
                            viewportWidth: constraints.maxWidth,
                            rowHeaderWidth: rowHeaderWidth,
                            columnWidth: columnWidth,
                            columnCount: columnCount,
                            zoom: widget.zoom,
                            isDark: isDark,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpreadsheetPaintedHeader extends StatelessWidget {
  final ScrollController horizontalController;
  final double viewportWidth;
  final double rowHeaderWidth;
  final double columnWidth;
  final int columnCount;
  final bool isDark;

  const _SpreadsheetPaintedHeader({
    required this.horizontalController,
    required this.viewportWidth,
    required this.rowHeaderWidth,
    required this.columnWidth,
    required this.columnCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: horizontalController,
      builder: (context, _) => CustomPaint(
        painter: _SpreadsheetHeaderPainter(
          scrollOffset: horizontalController.hasClients
              ? horizontalController.offset
              : 0,
          viewportWidth: viewportWidth,
          rowHeaderWidth: rowHeaderWidth,
          columnWidth: columnWidth,
          columnCount: columnCount,
          isDark: isDark,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SpreadsheetPaintedRow extends StatelessWidget {
  final SpreadsheetRow row;
  final int rowListIndex;
  final ScrollController horizontalController;
  final double viewportWidth;
  final double rowHeaderWidth;
  final double columnWidth;
  final int columnCount;
  final double zoom;
  final bool isDark;

  const _SpreadsheetPaintedRow({
    required this.row,
    required this.rowListIndex,
    required this.horizontalController,
    required this.viewportWidth,
    required this.rowHeaderWidth,
    required this.columnWidth,
    required this.columnCount,
    required this.zoom,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: horizontalController,
      builder: (context, _) => CustomPaint(
        painter: _SpreadsheetRowPainter(
          row: row,
          rowListIndex: rowListIndex,
          scrollOffset: horizontalController.hasClients
              ? horizontalController.offset
              : 0,
          viewportWidth: viewportWidth,
          rowHeaderWidth: rowHeaderWidth,
          columnWidth: columnWidth,
          columnCount: columnCount,
          zoom: zoom,
          isDark: isDark,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SpreadsheetHeaderPainter extends CustomPainter {
  final double scrollOffset;
  final double viewportWidth;
  final double rowHeaderWidth;
  final double columnWidth;
  final int columnCount;
  final bool isDark;

  _SpreadsheetHeaderPainter({
    required this.scrollOffset,
    required this.viewportWidth,
    required this.rowHeaderWidth,
    required this.columnWidth,
    required this.columnCount,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final background = isDark
        ? const Color(0xFF243025)
        : const Color(0xFFEAF7ED);
    final grid = isDark ? Colors.white12 : Colors.black12;
    final textColor = isDark ? Colors.white : Colors.black87;
    final fill = Paint()..color = background;
    final border = Paint()
      ..color = grid
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Offset.zero & size, fill);
    final range = _visibleColumnRange(
      scrollOffset,
      viewportWidth,
      rowHeaderWidth,
      columnWidth,
      columnCount,
    );

    if (scrollOffset < rowHeaderWidth) {
      canvas.drawRect(Rect.fromLTWH(0, 0, rowHeaderWidth, size.height), border);
    }
    for (var column = range.$1; column <= range.$2; column++) {
      final left = rowHeaderWidth + column * columnWidth;
      final rect = Rect.fromLTWH(left, 0, columnWidth, size.height);
      canvas.drawRect(rect, border);
      _paintText(
        canvas,
        _columnName(column),
        rect.deflate(8),
        TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w800),
        TextAlign.center,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpreadsheetHeaderPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.viewportWidth != viewportWidth ||
        oldDelegate.columnWidth != columnWidth ||
        oldDelegate.columnCount != columnCount ||
        oldDelegate.isDark != isDark;
  }
}

class _SpreadsheetRowPainter extends CustomPainter {
  final SpreadsheetRow row;
  final int rowListIndex;
  final double scrollOffset;
  final double viewportWidth;
  final double rowHeaderWidth;
  final double columnWidth;
  final int columnCount;
  final double zoom;
  final bool isDark;

  _SpreadsheetRowPainter({
    required this.row,
    required this.rowListIndex,
    required this.scrollOffset,
    required this.viewportWidth,
    required this.rowHeaderWidth,
    required this.columnWidth,
    required this.columnCount,
    required this.zoom,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final alternating = rowListIndex.isOdd;
    final background = isDark
        ? (alternating ? const Color(0xFF191D22) : const Color(0xFF15181D))
        : (alternating ? const Color(0xFFF9FBFC) : Colors.white);
    final headerBackground = isDark
        ? const Color(0xFF20252B)
        : const Color(0xFFF0F3F6);
    final grid = isDark ? Colors.white10 : Colors.black12;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final fill = Paint()..color = background;
    final border = Paint()
      ..color = grid
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Offset.zero & size, fill);
    if (scrollOffset < rowHeaderWidth) {
      final headerRect = Rect.fromLTWH(0, 0, rowHeaderWidth, size.height);
      canvas.drawRect(headerRect, Paint()..color = headerBackground);
      canvas.drawRect(headerRect, border);
      _paintText(
        canvas,
        '${row.rowIndex}',
        headerRect.deflate(6),
        TextStyle(
          color: textColor,
          fontSize: 11.5 * zoom,
          fontWeight: FontWeight.w700,
        ),
        TextAlign.center,
      );
    }

    final range = _visibleColumnRange(
      scrollOffset,
      viewportWidth,
      rowHeaderWidth,
      columnWidth,
      columnCount,
    );
    for (var column = range.$1; column <= range.$2; column++) {
      final left = rowHeaderWidth + column * columnWidth;
      final rect = Rect.fromLTWH(left, 0, columnWidth, size.height);
      canvas.drawRect(rect, border);
      final value = row.valueAt(column);
      if (value.isNotEmpty) {
        _paintText(
          canvas,
          value,
          rect.deflate(8),
          TextStyle(color: textColor, fontSize: 12 * zoom),
          TextAlign.left,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpreadsheetRowPainter oldDelegate) {
    return oldDelegate.row != row ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.viewportWidth != viewportWidth ||
        oldDelegate.columnWidth != columnWidth ||
        oldDelegate.zoom != zoom ||
        oldDelegate.isDark != isDark;
  }
}

(int, int) _visibleColumnRange(
  double offset,
  double viewportWidth,
  double rowHeaderWidth,
  double columnWidth,
  int columnCount,
) {
  final relativeStart = math.max(0.0, offset - rowHeaderWidth).toDouble();
  final relativeEnd = math
      .max(0.0, offset + viewportWidth - rowHeaderWidth)
      .toDouble();
  final start = (relativeStart / columnWidth)
      .floor()
      .clamp(0, columnCount - 1)
      .toInt();
  final end = (relativeEnd / columnWidth)
      .ceil()
      .clamp(0, columnCount - 1)
      .toInt();
  return (start, end);
}

void _paintText(
  Canvas canvas,
  String text,
  Rect rect,
  TextStyle style,
  TextAlign align,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: align,
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: math.max(0.0, rect.width).toDouble());

  final dx = switch (align) {
    TextAlign.center => rect.left + (rect.width - painter.width) / 2,
    TextAlign.right => rect.right - painter.width,
    _ => rect.left,
  };
  final dy = rect.top + (rect.height - painter.height) / 2;
  canvas.save();
  canvas.clipRect(rect);
  painter.paint(canvas, Offset(dx, dy));
  canvas.restore();
}

String _columnName(int index) {
  var value = index + 1;
  final chars = <String>[];
  while (value > 0) {
    value--;
    chars.insert(0, String.fromCharCode(65 + value % 26));
    value ~/= 26;
  }
  return chars.join();
}

class _SpreadsheetLimitBanner extends StatelessWidget {
  const _SpreadsheetLimitBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.amber.withValues(alpha: 0.14),
      child: const Text(
        'Very large workbook: preview is safely bounded to keep EduSheet responsive. The original file is unchanged.',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SpreadsheetLoadingState extends StatelessWidget {
  const _SpreadsheetLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('Preparing spreadsheet…'),
        ],
      ),
    );
  }
}

class _SpreadsheetErrorState extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _SpreadsheetErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final currentError = error;
    final readError = currentError is DocumentFileReadException
        ? currentError
        : null;
    final cloudUnavailable =
        readError?.kind == DocumentFileReadFailure.cloudProviderUnavailable;
    final title = cloudUnavailable
        ? 'Cloud spreadsheet is not available offline'
        : 'Unable to read this spreadsheet';
    final message = cloudUnavailable
        ? 'Start your cloud sync provider or make the file available offline, then retry.'
        : readError?.message ??
              'The spreadsheet could not be decoded. The file may be unavailable, incomplete, or damaged.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                cloudUnavailable
                    ? Icons.cloud_off_outlined
                    : Icons.error_outline,
                size: 54,
                color: cloudUnavailable
                    ? Colors.orangeAccent
                    : Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
