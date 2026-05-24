import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:xml/xml.dart' as xml;

import '../../domain/models/document_model.dart';

class FilePreviewScreen extends StatefulWidget {
  final DocumentFile document;

  const FilePreviewScreen({super.key, required this.document});

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  static const double _minZoom = 0.6;
  static const double _maxZoom = 3.0;
  static const double _zoomStep = 0.25;

  late final PdfViewerController _pdfController;
  Future<String>? _textFuture;
  Future<List<_SpreadsheetSheet>>? _spreadsheetFuture;
  Future<List<_PresentationSlide>>? _presentationFuture;

  double _zoom = 1.0;
  String? _pdfError;
  int _currentPdfPage = 1;
  int _pdfPageCount = 0;
  int _selectedSheetIndex = 0;
  int _selectedSlideIndex = 0;

  DocumentFile get document => widget.document;

  bool get _isOfficeDocument {
    return document.type == DocumentType.word ||
        document.type == DocumentType.excel ||
        document.type == DocumentType.powerpoint;
  }

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _preparePreviewFutures();
  }

  void _preparePreviewFutures() {
    switch (document.type) {
      case DocumentType.text:
        _textFuture = File(document.path).readAsString();
        break;
      case DocumentType.excel:
        if (document.extension == '.csv') {
          _spreadsheetFuture = _readCsv(File(document.path));
        } else if (document.extension == '.xlsx') {
          _spreadsheetFuture = _readXlsx(File(document.path));
        }
        break;
      case DocumentType.powerpoint:
        if (document.extension == '.pptx') {
          _presentationFuture = _readPptx(File(document.path));
        }
        break;
      case DocumentType.pdf:
      case DocumentType.word:
      case DocumentType.other:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF101214)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          document.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => OpenFilex.open(document.path),
            tooltip: 'Open externally',
          ),
        ],
      ),
      body: Column(
        children: [
          _FileSummary(document: document, isDark: isDark),
          if (_isOfficeDocument)
            _OfficeFidelityBanner(document: document, isDark: isDark),
          _ZoomToolbar(
            zoom: _zoom,
            canZoomOut: _zoom > _minZoom,
            canZoomIn: _zoom < _maxZoom,
            pageLabel: _pageLabel,
            onZoomOut: () => _setZoom(_zoom - _zoomStep),
            onZoomIn: () => _setZoom(_zoom + _zoomStep),
            onReset: () => _setZoom(1.0),
          ),
          Expanded(child: _buildPreviewer(context, isDark)),
        ],
      ),
    );
  }

  String? get _pageLabel {
    if (document.type == DocumentType.pdf && _pdfPageCount > 0) {
      return 'Page $_currentPdfPage / $_pdfPageCount';
    }
    if (document.type == DocumentType.powerpoint) {
      return 'Slide ${_selectedSlideIndex + 1}';
    }
    return null;
  }

  void _setZoom(double value) {
    final next = value.clamp(_minZoom, _maxZoom).toDouble();
    if ((next - _zoom).abs() < 0.001) return;

    setState(() => _zoom = next);
    if (document.type == DocumentType.pdf) {
      _pdfController.zoomLevel = next;
    }
  }

  Widget _buildPreviewer(BuildContext context, bool isDark) {
    switch (document.type) {
      case DocumentType.pdf:
        return _buildPdfPreview(context, isDark);
      case DocumentType.word:
        if (document.extension == '.docx') {
          return _buildWordPreview(context, isDark);
        }
        return _buildUnsupportedState(
          context,
          'Simple Word preview supports DOCX files. Open this ${document.extension.toUpperCase()} file in Office/WPS for the closest PC view.',
        );
      case DocumentType.text:
        return _buildTextPreview(context, isDark);
      case DocumentType.excel:
        return _buildExcelPreview(context, isDark);
      case DocumentType.powerpoint:
        return _buildPowerPointPreview(context, isDark);
      case DocumentType.other:
        return _buildUnsupportedState(
          context,
          'In-app preview for ${document.extension.toUpperCase()} is coming soon. Use the external opener for now.',
        );
    }
  }

  Widget _buildPdfPreview(BuildContext context, bool isDark) {
    if (_pdfError != null) {
      return _buildErrorState(context, _pdfError!);
    }

    return ColoredBox(
      color: isDark ? const Color(0xFF171A1F) : const Color(0xFFE9EDF2),
      child: SfPdfViewer.file(
        File(document.path),
        controller: _pdfController,
        maxZoomLevel: _maxZoom,
        enableDoubleTapZooming: true,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        onDocumentLoaded: (details) {
          setState(() {
            _pdfError = null;
            _pdfPageCount = details.document.pages.count;
          });
        },
        onPageChanged: (details) {
          setState(() => _currentPdfPage = details.newPageNumber);
        },
        onZoomLevelChanged: (details) {
          if ((details.newZoomLevel - _zoom).abs() > 0.001) {
            setState(
              () => _zoom = details.newZoomLevel.clamp(_minZoom, _maxZoom),
            );
          }
        },
        onDocumentLoadFailed: (details) {
          setState(() => _pdfError = 'PDF load failed: ${details.description}');
        },
      ),
    );
  }

  Widget _buildWordPreview(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;
        final horizontalPadding = isCompact ? 8.0 : 24.0;
        final basePageWidth = isCompact
            ? constraints.maxWidth - (horizontalPadding * 2)
            : 794.0;

        return ColoredBox(
          color: isDark ? const Color(0xFF171A1F) : const Color(0xFFE9EDF2),
          child: DocxView.file(
            File(document.path),
            key: ValueKey('docx-${document.path}-${_zoom.toStringAsFixed(2)}'),
            config: DocxViewConfig(
              enableZoom: true,
              minScale: _minZoom,
              maxScale: _maxZoom,
              pageMode: DocxPageMode.paged,
              pageWidth: (basePageWidth * _zoom).clamp(320.0, 1400.0),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 12,
              ),
              backgroundColor: isDark
                  ? const Color(0xFF171A1F)
                  : const Color(0xFFE9EDF2),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextPreview(BuildContext context, bool isDark) {
    return FutureBuilder<String>(
      future: _textFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(context, 'Failed to read text file.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: SelectableText(
            snapshot.data!,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14 * _zoom,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        );
      },
    );
  }

  Widget _buildExcelPreview(BuildContext context, bool isDark) {
    if (document.extension != '.xlsx' && document.extension != '.csv') {
      return _buildUnsupportedState(
        context,
        'Simple spreadsheet preview supports XLSX and CSV files. Open this ${document.extension.toUpperCase()} file in Office/WPS for the closest PC view.',
      );
    }

    return FutureBuilder<List<_SpreadsheetSheet>>(
      future: _spreadsheetFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildErrorState(context, 'Failed to read spreadsheet file.');
        }
        final sheets = snapshot.data ?? [];
        if (sheets.isEmpty) {
          return _buildUnsupportedState(
            context,
            'No readable spreadsheet data was found. You can still open this file in Office/WPS.',
          );
        }
        if (_selectedSheetIndex >= sheets.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedSheetIndex = 0);
          });
        }

        final selectedSheet =
            sheets[_selectedSheetIndex.clamp(0, sheets.length - 1)];
        return Column(
          children: [
            _SheetTabs(
              sheets: sheets,
              selectedIndex: _selectedSheetIndex,
              onSelected: (index) =>
                  setState(() => _selectedSheetIndex = index),
              isDark: isDark,
            ),
            Expanded(
              child: _SpreadsheetCanvas(
                sheet: selectedSheet,
                zoom: _zoom,
                isDark: isDark,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPowerPointPreview(BuildContext context, bool isDark) {
    if (document.extension != '.pptx') {
      return _buildUnsupportedState(
        context,
        'Simple presentation preview supports PPTX files. Open this ${document.extension.toUpperCase()} file in Office/WPS for the closest PC view.',
      );
    }

    return FutureBuilder<List<_PresentationSlide>>(
      future: _presentationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildErrorState(context, 'Failed to read presentation file.');
        }
        final slides = snapshot.data ?? [];
        if (slides.isEmpty) {
          return _buildUnsupportedState(
            context,
            'No readable slide text was found. You can still open this file in Office/WPS.',
          );
        }
        if (_selectedSlideIndex >= slides.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedSlideIndex = 0);
          });
        }

        final selectedSlide =
            slides[_selectedSlideIndex.clamp(0, slides.length - 1)];
        return Column(
          children: [
            _SlideNavigator(
              currentIndex: _selectedSlideIndex,
              slideCount: slides.length,
              onPrevious: _selectedSlideIndex == 0
                  ? null
                  : () => setState(() => _selectedSlideIndex--),
              onNext: _selectedSlideIndex == slides.length - 1
                  ? null
                  : () => setState(() => _selectedSlideIndex++),
              isDark: isDark,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final baseWidth = math.min(
                    900.0,
                    math.max(320.0, constraints.maxWidth - 32),
                  );
                  final width = baseWidth * _zoom;
                  final height = width * 9 / 16;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: math.max(width, constraints.maxWidth - 32),
                        child: Center(
                          child: _SlideCanvas(
                            slide: selectedSlide,
                            width: width,
                            height: height,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUnsupportedState(BuildContext context, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1F26) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description_outlined,
                size: 76,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => OpenFilex.open(document.path),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open externally'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<_SpreadsheetSheet>> _readCsv(File file) async {
    final text = await file.readAsString();
    final rows = const LineSplitter()
        .convert(text)
        .take(220)
        .map(_parseCsvLine)
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .toList();

    return [_SpreadsheetSheet(name: document.name, rows: rows)];
  }

  List<String> _parseCsvLine(String line) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        cells.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    cells.add(buffer.toString());
    return cells;
  }

  Future<List<_SpreadsheetSheet>> _readXlsx(File file) async {
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final files = {for (final entry in archive.files) entry.name: entry};
    final sharedStrings = _readSharedStrings(files);
    final sheetRefs = _readSheetRefs(files);
    final sheets = <_SpreadsheetSheet>[];

    for (final sheetRef in sheetRefs) {
      final entry = files[sheetRef.path];
      if (entry == null) continue;

      final sheetXml = utf8.decode(entry.content);
      final parsed = xml.XmlDocument.parse(sheetXml);
      final rows = <List<String>>[];
      var maxColumns = 0;

      final rowElements = parsed.descendants
          .whereType<xml.XmlElement>()
          .where((element) => element.name.local == 'row')
          .take(220);

      for (final row in rowElements) {
        final cells = <int, String>{};
        for (final cell in row.childElements.where(
          (element) => element.name.local == 'c',
        )) {
          final index = _columnIndex(cell.getAttribute('r'));
          final value = _cellValue(cell, sharedStrings);
          if (value.trim().isNotEmpty) {
            cells[index] = value;
            if (index + 1 > maxColumns) maxColumns = index + 1;
          }
        }
        if (cells.isNotEmpty) {
          final rowValues = List<String>.filled(
            cells.keys.reduce((a, b) => a > b ? a : b) + 1,
            '',
          );
          cells.forEach((index, value) => rowValues[index] = value);
          rows.add(rowValues);
        }
      }

      final visibleColumns = maxColumns.clamp(1, 28);
      sheets.add(
        _SpreadsheetSheet(
          name: sheetRef.name,
          rows: rows
              .map(
                (row) => List.generate(
                  visibleColumns,
                  (index) => index < row.length ? row[index] : '',
                ),
              )
              .toList(),
        ),
      );
    }

    return sheets.where((sheet) => sheet.rows.isNotEmpty).toList();
  }

  List<String> _readSharedStrings(Map<String, ArchiveFile> files) {
    final entry = files['xl/sharedStrings.xml'];
    if (entry == null) return [];

    final parsed = xml.XmlDocument.parse(utf8.decode(entry.content));
    return parsed.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 'si')
        .map(
          (element) => element.descendants
              .whereType<xml.XmlElement>()
              .where((child) => child.name.local == 't')
              .map((child) => child.innerText)
              .join(),
        )
        .toList();
  }

  List<_SheetRef> _readSheetRefs(Map<String, ArchiveFile> files) {
    final workbook = files['xl/workbook.xml'];
    final rels = files['xl/_rels/workbook.xml.rels'];
    if (workbook == null || rels == null) return [];

    final relTargets = <String, String>{};
    final relXml = xml.XmlDocument.parse(utf8.decode(rels.content));
    for (final rel in relXml.descendants.whereType<xml.XmlElement>()) {
      if (rel.name.local != 'Relationship') continue;
      final id = rel.getAttribute('Id');
      final target = rel.getAttribute('Target');
      if (id != null && target != null) {
        relTargets[id] = _normalizeXlsxPath(target);
      }
    }

    final workbookXml = xml.XmlDocument.parse(utf8.decode(workbook.content));
    return workbookXml.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 'sheet')
        .map((sheet) {
          final relId = sheet.attributes
              .where((attr) => attr.name.local == 'id')
              .map((attr) => attr.value)
              .firstOrNull;
          return _SheetRef(
            name: sheet.getAttribute('name') ?? 'Sheet',
            path: relTargets[relId] ?? '',
          );
        })
        .where((sheet) => sheet.path.isNotEmpty)
        .toList();
  }

  String _normalizeXlsxPath(String target) {
    if (target.startsWith('/')) return target.substring(1);
    if (target.startsWith('xl/')) return target;
    return 'xl/$target';
  }

  int _columnIndex(String? cellRef) {
    final letters = RegExp(r'^[A-Z]+').stringMatch(cellRef ?? '') ?? 'A';
    var index = 0;
    for (final codeUnit in letters.codeUnits) {
      index = (index * 26) + (codeUnit - 64);
    }
    return index - 1;
  }

  String _cellValue(xml.XmlElement cell, List<String> sharedStrings) {
    final type = cell.getAttribute('t');
    if (type == 'inlineStr') {
      return cell.descendants
          .whereType<xml.XmlElement>()
          .where((element) => element.name.local == 't')
          .map((element) => element.innerText)
          .join();
    }

    final raw = cell.childElements
        .where((element) => element.name.local == 'v')
        .map((element) => element.innerText)
        .firstOrNull;
    if (raw == null) return '';

    if (type == 's') {
      final index = int.tryParse(raw);
      if (index != null && index >= 0 && index < sharedStrings.length) {
        return sharedStrings[index];
      }
    }

    if (type == 'b') return raw == '1' ? 'TRUE' : 'FALSE';
    return raw;
  }

  Future<List<_PresentationSlide>> _readPptx(File file) async {
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final slideFiles =
        archive.files
            .where(
              (entry) =>
                  RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(entry.name),
            )
            .toList()
          ..sort(
            (a, b) => _slideNumber(a.name).compareTo(_slideNumber(b.name)),
          );

    final slides = <_PresentationSlide>[];
    for (final entry in slideFiles) {
      final parsed = xml.XmlDocument.parse(utf8.decode(entry.content));
      final text = parsed.descendants
          .whereType<xml.XmlElement>()
          .where((element) => element.name.local == 't')
          .map((element) => element.innerText.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      slides.add(
        _PresentationSlide(number: _slideNumber(entry.name), text: text),
      );
    }
    return slides;
  }

  int _slideNumber(String path) {
    return int.tryParse(
          RegExp(r'slide(\d+)\.xml').firstMatch(path)?.group(1) ?? '',
        ) ??
        0;
  }
}

class _FileSummary extends StatelessWidget {
  final DocumentFile document;
  final bool isDark;

  const _FileSummary({required this.document, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(document.type);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1F26) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(_typeIcon(document.type), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.extension.replaceFirst('.', '').toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${document.sizeString} | ${document.path}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 12,
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

  IconData _typeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf;
      case DocumentType.word:
        return Icons.description;
      case DocumentType.excel:
        return Icons.table_chart;
      case DocumentType.powerpoint:
        return Icons.slideshow;
      case DocumentType.text:
        return Icons.text_snippet;
      case DocumentType.other:
        return Icons.insert_drive_file;
    }
  }

  Color _typeColor(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Colors.redAccent;
      case DocumentType.word:
        return Colors.blue;
      case DocumentType.excel:
        return Colors.green;
      case DocumentType.powerpoint:
        return Colors.deepOrange;
      case DocumentType.text:
        return Colors.blueGrey;
      case DocumentType.other:
        return Colors.blueGrey;
    }
  }
}

class _OfficeFidelityBanner extends StatelessWidget {
  final DocumentFile document;
  final bool isDark;

  const _OfficeFidelityBanner({required this.document, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(document.type);

    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1F26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Simple preview. Office/WPS gives the closest PC view.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => OpenFilex.open(document.path),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Office'),
            style: TextButton.styleFrom(
              foregroundColor: color,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(DocumentType type) {
    switch (type) {
      case DocumentType.word:
        return Colors.blue;
      case DocumentType.excel:
        return Colors.green;
      case DocumentType.powerpoint:
        return Colors.deepOrange;
      case DocumentType.pdf:
      case DocumentType.text:
      case DocumentType.other:
        return Colors.blueGrey;
    }
  }
}

class _ZoomToolbar extends StatelessWidget {
  final double zoom;
  final bool canZoomOut;
  final bool canZoomIn;
  final String? pageLabel;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onReset;

  const _ZoomToolbar({
    required this.zoom,
    required this.canZoomOut,
    required this.canZoomIn,
    required this.pageLabel,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 50,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1F26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: canZoomOut ? onZoomOut : null,
            icon: const Icon(Icons.remove),
            tooltip: 'Zoom out',
          ),
          SizedBox(
            width: 64,
            child: Text(
              '${(zoom * 100).round()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: canZoomIn ? onZoomIn : null,
            icon: const Icon(Icons.add),
            tooltip: 'Zoom in',
          ),
          IconButton(
            onPressed: onReset,
            icon: const Icon(Icons.fit_screen),
            tooltip: 'Reset zoom',
          ),
          const Spacer(),
          if (pageLabel != null)
            Flexible(
              child: Text(
                pageLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpreadsheetSheet {
  final String name;
  final List<List<String>> rows;

  const _SpreadsheetSheet({required this.name, required this.rows});
}

class _SheetRef {
  final String name;
  final String path;

  const _SheetRef({required this.name, required this.path});
}

class _PresentationSlide {
  final int number;
  final List<String> text;

  const _PresentationSlide({required this.number, required this.text});
}

class _SheetTabs extends StatelessWidget {
  final List<_SpreadsheetSheet> sheets;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool isDark;

  const _SheetTabs({
    required this.sheets,
    required this.selectedIndex,
    required this.onSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sheets.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = selectedIndex == index;
          return ChoiceChip(
            label: Text(
              sheets[index].name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            selected: selected,
            onSelected: (_) => onSelected(index),
            selectedColor: Colors.green.withValues(alpha: 0.18),
            labelStyle: TextStyle(
              color: selected
                  ? Colors.green.shade700
                  : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          );
        },
      ),
    );
  }
}

class _SpreadsheetCanvas extends StatelessWidget {
  final _SpreadsheetSheet sheet;
  final double zoom;
  final bool isDark;

  const _SpreadsheetCanvas({
    required this.sheet,
    required this.zoom,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final rows = sheet.rows.take(180).toList();
    final columnCount = rows.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    final safeColumnCount = columnCount.clamp(1, 28);
    final fontSize = 12.0 * zoom;
    final rowHeaderWidth = 52.0 * zoom;
    final columnWidths = List.generate(safeColumnCount, (index) {
      final longest = rows.fold<int>(_columnName(index).length, (max, row) {
        if (index >= row.length) return max;
        final length = row[index].trim().length;
        return length > max ? length : max;
      });
      return (math.max(96.0, math.min(220.0, longest * 9.0 + 36.0))) * zoom;
    });
    final rowHeight = 42.0 * zoom;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.grid_on, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${sheet.name}  |  ${rows.length} rows x $safeColumnCount columns',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: rowHeight,
                dataRowMinHeight: rowHeight,
                dataRowMaxHeight: rowHeight * 1.4,
                horizontalMargin: 10 * zoom,
                columnSpacing: 10 * zoom,
                headingTextStyle: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                ),
                dataTextStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: fontSize,
                ),
                headingRowColor: WidgetStatePropertyAll(
                  isDark ? const Color(0xFF263224) : Colors.green.shade50,
                ),
                dataRowColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.green.withValues(alpha: 0.08);
                  }
                  return isDark ? const Color(0xFF171A1F) : Colors.white;
                }),
                border: TableBorder.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
                columns: [
                  const DataColumn(label: Text('#')),
                  ...List.generate(
                    safeColumnCount,
                    (index) => DataColumn(label: Text(_columnName(index))),
                  ),
                ],
                rows: rows.asMap().entries.map((entry) {
                  final row = entry.value;
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: rowHeaderWidth,
                          child: Text(
                            '${entry.key + 1}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      ...List.generate(
                        safeColumnCount,
                        (index) => DataCell(
                          SizedBox(
                            width: columnWidths[index],
                            child: Text(
                              index < row.length ? row[index] : '',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _columnName(int index) {
    var value = index + 1;
    final chars = <String>[];
    while (value > 0) {
      value--;
      chars.insert(0, String.fromCharCode(65 + (value % 26)));
      value ~/= 26;
    }
    return chars.join();
  }
}

class _SlideNavigator extends StatelessWidget {
  final int currentIndex;
  final int slideCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool isDark;

  const _SlideNavigator({
    required this.currentIndex,
    required this.slideCount,
    required this.onPrevious,
    required this.onNext,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1F26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous slide',
          ),
          Expanded(
            child: Text(
              'Slide ${currentIndex + 1} of $slideCount',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next slide',
          ),
        ],
      ),
    );
  }
}

class _SlideCanvas extends StatelessWidget {
  final _PresentationSlide slide;
  final double width;
  final double height;
  final bool isDark;

  const _SlideCanvas({
    required this.slide,
    required this.width,
    required this.height,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final title = slide.text.isEmpty
        ? 'Slide ${slide.number}'
        : slide.text.first;
    final body = slide.text.length <= 1
        ? <String>[]
        : slide.text.skip(1).toList();

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(width * 0.045),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1F26) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.slideshow, color: Colors.deepOrange, size: 18),
              const SizedBox(width: 8),
              Text(
                'Slide ${slide.number}',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w800,
                  fontSize: width * 0.017,
                ),
              ),
            ],
          ),
          SizedBox(height: width * 0.035),
          Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: width * 0.04,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: width * 0.03),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                body.isEmpty
                    ? 'No additional readable text on this slide.'
                    : body.join('\n'),
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: width * 0.022,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
