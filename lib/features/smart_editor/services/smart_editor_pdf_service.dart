import 'dart:math' as math;
import 'dart:typed_data';

import 'package:edusheet/features/pdf/services/math/pdf_math_typesetter.dart';
import 'package:edusheet/features/pdf/services/pdf_export_theme_service.dart';
import 'package:edusheet/features/pdf/services/shaping/pdf_complex_text_service.dart';
import 'package:edusheet/features/smart_editor/application/smart_editor_export_projection.dart';
import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_geometry_rasterizer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SmartEditorPdfExportResult {
  const SmartEditorPdfExportResult({
    required this.bytes,
    this.warnings = const <String>[],
  });

  final Uint8List bytes;
  final List<String> warnings;
}

class SmartEditorPdfService {
  const SmartEditorPdfService({
    this.geometryRasterizer = const SmartEditorGeometryRasterizer(),
  });

  static const PdfMathTypesetter _mathTypesetter = PdfMathTypesetter();
  final SmartEditorGeometryRasterizer geometryRasterizer;

  Future<SmartEditorPdfExportResult> export(SmartDocument document) async {
    final projection = SmartEditorExportProjection.fromDocument(document);
    final warnings = <String>[];
    final allText = StringBuffer()
      ..write(document.header.text)
      ..write('\n')
      ..write(document.footer.text);
    for (final block in projection.blocks) {
      if (block is SmartEditorExportParagraph) {
        for (final inline in block.inlines) {
          allText.write(inline.plainText);
        }
      } else if (block is SmartEditorExportTable) {
        for (final row in block.payload.rows) {
          for (final cell in row.cells) {
            allText.write(cell.text);
          }
        }
      }
    }
    final complex = PdfComplexTextService.containsComplexScript(allText.toString());
    final theme = await PdfExportThemeService.loadTheme(requireUnicode: complex);
    if (complex) await PdfComplexTextService.ensureInitialized();

    final pdf = pw.Document(theme: theme);
    final layout = document.pageLayout;
    final size = _pageSize(layout);
    final pageFormat = PdfPageFormat(size.$1, size.$2);
    final contentWidth = math.max(
      72.0,
      size.$1 - layout.leftMarginPoints - layout.rightMarginPoints,
    );
    final renderer = _SmartPdfRenderer(
      contentWidth: contentWidth,
      warnings: warnings,
      rasterizer: geometryRasterizer,
    );
    final widgets = await renderer.render(projection.blocks);

    pdf.addPage(
      pw.MultiPage(
        maxPages: 500,
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.fromLTRB(
            layout.leftMarginPoints,
            layout.topMarginPoints,
            layout.rightMarginPoints,
            layout.bottomMarginPoints,
          ),
          buildBackground: layout.borderStyle == SmartDocumentPageBorderStyle.none
              ? null
              : (_) => _pageBorder(layout.borderStyle),
        ),
        header: document.header.enabled && document.header.text.trim().isNotEmpty
            ? (_) => _headerFooter(document.header, header: true)
            : null,
        footer: document.footer.enabled && document.footer.text.trim().isNotEmpty
            ? (_) => _headerFooter(document.footer, header: false)
            : null,
        build: (_) => widgets,
      ),
    );

    return SmartEditorPdfExportResult(
      bytes: Uint8List.fromList(await pdf.save()),
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  static (double, double) _pageSize(SmartDocumentPageLayout layout) {
    var width = layout.pageSize == SmartDocumentPageSize.a4 ? 595.3 : 612.0;
    var height = layout.pageSize == SmartDocumentPageSize.a4 ? 841.9 : 792.0;
    if (layout.orientation == SmartDocumentOrientation.landscape) {
      final value = width;
      width = height;
      height = value;
    }
    return (width, height);
  }

  static pw.Widget _pageBorder(SmartDocumentPageBorderStyle style) {
    final double width = switch (style) {
      SmartDocumentPageBorderStyle.subtle => 0.4,
      SmartDocumentPageBorderStyle.solid => 0.8,
      SmartDocumentPageBorderStyle.doubleLine => 1.2,
      SmartDocumentPageBorderStyle.none => 0,
    };
    if (width <= 0) return pw.SizedBox();
    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(18),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600, width: width),
          ),
          child: style == SmartDocumentPageBorderStyle.doubleLine
              ? pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.grey600,
                        width: 0.6,
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  static pw.Widget _headerFooter(
    SmartDocumentHeaderFooter config, {
    required bool header,
  }) {
    final align = switch (config.alignment) {
      SmartDocumentHeaderFooterAlignment.left => pw.TextAlign.left,
      SmartDocumentHeaderFooterAlignment.center => pw.TextAlign.center,
      SmartDocumentHeaderFooterAlignment.right => pw.TextAlign.right,
    };
    final content = PdfComplexTextService.styledText(
      config.text,
      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      textAlign: align,
    );
    final border = config.showDivider
        ? (header
            ? const pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.5),
              )
            : const pw.Border(
                top: pw.BorderSide(color: PdfColors.grey600, width: 0.5),
              ))
        : null;
    return pw.Container(
      decoration: border == null ? null : pw.BoxDecoration(border: border),
      padding: pw.EdgeInsets.only(
        bottom: header ? 4 : 0,
        top: header ? 0 : 4,
      ),
      child: content,
    );
  }
}

class _SmartPdfRenderer {
  const _SmartPdfRenderer({
    required this.contentWidth,
    required this.warnings,
    required this.rasterizer,
  });

  final double contentWidth;
  final List<String> warnings;
  final SmartEditorGeometryRasterizer rasterizer;

  Future<List<pw.Widget>> render(List<SmartEditorExportBlock> blocks) async {
    final result = <pw.Widget>[];
    final orderedCounters = <int, int>{};
    for (final block in blocks) {
      switch (block) {
        case SmartEditorExportParagraph():
          result.add(_paragraph(block, orderedCounters));
        case SmartEditorExportBreak():
          if (block.type == 'page') {
            result.add(pw.NewPage());
          } else {
            result.add(pw.SizedBox(height: 0));
          }
        case SmartEditorExportImage():
          if (block.payload.bytes.isEmpty) {
            result.add(_placeholder('[Image unavailable]'));
          } else {
            try {
              result.add(_image(
                block.payload.bytes,
                block.payload.widthPoints,
                block.payload.heightPoints,
              ));
            } catch (_) {
              warnings.add('One imported image could not be rendered in PDF.');
              result.add(_placeholder('[Unsupported image]'));
            }
          }
        case SmartEditorExportGeometry():
          final diagram = block.layout.diagram;
          if (diagram == null) {
            warnings.add('One geometry object had no embedded diagram payload.');
            result.add(_placeholder('[Geometry diagram]'));
          } else {
            try {
              final png = await rasterizer.toPng(diagram);
              result.add(
                _image(
                  png,
                  (diagram.canvasSize.width * block.layout.widthFactor)
                      .clamp(120.0, contentWidth)
                      .toDouble(),
                  block.layout.height,
                  alignmentX: block.layout.effectiveAlignmentX,
                ),
              );
            } catch (_) {
              warnings.add('One geometry object could not be rendered in PDF.');
              result.add(_placeholder('[Geometry diagram]'));
            }
          }
        case SmartEditorExportTable():
          result.add(_table(block));
      }
    }
    return result;
  }

  pw.Widget _paragraph(
    SmartEditorExportParagraph paragraph,
    Map<int, int> orderedCounters,
  ) {
    final attrs = paragraph.attributes;
    final indent = _int(attrs['indent']) ?? 0;
    final list = attrs['list']?.toString();
    String prefix = '';
    if (list == 'bullet') {
      prefix = '• ';
    } else if (list == 'ordered') {
      final next = (orderedCounters[indent] ?? 0) + 1;
      orderedCounters[indent] = next;
      prefix = '$next. ';
    } else {
      orderedCounters.remove(indent);
    }

    final align = switch (attrs['align']?.toString()) {
      'center' => pw.WrapAlignment.center,
      'right' => pw.WrapAlignment.end,
      'justify' => pw.WrapAlignment.spaceBetween,
      _ => pw.WrapAlignment.start,
    };
    final header = _int(attrs['header']);
    final defaultSize = switch (header) {
      1 => 20.0,
      2 => 16.0,
      3 => 14.0,
      _ => 11.0,
    };
    final pieces = <pw.Widget>[];
    if (prefix.isNotEmpty) {
      pieces.add(_text(prefix, <String, dynamic>{'bold': header != null}, defaultSize));
    }
    for (final inline in paragraph.inlines) {
      if (inline is SmartEditorExportText) {
        pieces.add(_text(inline.text, inline.attributes, defaultSize));
      } else if (inline is SmartEditorExportMath) {
        final mathWidget = SmartEditorPdfService._mathTypesetter.buildSource(
          inline.expression.latex,
          fontSize: math.max(10.0, defaultSize),
        );
        if (mathWidget == null) {
          warnings.add(
            'One equation used unsupported PDF math syntax and was exported as readable text.',
          );
          pieces.add(_text(inline.plainText, const <String, dynamic>{}, defaultSize));
        } else {
          pieces.add(
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 2),
              child: mathWidget,
            ),
          );
        }
      }
    }
    if (pieces.isEmpty) pieces.add(pw.SizedBox(height: defaultSize));
    return pw.Padding(
      padding: pw.EdgeInsets.only(
        left: indent * 24.0,
        bottom: 5,
      ),
      child: pw.Wrap(
        alignment: align,
        crossAxisAlignment: pw.WrapCrossAlignment.center,
        spacing: 0,
        runSpacing: 2,
        children: pieces,
      ),
    );
  }

  pw.Widget _text(
    String text,
    Map<String, dynamic> attrs,
    double defaultSize,
  ) {
    final size = double.tryParse(attrs['size']?.toString() ?? '') ?? defaultSize;
    final color = _pdfColor(attrs['color']) ?? PdfColors.black;
    final style = pw.TextStyle(
      fontSize: size.clamp(6.0, 72.0).toDouble(),
      fontWeight: attrs['bold'] == true ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontStyle: attrs['italic'] == true ? pw.FontStyle.italic : pw.FontStyle.normal,
      color: color,
      decoration: attrs['underline'] == true
          ? pw.TextDecoration.underline
          : attrs['strike'] == true
              ? pw.TextDecoration.lineThrough
              : null,
      background: _pdfColor(attrs['background']) == null
          ? null
          : pw.BoxDecoration(color: _pdfColor(attrs['background'])),
    );
    final textWidget = PdfComplexTextService.styledText(text, style: style);
    final link = attrs['link']?.toString().trim();
    return link == null || link.isEmpty
        ? textWidget
        : pw.UrlLink(destination: link, child: textWidget);
  }

  pw.Widget _image(
    Uint8List bytes,
    double width,
    double height, {
    double alignmentX = 0,
  }) {
    final safeWidth = width.clamp(48.0, contentWidth).toDouble();
    final safeHeight = height.clamp(36.0, 560.0).toDouble();
    final alignment = alignmentX < -0.35
        ? pw.Alignment.centerLeft
        : alignmentX > 0.35
            ? pw.Alignment.centerRight
            : pw.Alignment.center;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Align(
        alignment: alignment,
        child: pw.Image(
          pw.MemoryImage(bytes),
          width: safeWidth,
          height: safeHeight,
          fit: pw.BoxFit.contain,
        ),
      ),
    );
  }

  pw.Widget _table(SmartEditorExportTable block) {
    final table = block.payload;
    if (table.rows.isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Table(
        border: table.showBorders
            ? pw.TableBorder.all(color: PdfColors.grey500, width: 0.5)
            : null,
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          for (final row in table.rows)
            pw.TableRow(
              decoration: row.header
                  ? const pw.BoxDecoration(color: PdfColors.grey200)
                  : null,
              children: [
                for (final cell in row.cells)
                  pw.Container(
                    color: _pdfColor(cell.shadingHex),
                    padding: const pw.EdgeInsets.all(5),
                    child: PdfComplexTextService.styledText(
                      cell.text,
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: row.header ? pw.FontWeight.bold : null,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  pw.Widget _placeholder(String text) => pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 6),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
        ),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
      );

  static int? _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static PdfColor? _pdfColor(Object? value) {
    final raw = value?.toString().replaceAll('#', '').trim();
    if (raw == null || !RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(raw)) return null;
    return PdfColor.fromInt(0xFF000000 | int.parse(raw, radix: 16));
  }
}
