import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:edusheet/features/pdf/services/pdf_export_theme_service.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class DocxPdfRenderer {
  DocxPdfRenderer._();

  static Future<List<int>> render(
    ConversionDocument document, {
    bool Function()? shouldCancel,
    void Function(int current, int total)? onSection,
  }) async {
    final theme = await PdfExportThemeService.loadTheme();
    final fontResolver = _DocxFontResolver();
    await fontResolver.preload(document);
    final pdf = pw.Document(theme: theme);

    for (var sectionIndex = 0; sectionIndex < document.sections.length; sectionIndex++) {
      await Future<void>.delayed(Duration.zero);
      if (shouldCancel?.call() ?? false) {
        throw const _DocxPdfRenderCancelled();
      }
      onSection?.call(sectionIndex + 1, document.sections.length);
      final section = document.sections[sectionIndex];
      final page = section.page;
      final contentWidth = math.max(
        48.0,
        page.widthPoints - page.marginLeftPoints - page.marginRightPoints,
      );
      final renderer = _SectionRenderer(
        fontResolver: fontResolver,
        contentWidth: contentWidth,
      );
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat(page.widthPoints, page.heightPoints),
            margin: pw.EdgeInsets.fromLTRB(
              page.marginLeftPoints,
              page.marginTopPoints,
              page.marginRightPoints,
              page.marginBottomPoints,
            ),
          ),
          header: section.headerBlocks.isEmpty
              ? null
              : (context) => pw.Padding(
                  padding: pw.EdgeInsets.only(
                    bottom: math.max(4, page.headerDistancePoints / 4),
                  ),
                  child: renderer.renderStory(
                    section.headerBlocks,
                    pageNumber: context.pageNumber,
                    pageCount: context.pagesCount,
                  ),
                ),
          footer: section.footerBlocks.isEmpty
              ? null
              : (context) => pw.Padding(
                  padding: pw.EdgeInsets.only(
                    top: math.max(4, page.footerDistancePoints / 4),
                  ),
                  child: renderer.renderStory(
                    section.footerBlocks,
                    pageNumber: context.pageNumber,
                    pageCount: context.pagesCount,
                  ),
                ),
          build: (context) => renderer.renderBlocks(section.blocks),
        ),
      );
    }

    if (shouldCancel?.call() ?? false) {
      throw const _DocxPdfRenderCancelled();
    }
    return pdf.save();
  }
}

class _SectionRenderer {
  _SectionRenderer({required this.fontResolver, required this.contentWidth});

  final _DocxFontResolver fontResolver;
  final double contentWidth;

  List<pw.Widget> renderBlocks(
    List<ConversionBlock> blocks, {
    int? pageNumber,
    int? pageCount,
  }) {
    final widgets = <pw.Widget>[];
    for (final block in blocks) {
      if (block case final ConversionParagraph paragraph) {
        if (paragraph.pageBreakBefore && widgets.isNotEmpty) {
          widgets.add(pw.NewPage());
        }
        widgets.add(
          _paragraph(
            paragraph,
            pageNumber: pageNumber,
            pageCount: pageCount,
          ),
        );
      } else if (block case final ConversionOpaqueOoxmlBlock opaque) {
        if (opaque.fallbackBlocks.isNotEmpty) {
          widgets.addAll(
            renderBlocks(
              opaque.fallbackBlocks,
              pageNumber: pageNumber,
              pageCount: pageCount,
            ),
          );
        } else {
          widgets.add(
            pw.Text(
              '[Word ${opaque.featureKind} preserved]',
              style: const pw.TextStyle(fontSize: 9),
            ),
          );
        }
      } else if (block case final ConversionTable table) {
        widgets.add(
          _table(
            table,
            pageNumber: pageNumber,
            pageCount: pageCount,
          ),
        );
      }
    }
    return widgets;
  }

  pw.Widget renderStory(
    List<ConversionBlock> blocks, {
    int? pageNumber,
    int? pageCount,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: renderBlocks(
        blocks,
        pageNumber: pageNumber,
        pageCount: pageCount,
      ),
    );
  }

  pw.Widget _paragraph(
    ConversionParagraph paragraph, {
    int? pageNumber,
    int? pageCount,
  }) {
    final content = <pw.Widget>[];
    if (paragraph.inlines.isNotEmpty ||
        (paragraph.listLabel?.isNotEmpty ?? false)) {
      content.add(
        _richParagraphText(
          paragraph,
          pageNumber: pageNumber,
          pageCount: pageCount,
        ),
      );
    } else {
      content.add(pw.SizedBox(height: 8));
    }

    final leftIndent = math.max(0.0, paragraph.leftIndentPoints);
    final rightIndent = math.max(0.0, paragraph.rightIndentPoints);
    final firstLine = paragraph.firstLineIndentPoints;
    final firstLinePadding = firstLine > 0 ? firstLine : 0.0;
    final hangingPadding = firstLine < 0 ? -firstLine : 0.0;

    return pw.Padding(
      padding: pw.EdgeInsets.only(
        top: math.max(0.0, paragraph.spaceBeforePoints),
        bottom: math.max(0.0, paragraph.spaceAfterPoints),
        left: leftIndent + hangingPadding,
        right: rightIndent,
      ),
      child: pw.Padding(
        padding: pw.EdgeInsets.only(left: firstLinePadding),
        child: pw.Column(
          crossAxisAlignment: _crossAxis(paragraph.alignment),
          children: content,
        ),
      ),
    );
  }

  pw.Widget _richParagraphText(
    ConversionParagraph paragraph, {
    int? pageNumber,
    int? pageCount,
  }) {
    final spans = <pw.InlineSpan>[];
    final listLabel = paragraph.listLabel;
    if (listLabel != null && listLabel.isNotEmpty) {
      final markerStyle = paragraph.listLabelStyle ??
          paragraph.inlines.whereType<ConversionTextRun>().firstOrNull?.style ??
          const ConversionTextStyle();
      spans.add(pw.TextSpan(text: listLabel, style: _textStyle(markerStyle)));
    }
    for (final inline in paragraph.inlines) {
      if (inline is ConversionTextRun && inline.text.isNotEmpty) {
        final link = inline.hyperlink;
        if (link == null || link.isEmpty) {
          spans.add(
            pw.TextSpan(text: inline.text, style: _textStyle(inline.style)),
          );
        } else {
          spans.add(
            pw.WidgetSpan(
              child: pw.UrlLink(
                destination: link,
                child: pw.Text(inline.text, style: _textStyle(inline.style)),
              ),
            ),
          );
        }
      } else if (inline is ConversionDynamicFieldRun) {
        spans.add(
          pw.TextSpan(
            text: _dynamicFieldText(
              inline.field,
              pageNumber: pageNumber,
              pageCount: pageCount,
            ),
            style: _textStyle(inline.style),
          ),
        );
      } else if (inline is ConversionOpaqueOoxmlRun) {
        spans.add(
          pw.TextSpan(
            text: inline.fallbackText.isEmpty
                ? '[Word ${inline.featureKind} preserved]'
                : inline.fallbackText,
            style: _textStyle(inline.style),
          ),
        );
      } else if (inline is ConversionImageRun) {
        spans.add(pw.WidgetSpan(child: _image(inline)));
      }
    }
    return pw.RichText(
      textAlign: _textAlign(paragraph.alignment),
      text: pw.TextSpan(children: spans),
    );
  }

  pw.Widget _image(ConversionImageRun image) {
    var width = image.widthPoints > 0 ? image.widthPoints : 160.0;
    var height = image.heightPoints > 0 ? image.heightPoints : 120.0;
    if (width > contentWidth) {
      final scale = contentWidth / width;
      width *= scale;
      height *= scale;
    }
    final imageWidget = pw.Image(
      pw.MemoryImage(Uint8List.fromList(image.bytes)),
      width: width,
      height: height,
      fit: pw.BoxFit.contain,
    );
    final link = image.hyperlink;
    return link == null || link.isEmpty
        ? imageWidget
        : pw.UrlLink(destination: link, child: imageWidget);
  }

  pw.Widget _table(
    ConversionTable table, {
    int? pageNumber,
    int? pageCount,
  }) {
    if (table.rows.isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Table(
        border: table.showBorders
            ? pw.TableBorder.all(color: PdfColors.grey500, width: 0.5)
            : null,
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
        children: [
          for (final row in table.rows)
            pw.TableRow(
              decoration: row.isHeader
                  ? const pw.BoxDecoration(color: PdfColors.grey200)
                  : null,
              children: [
                for (final cell in row.cells)
                  pw.Container(
                    color: _pdfColor(cell.shadingHex),
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: renderBlocks(
                        cell.blocks,
                        pageNumber: pageNumber,
                        pageCount: pageCount,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static String _dynamicFieldText(
    ConversionDynamicField field, {
    int? pageNumber,
    int? pageCount,
  }) {
    return switch (field) {
      ConversionDynamicField.pageNumber => '${pageNumber ?? 1}',
      ConversionDynamicField.pageCount => '${pageCount ?? 1}',
    };
  }

  pw.TextStyle _textStyle(ConversionTextStyle style) {
    final font = fontResolver.resolve(style);
    final decorations = <pw.TextDecoration>[
      if (style.underline) pw.TextDecoration.underline,
      if (style.strike) pw.TextDecoration.lineThrough,
    ];
    final decoration = decorations.isEmpty
        ? pw.TextDecoration.none
        : pw.TextDecoration.combine(decorations);
    return pw.TextStyle(
      font: font,
      fontSize: math.max(6, style.fontSizePoints),
      fontWeight: style.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontStyle: style.italic ? pw.FontStyle.italic : pw.FontStyle.normal,
      decoration: decoration,
      color: _pdfColor(style.colorHex),
      background: style.highlightHex == null
          ? null
          : pw.BoxDecoration(color: _pdfColor(style.highlightHex)),
    );
  }

  static pw.TextAlign _textAlign(ConversionTextAlignment alignment) {
    return switch (alignment) {
      ConversionTextAlignment.center => pw.TextAlign.center,
      ConversionTextAlignment.right => pw.TextAlign.right,
      ConversionTextAlignment.justify => pw.TextAlign.justify,
      ConversionTextAlignment.left => pw.TextAlign.left,
    };
  }

  static pw.CrossAxisAlignment _crossAxis(ConversionTextAlignment alignment) {
    return switch (alignment) {
      ConversionTextAlignment.center => pw.CrossAxisAlignment.center,
      ConversionTextAlignment.right => pw.CrossAxisAlignment.end,
      ConversionTextAlignment.justify || ConversionTextAlignment.left =>
        pw.CrossAxisAlignment.start,
    };
  }

  static PdfColor? _pdfColor(String? hex) {
    if (hex == null || !RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) return null;
    return PdfColor.fromInt(0xFF000000 | int.parse(hex, radix: 16));
  }
}

class _DocxFontResolver {
  final Map<_FontKey, pw.Font?> _fonts = {};

  Future<void> preload(ConversionDocument document) async {
    final keys = <_FontKey>{};
    for (final section in document.sections) {
      _collectFromBlocks(section.blocks, keys);
      _collectFromBlocks(section.headerBlocks, keys);
      _collectFromBlocks(section.footerBlocks, keys);
    }
    for (final key in keys) {
      _fonts[key] = await _load(key);
    }
  }

  pw.Font? resolve(ConversionTextStyle style) {
    final family = _normalizeFamily(style.fontFamily);
    if (family == null) return null;
    return _fonts[_FontKey(family, style.bold, style.italic)];
  }

  void _collectFromBlocks(List<ConversionBlock> blocks, Set<_FontKey> keys) {
    for (final block in blocks) {
      if (block is ConversionParagraph) {
        for (final inline in block.inlines) {
          final style = switch (inline) {
            ConversionTextRun run => run.style,
            ConversionDynamicFieldRun field => field.style,
            ConversionOpaqueOoxmlRun opaque => opaque.style,
            _ => null,
          };
          if (style == null) continue;
          final family = _normalizeFamily(style.fontFamily);
          if (family != null) {
            keys.add(_FontKey(family, style.bold, style.italic));
          }
        }
      } else if (block is ConversionOpaqueOoxmlBlock) {
        _collectFromBlocks(block.fallbackBlocks, keys);
      } else if (block is ConversionTable) {
        for (final row in block.rows) {
          for (final cell in row.cells) {
            _collectFromBlocks(cell.blocks, keys);
          }
        }
      }
    }
  }

  Future<pw.Font?> _load(_FontKey key) async {
    for (final path in _candidatePaths(key)) {
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        final data = await file.readAsBytes();
        return pw.Font.ttf(Uint8List.fromList(data).buffer.asByteData());
      } catch (_) {
        // Exact Word font is optional. The document theme remains the safe
        // Unicode fallback when a host font cannot be loaded.
      }
    }
    return null;
  }

  static Iterable<String> _candidatePaths(_FontKey key) sync* {
    if (!Platform.isWindows) return;
    final windows = Platform.environment['WINDIR'] ?? r'C:\Windows';
    final fonts = '$windows${Platform.pathSeparator}Fonts';

    String fileName;
    switch (key.family) {
      case 'calibri':
        fileName = key.bold && key.italic
            ? 'calibriz.ttf'
            : key.bold
            ? 'calibrib.ttf'
            : key.italic
            ? 'calibrii.ttf'
            : 'calibri.ttf';
        break;
      case 'arial':
        fileName = key.bold && key.italic
            ? 'arialbi.ttf'
            : key.bold
            ? 'arialbd.ttf'
            : key.italic
            ? 'ariali.ttf'
            : 'arial.ttf';
        break;
      case 'times new roman':
        fileName = key.bold && key.italic
            ? 'timesbi.ttf'
            : key.bold
            ? 'timesbd.ttf'
            : key.italic
            ? 'timesi.ttf'
            : 'times.ttf';
        break;
      case 'cambria':
        fileName = key.bold && key.italic
            ? 'cambriaz.ttf'
            : key.bold
            ? 'cambriab.ttf'
            : key.italic
            ? 'cambriai.ttf'
            : 'cambria.ttf';
        break;
      case 'segoe ui':
        fileName = key.bold && key.italic
            ? 'segoeuiz.ttf'
            : key.bold
            ? 'segoeuib.ttf'
            : key.italic
            ? 'segoeuii.ttf'
            : 'segoeui.ttf';
        break;
      case 'verdana':
        fileName = key.bold && key.italic
            ? 'verdanaz.ttf'
            : key.bold
            ? 'verdanab.ttf'
            : key.italic
            ? 'verdanai.ttf'
            : 'verdana.ttf';
        break;
      case 'courier new':
        fileName = key.bold && key.italic
            ? 'courbi.ttf'
            : key.bold
            ? 'courbd.ttf'
            : key.italic
            ? 'couri.ttf'
            : 'cour.ttf';
        break;
      default:
        return;
    }
    yield '$fonts${Platform.pathSeparator}$fileName';
  }

  static String? _normalizeFamily(String? family) {
    final normalized = family?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }
}

class _FontKey {
  const _FontKey(this.family, this.bold, this.italic);

  final String family;
  final bool bold;
  final bool italic;

  @override
  bool operator ==(Object other) {
    return other is _FontKey &&
        other.family == family &&
        other.bold == bold &&
        other.italic == italic;
  }

  @override
  int get hashCode => Object.hash(family, bold, italic);
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}

class _DocxPdfRenderCancelled implements Exception {
  const _DocxPdfRenderCancelled();
}
