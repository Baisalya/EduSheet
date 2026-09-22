import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:edusheet/features/pdf/services/math/word_omml_math_typesetter.dart';
import 'package:edusheet/features/smart_editor/application/smart_editor_export_projection.dart';
import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_break_embed_builder.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_interop_embed_builders.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_geometry_rasterizer.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart' as xml;

class SmartEditorDocxImportResult {
  const SmartEditorDocxImportResult({
    required this.document,
    this.warnings = const <String>[],
    this.nativeRoundTrip = false,
  });

  final SmartDocument document;
  final List<String> warnings;
  final bool nativeRoundTrip;
}

class SmartEditorDocxExportResult {
  const SmartEditorDocxExportResult({
    required this.bytes,
    this.warnings = const <String>[],
  });

  final Uint8List bytes;
  final List<String> warnings;
}

/// DOCX bridge for Smart Editor.
///
/// Standard Word content is always emitted for interoperability. An EduSheet
/// custom XML part is also embedded with SHA-256 change-detection hashes for
/// every Word-owned package part (`word/*`), including body, header/footer,
/// styles, relationships and media. Native math, geometry and Smart Editor
/// metadata are restored only for an exact round trip. Any normal external Word
/// edit invalidates the package fingerprint and import falls back to standard
/// DOCX content. These hashes are integrity/change detection, not authentication.
class SmartEditorDocxService {
  const SmartEditorDocxService({
    this.geometryRasterizer = const SmartEditorGeometryRasterizer(),
  });

  static const String roundTripPartName =
      'customXml/itemEduSheetSmartDocument.xml';
  static const String roundTripNamespace =
      'urn:edusheet:smart-document:v1';
  static const String roundTripRelationshipType =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/customXml';
  static const WordOmmlMathTypesetter _omml = WordOmmlMathTypesetter();

  final SmartEditorGeometryRasterizer geometryRasterizer;

  Future<SmartEditorDocxImportResult> importFile(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final entries = <String, ArchiveFile>{
      for (final entry in archive.files) entry.name: entry,
    };
    final hadNativeMetadata = entries.containsKey(roundTripPartName);
    final native = _restoreNative(entries);
    if (native != null) {
      final now = DateTime.now().toUtc();
      final restored = native.copyWith(
        id: SmartDocument.blank().id,
        createdAt: now,
        updatedAt: now,
      );
      return SmartEditorDocxImportResult(
        document: restored,
        nativeRoundTrip: true,
      );
    }

    final parsed = await DocxConversionParser.parse(file);
    final warnings = <String>[
      if (hadNativeMetadata)
        'This EduSheet Word file has changed outside EduSheet (or its native metadata is no longer exact), so it was opened through standard Word compatibility mode. Native Math/Geometry may return as normal Word math or images instead of editable EduSheet objects.',
      'Imported through standard Word compatibility mode. Complex Word-only features such as SmartArt, tracked changes, floating text boxes and macros may not be editable.',
    ];
    final document = _fromConversionDocument(
      parsed,
      title: p.basenameWithoutExtension(file.path),
      warnings: warnings,
    );
    return SmartEditorDocxImportResult(
      document: document,
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  Future<SmartEditorDocxExportResult> export(SmartDocument document) async {
    final projection = SmartEditorExportProjection.fromDocument(document);
    final warnings = <String>[];
    final media = <int, _MediaPart>{};
    var mediaNumber = 1;

    for (var index = 0; index < projection.blocks.length; index++) {
      final block = projection.blocks[index];
      if (block is SmartEditorExportImage) {
        if (block.payload.bytes.isEmpty) continue;
        final kind = _imageKind(block.payload.bytes);
        if (kind == null) {
          warnings.add(
            'One imported image uses an unsupported format and was replaced by a text placeholder in DOCX.',
          );
          continue;
        }
        media[index] = _MediaPart(
          relationshipId: 'rIdImage$mediaNumber',
          fileName: 'smart_image_$mediaNumber.${kind.extension}',
          contentType: kind.contentType,
          bytes: block.payload.bytes,
          widthPoints: block.payload.widthPoints,
          heightPoints: block.payload.heightPoints,
          altText: block.payload.altText ?? 'Imported Word image',
        );
        mediaNumber++;
      } else if (block is SmartEditorExportGeometry) {
        final diagram = block.layout.diagram;
        if (diagram == null) {
          warnings.add(
            'One geometry object had no embedded diagram payload and was exported as a placeholder.',
          );
          continue;
        }
        try {
          final png = await geometryRasterizer.toPng(diagram);
          final naturalWidth = diagram.canvasSize.width.clamp(120.0, 520.0).toDouble();
          final width = (naturalWidth * block.layout.widthFactor)
              .clamp(120.0, 520.0)
              .toDouble();
          final height = block.layout.height.clamp(90.0, 520.0).toDouble();
          media[index] = _MediaPart(
            relationshipId: 'rIdImage$mediaNumber',
            fileName: 'geometry_$mediaNumber.png',
            contentType: 'image/png',
            bytes: png,
            widthPoints: width,
            heightPoints: height,
            altText: diagram.name,
          );
          mediaNumber++;
        } catch (_) {
          warnings.add(
            'One geometry object could not be rendered for Word and was exported as a text placeholder.',
          );
        }
      }
    }

    final hyperlinks = _hyperlinkRelationships(projection);
    final hasHeader = document.header.enabled && document.header.text.trim().isNotEmpty;
    final hasFooter = document.footer.enabled && document.footer.text.trim().isNotEmpty;
    final documentXml = _documentXml(
      document,
      projection,
      media,
      warnings,
      hyperlinks: hyperlinks,
      hasHeader: hasHeader,
      hasFooter: hasFooter,
    );
    final archive = Archive();

    void addString(String name, String source) {
      archive.addFile(ArchiveFile.string(name, source));
    }

    addString(
      '[Content_Types].xml',
      _contentTypesXml(
        media.values,
        hasHeader: hasHeader,
        hasFooter: hasFooter,
      ),
    );
    addString('_rels/.rels', _rootRelsXml());
    addString('docProps/core.xml', _coreXml(document));
    addString('docProps/app.xml', _appXml());
    addString('word/styles.xml', _stylesXml());
    addString('word/numbering.xml', _numberingXml());
    addString(
      'word/_rels/document.xml.rels',
      _documentRelsXml(
        media.values,
        hyperlinks: hyperlinks,
        hasHeader: hasHeader,
        hasFooter: hasFooter,
      ),
    );
    if (hasHeader) {
      addString('word/header1.xml', _headerFooterXml(document.header, header: true));
    }
    if (hasFooter) {
      addString('word/footer1.xml', _headerFooterXml(document.footer, header: false));
    }
    addString('word/document.xml', documentXml);
    for (final part in media.values) {
      archive.addFile(
        ArchiveFile.bytes('word/media/${part.fileName}', part.bytes),
      );
    }
    addString(
      roundTripPartName,
      _roundTripXml(
        document,
        documentXml,
        _wordContentFingerprint(archive.files),
      ),
    );

    return SmartEditorDocxExportResult(
      bytes: Uint8List.fromList(ZipEncoder().encode(archive)),
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  SmartDocument? _restoreNative(Map<String, ArchiveFile> entries) {
    final metadata = entries[roundTripPartName];
    final documentPart = entries['word/document.xml'];
    if (metadata == null || documentPart == null) return null;
    try {
      final root = xml.XmlDocument.parse(utf8.decode(metadata.content)).rootElement;
      if (root.name.local != 'smartDocument' || root.getAttribute('version') != '1') {
        return null;
      }
      final payloadElement = root.childElements
          .where((element) => element.name.local == 'payload')
          .firstOrNull;
      if (payloadElement == null) return null;
      final encoded = payloadElement.innerText.trim();
      final payloadBytes = base64Decode(encoded);
      final payloadHash = root.getAttribute('payloadSha256');
      final documentHash = root.getAttribute('documentSha256');
      final packageHash = root.getAttribute('wordContentSha256');
      if (payloadHash == null ||
          documentHash == null ||
          packageHash == null ||
          sha256.convert(payloadBytes).toString() != payloadHash ||
          sha256.convert(documentPart.content as List<int>).toString() !=
              documentHash ||
          _wordContentFingerprint(entries.values) != packageHash) {
        return null;
      }
      final decoded = jsonDecode(utf8.decode(payloadBytes));
      if (decoded is! Map) return null;
      return SmartDocument.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  SmartDocument _fromConversionDocument(
    ConversionDocument source, {
    required String title,
    required List<String> warnings,
  }) {
    final operations = <Map<String, dynamic>>[];
    var importedTables = 0;
    var importedImages = 0;

    void insertBreak(String type) {
      operations.add(<String, dynamic>{
        'insert': <String, dynamic>{SmartEditorBreakEmbedBuilder.keyName: type},
      });
      operations.add(const <String, dynamic>{'insert': '\n'});
    }

    for (var sectionIndex = 0; sectionIndex < source.sections.length; sectionIndex++) {
      final section = source.sections[sectionIndex];
      if (sectionIndex > 0) insertBreak('section');
      for (final block in section.blocks) {
        if (block is ConversionParagraph) {
          if (block.pageBreakBefore) insertBreak('page');
          final blockAttributes = _paragraphAttributes(block);
          var hasTextInCurrentParagraph = false;
          final inferredList = _listType(block.listLabel);
          if (block.listLabel != null && inferredList == null) {
            operations.add(<String, dynamic>{'insert': block.listLabel!});
            hasTextInCurrentParagraph = true;
          }
          for (final inline in block.inlines) {
            if (inline is ConversionTextRun) {
              if (inline.text.isEmpty) continue;
              final attributes = _textAttributes(inline);
              operations.add(<String, dynamic>{
                'insert': inline.text,
                if (attributes.isNotEmpty) 'attributes': attributes,
              });
              hasTextInCurrentParagraph = true;
            } else if (inline is ConversionDynamicFieldRun) {
              final value = switch (inline.field) {
                ConversionDynamicField.pageNumber => '{PAGE}',
                ConversionDynamicField.pageCount => '{NUMPAGES}',
              };
              operations.add(<String, dynamic>{'insert': value});
              hasTextInCurrentParagraph = true;
            } else if (inline is ConversionImageRun) {
              if (hasTextInCurrentParagraph) {
                operations.add(<String, dynamic>{
                  'insert': '\n',
                  if (blockAttributes.isNotEmpty) 'attributes': blockAttributes,
                });
                hasTextInCurrentParagraph = false;
              }
              final payload = SmartEditorInteropImagePayload(
                bytes: Uint8List.fromList(inline.bytes),
                widthPoints: inline.widthPoints,
                heightPoints: inline.heightPoints,
                altText: inline.altText,
                hyperlink: inline.hyperlink,
              );
              operations.add(<String, dynamic>{
                'insert': <String, dynamic>{
                  SmartEditorInteropImageEmbedBuilder.keyName: payload.encode(),
                },
              });
              operations.add(const <String, dynamic>{'insert': '\n'});
              importedImages++;
            }
          }
          if (inferredList != null) blockAttributes['list'] = inferredList;
          if (hasTextInCurrentParagraph || block.inlines.isEmpty) {
            operations.add(<String, dynamic>{
              'insert': '\n',
              if (blockAttributes.isNotEmpty) 'attributes': blockAttributes,
            });
          }
        } else if (block is ConversionTable) {
          final payload = _tablePayload(block);
          operations.add(<String, dynamic>{
            'insert': <String, dynamic>{
              SmartEditorInteropTableEmbedBuilder.keyName: payload.encode(),
            },
          });
          operations.add(const <String, dynamic>{'insert': '\n'});
          importedTables++;
        }
      }
    }

    if (operations.isEmpty || operations.last['insert'] != '\n') {
      operations.add(const <String, dynamic>{'insert': '\n'});
    }
    if (importedTables > 0) {
      warnings.add(
        '$importedTables Word table${importedTables == 1 ? '' : 's'} preserved as table blocks. Cell-by-cell editing is limited in this phase.',
      );
    }
    if (importedImages > 0) {
      warnings.add(
        '$importedImages Word image${importedImages == 1 ? '' : 's'} preserved as document image blocks.',
      );
    }
    if (source.sections.length > 1) {
      warnings.add(
        '${source.sections.length} Word sections were imported with semantic section breaks. Smart Editor currently uses one page-layout profile for the editable canvas.',
      );
    }

    final firstSection = source.sections.firstOrNull;
    final layout = firstSection == null
        ? const SmartDocumentPageLayout()
        : _pageLayout(firstSection.page);
    final header = firstSection == null
        ? const SmartDocumentHeaderFooter()
        : _headerFooter(firstSection.headerBlocks);
    final footer = firstSection == null
        ? const SmartDocumentHeaderFooter()
        : _headerFooter(firstSection.footerBlocks);
    final now = DateTime.now().toUtc();
    return SmartDocument(
      id: SmartDocument.blank().id,
      title: title.trim().isEmpty ? 'Imported Word Document' : title.trim(),
      deltaJson: List<dynamic>.from(operations),
      pageLayout: layout,
      header: header,
      footer: footer,
      createdAt: now,
      updatedAt: now,
    );
  }

  static Map<String, dynamic> _textAttributes(ConversionTextRun run) {
    final style = run.style;
    final result = <String, dynamic>{};
    if (style.bold) result['bold'] = true;
    if (style.italic) result['italic'] = true;
    if (style.underline) result['underline'] = true;
    if (style.strike) result['strike'] = true;
    if (style.fontFamily?.trim().isNotEmpty == true) {
      result['font'] = style.fontFamily!.trim();
    }
    if ((style.fontSizePoints - 11).abs() > 0.2) {
      result['size'] = style.fontSizePoints;
    }
    if (style.colorHex != null) result['color'] = '#${style.colorHex}';
    if (style.highlightHex != null) {
      result['background'] = '#${style.highlightHex}';
    }
    if (run.hyperlink?.trim().isNotEmpty == true) {
      result['link'] = run.hyperlink!.trim();
    }
    return result;
  }

  static Map<String, dynamic> _paragraphAttributes(ConversionParagraph paragraph) {
    final result = <String, dynamic>{};
    final align = switch (paragraph.alignment) {
      ConversionTextAlignment.left => null,
      ConversionTextAlignment.center => 'center',
      ConversionTextAlignment.right => 'right',
      ConversionTextAlignment.justify => 'justify',
    };
    if (align != null) result['align'] = align;
    if (paragraph.leftIndentPoints >= 18) {
      result['indent'] = (paragraph.leftIndentPoints / 36).round().clamp(1, 8);
    }
    final maxSize = paragraph.inlines
        .whereType<ConversionTextRun>()
        .map((run) => run.style.fontSizePoints)
        .fold<double>(0, math.max);
    final hasBold = paragraph.inlines
        .whereType<ConversionTextRun>()
        .any((run) => run.style.bold);
    if (paragraph.keepWithNext && hasBold && maxSize >= 15) {
      result['header'] = maxSize >= 18 ? 1 : 2;
    }
    return result;
  }

  static String? _listType(String? label) {
    final value = label?.trim();
    if (value == null || value.isEmpty) return null;
    if (RegExp(r'^\d+[.)]$').hasMatch(value) ||
        RegExp(r'^[A-Za-z][.)]$').hasMatch(value)) {
      return 'ordered';
    }
    if (RegExp(r'^[•●○▪◦\-–—]$').hasMatch(value)) return 'bullet';
    return null;
  }

  static SmartEditorInteropTablePayload _tablePayload(ConversionTable table) {
    return SmartEditorInteropTablePayload(
      showBorders: table.showBorders,
      rows: table.rows
          .map(
            (row) => SmartEditorInteropTableRow(
              header: row.isHeader,
              cells: row.cells
                  .map(
                    (cell) => SmartEditorInteropTableCell(
                      text: _plainText(cell.blocks),
                      shadingHex: cell.shadingHex,
                      widthPoints: cell.widthPoints,
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  static String _plainText(List<ConversionBlock> blocks) {
    final lines = <String>[];
    for (final block in blocks) {
      if (block is ConversionParagraph) {
        final buffer = StringBuffer(block.listLabel ?? '');
        for (final inline in block.inlines) {
          if (inline is ConversionTextRun) {
            buffer.write(inline.text);
          } else if (inline is ConversionDynamicFieldRun) {
            buffer.write(
              inline.field == ConversionDynamicField.pageNumber
                  ? '{PAGE}'
                  : '{NUMPAGES}',
            );
          } else if (inline is ConversionImageRun) {
            buffer.write('[image]');
          }
        }
        lines.add(buffer.toString());
      } else if (block is ConversionTable) {
        for (final row in block.rows) {
          lines.add(row.cells.map((cell) => _plainText(cell.blocks)).join('\t'));
        }
      }
    }
    return lines.join('\n').trimRight();
  }

  static SmartDocumentPageLayout _pageLayout(ConversionPageSettings page) {
    final landscape = page.widthPoints > page.heightPoints;
    final shortSide = math.min(page.widthPoints, page.heightPoints);
    final longSide = math.max(page.widthPoints, page.heightPoints);
    final letterDistance = (shortSide - 612).abs() + (longSide - 792).abs();
    final a4Distance = (shortSide - 595.3).abs() + (longSide - 841.9).abs();
    final margins = <double>[
      page.marginTopPoints,
      page.marginRightPoints,
      page.marginBottomPoints,
      page.marginLeftPoints,
    ];
    SmartDocumentMarginPreset preset;
    if (margins.every((value) => (value - 36).abs() <= 2)) {
      preset = SmartDocumentMarginPreset.narrow;
    } else if (margins.every((value) => (value - 72).abs() <= 2)) {
      preset = SmartDocumentMarginPreset.normal;
    } else if (margins.every((value) => (value - 108).abs() <= 2)) {
      preset = SmartDocumentMarginPreset.wide;
    } else {
      preset = SmartDocumentMarginPreset.custom;
    }
    return SmartDocumentPageLayout(
      pageSize: letterDistance < a4Distance
          ? SmartDocumentPageSize.letter
          : SmartDocumentPageSize.a4,
      orientation: landscape
          ? SmartDocumentOrientation.landscape
          : SmartDocumentOrientation.portrait,
      marginPreset: preset,
      borderStyle: SmartDocumentPageBorderStyle.none,
      customTopMargin: page.marginTopPoints,
      customRightMargin: page.marginRightPoints,
      customBottomMargin: page.marginBottomPoints,
      customLeftMargin: page.marginLeftPoints,
    );
  }

  static SmartDocumentHeaderFooter _headerFooter(List<ConversionBlock> blocks) {
    final text = _plainText(blocks);
    return SmartDocumentHeaderFooter(
      enabled: text.trim().isNotEmpty,
      text: text,
      alignment: SmartDocumentHeaderFooterAlignment.center,
    );
  }

  String _documentXml(
    SmartDocument document,
    SmartEditorExportProjection projection,
    Map<int, _MediaPart> media,
    List<String> warnings, {
    required Map<String, String> hyperlinks,
    required bool hasHeader,
    required bool hasFooter,
  }) {
    final body = StringBuffer();
    var drawingId = 1;
    for (var index = 0; index < projection.blocks.length; index++) {
      final block = projection.blocks[index];
      switch (block) {
        case SmartEditorExportParagraph():
          body.write(_paragraphXml(block, warnings, hyperlinks));
        case SmartEditorExportBreak():
          if (block.type == 'section') {
            body.write('<w:p><w:pPr><w:sectPr><w:type w:val="continuous"/></w:sectPr></w:pPr></w:p>');
          } else {
            body.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
          }
        case SmartEditorExportImage():
          final part = media[index];
          body.write(
            part == null
                ? _plainParagraphXml('[Unsupported image]')
                : _drawingParagraphXml(part, drawingId++),
          );
        case SmartEditorExportGeometry():
          final part = media[index];
          if (part == null) {
            body.write(_plainParagraphXml('[Geometry diagram]'));
          } else {
            final alignment = block.layout.effectiveAlignmentX < -0.35
                ? 'left'
                : block.layout.effectiveAlignmentX > 0.35
                    ? 'right'
                    : 'center';
            body.write(_drawingParagraphXml(part, drawingId++, alignment: alignment));
          }
        case SmartEditorExportTable():
          body.write(_tableXml(block.payload));
      }
    }

    final section = _sectionProperties(
      document,
      hasHeader: hasHeader,
      hasFooter: hasFooter,
    );
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document '
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<w:body>${body.toString()}$section</w:body></w:document>';
  }

  String _paragraphXml(
    SmartEditorExportParagraph paragraph,
    List<String> warnings,
    Map<String, String> hyperlinks,
  ) {
    final pPr = StringBuffer('<w:pPr>');
    final attributes = paragraph.attributes;
    final header = _intValue(attributes['header']);
    if (header != null && header >= 1 && header <= 3) {
      pPr.write('<w:pStyle w:val="Heading$header"/>');
    }
    final align = attributes['align']?.toString();
    if (align != null && align != 'left') {
      pPr.write('<w:jc w:val="${align == 'justify' ? 'both' : _xml(align)}"/>');
    }
    final indent = _intValue(attributes['indent']);
    if (indent != null && indent > 0) {
      pPr.write('<w:ind w:left="${indent * 720}"/>');
    }
    final list = attributes['list']?.toString();
    if (list == 'ordered' || list == 'bullet') {
      pPr.write(
        '<w:numPr><w:ilvl w:val="${math.max(0, (indent ?? 1) - 1)}"/>'
        '<w:numId w:val="${list == 'ordered' ? 1 : 2}"/></w:numPr>',
      );
    }
    final lineHeight = double.tryParse(attributes['line-height']?.toString() ?? '');
    if (lineHeight != null && lineHeight > 0) {
      pPr.write('<w:spacing w:line="${(240 * lineHeight).round()}" w:lineRule="auto"/>');
    }
    pPr.write('</w:pPr>');

    final content = StringBuffer();
    for (final inline in paragraph.inlines) {
      if (inline is SmartEditorExportText) {
        final link = inline.attributes['link']?.toString().trim();
        content.write(
          _runXml(
            inline.text,
            inline.attributes,
            hyperlinkRelationshipId:
                link == null || link.isEmpty ? null : hyperlinks[link],
          ),
        );
      } else if (inline is SmartEditorExportMath) {
        final mathXml = _omml.inlineSource(inline.expression.latex);
        if (mathXml == null) {
          warnings.add(
            'One equation used unsupported Word math syntax and was exported as readable text.',
          );
          content.write(_runXml(inline.plainText, const <String, dynamic>{}));
        } else {
          content.write(mathXml);
        }
      }
    }
    if (content.isEmpty) content.write('<w:r><w:t/></w:r>');
    return '<w:p>${pPr.toString()}${content.toString()}</w:p>';
  }

  static String _runXml(
    String text,
    Map<String, dynamic> attributes, {
    String? hyperlinkRelationshipId,
  }) {
    if (text.isEmpty) return '';
    final rPr = StringBuffer('<w:rPr>');
    if (hyperlinkRelationshipId != null) {
      rPr.write('<w:rStyle w:val="Hyperlink"/>');
    }
    if (attributes['bold'] == true) rPr.write('<w:b/><w:bCs/>');
    if (attributes['italic'] == true) rPr.write('<w:i/><w:iCs/>');
    if (attributes['underline'] == true) rPr.write('<w:u w:val="single"/>');
    if (attributes['strike'] == true) rPr.write('<w:strike/>');
    final font = attributes['font']?.toString().trim();
    if (font != null && font.isNotEmpty) {
      rPr.write('<w:rFonts w:ascii="${_xml(font)}" w:hAnsi="${_xml(font)}" w:cs="${_xml(font)}"/>');
    }
    final size = double.tryParse(attributes['size']?.toString() ?? '');
    if (size != null && size > 0) {
      final halfPoints = (size * 2).round().clamp(2, 400);
      rPr.write('<w:sz w:val="$halfPoints"/><w:szCs w:val="$halfPoints"/>');
    }
    final color = _hex(attributes['color']);
    if (color != null) rPr.write('<w:color w:val="$color"/>');
    final background = _hex(attributes['background']);
    if (background != null) rPr.write('<w:shd w:val="clear" w:fill="$background"/>');
    rPr.write('</w:rPr>');
    final run =
        '<w:r>${rPr.toString()}<w:t xml:space="preserve">${_xml(text)}</w:t></w:r>';
    if (hyperlinkRelationshipId == null) return run;
    return '<w:hyperlink r:id="${_xml(hyperlinkRelationshipId)}" w:history="1">$run</w:hyperlink>';
  }

  static String _tableXml(SmartEditorInteropTablePayload table) {
    if (table.rows.isEmpty) return '';
    final border = table.showBorders
        ? '<w:tblBorders>'
            '<w:top w:val="single" w:sz="4" w:color="B7B7B7"/>'
            '<w:left w:val="single" w:sz="4" w:color="B7B7B7"/>'
            '<w:bottom w:val="single" w:sz="4" w:color="B7B7B7"/>'
            '<w:right w:val="single" w:sz="4" w:color="B7B7B7"/>'
            '<w:insideH w:val="single" w:sz="4" w:color="D0D0D0"/>'
            '<w:insideV w:val="single" w:sz="4" w:color="D0D0D0"/>'
            '</w:tblBorders>'
        : '';
    final rows = table.rows.map((row) {
      final cells = row.cells.map((cell) {
        final width = cell.widthPoints == null
            ? ''
            : '<w:tcW w:w="${(cell.widthPoints! * 20).round()}" w:type="dxa"/>';
        final shading = _hex(cell.shadingHex);
        final shd = shading == null ? '' : '<w:shd w:val="clear" w:fill="$shading"/>';
        final bold = row.header ? const <String, dynamic>{'bold': true} : const <String, dynamic>{};
        return '<w:tc><w:tcPr>$width$shd</w:tcPr>${_plainParagraphXml(cell.text, attributes: bold)}</w:tc>';
      }).join();
      return '<w:tr>$cells</w:tr>';
    }).join();
    return '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>$border</w:tblPr>$rows</w:tbl>';
  }

  static String _drawingParagraphXml(
    _MediaPart part,
    int drawingId, {
    String alignment = 'center',
  }) {
    final cx = (part.widthPoints.clamp(24.0, 540.0) * 12700).round();
    final cy = (part.heightPoints.clamp(24.0, 720.0) * 12700).round();
    final name = _xml(part.altText.isEmpty ? part.fileName : part.altText);
    return '<w:p><w:pPr><w:jc w:val="$alignment"/></w:pPr><w:r><w:drawing>'
        '<wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$cx" cy="$cy"/>'
        '<wp:docPr id="$drawingId" name="$name" descr="$name"/>'
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic><pic:nvPicPr><pic:cNvPr id="0" name="$name"/><pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip r:embed="${part.relationshipId}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic></wp:inline>'
        '</w:drawing></w:r></w:p>';
  }

  static String _plainParagraphXml(
    String text, {
    Map<String, dynamic> attributes = const <String, dynamic>{},
  }) {
    return '<w:p>${_runXml(text, attributes)}</w:p>';
  }

  static String _sectionProperties(
    SmartDocument document, {
    required bool hasHeader,
    required bool hasFooter,
  }) {
    final page = document.pageLayout;
    var width = page.pageSize == SmartDocumentPageSize.a4 ? 595.3 : 612.0;
    var height = page.pageSize == SmartDocumentPageSize.a4 ? 841.9 : 792.0;
    if (page.orientation == SmartDocumentOrientation.landscape) {
      final swap = width;
      width = height;
      height = swap;
    }
    final border = _pageBorderXml(page.borderStyle);
    return '<w:sectPr>'
        '<w:pgSz w:w="${(width * 20).round()}" w:h="${(height * 20).round()}"'
        '${page.orientation == SmartDocumentOrientation.landscape ? ' w:orient="landscape"' : ''}/>'
        '<w:pgMar w:top="${(page.topMarginPoints * 20).round()}" '
        'w:right="${(page.rightMarginPoints * 20).round()}" '
        'w:bottom="${(page.bottomMarginPoints * 20).round()}" '
        'w:left="${(page.leftMarginPoints * 20).round()}" '
        'w:header="360" w:footer="360" w:gutter="0"/>'
        '${hasHeader ? '<w:headerReference w:type="default" r:id="rIdHeader"/>' : ''}'
        '${hasFooter ? '<w:footerReference w:type="default" r:id="rIdFooter"/>' : ''}'
        '$border</w:sectPr>';
  }

  static String _pageBorderXml(SmartDocumentPageBorderStyle style) {
    if (style == SmartDocumentPageBorderStyle.none) return '';
    final val = style == SmartDocumentPageBorderStyle.doubleLine ? 'double' : 'single';
    final size = switch (style) {
      SmartDocumentPageBorderStyle.subtle => 4,
      SmartDocumentPageBorderStyle.solid => 8,
      SmartDocumentPageBorderStyle.doubleLine => 6,
      SmartDocumentPageBorderStyle.none => 0,
    };
    final color = style == SmartDocumentPageBorderStyle.subtle
        ? 'A8A8A8'
        : '666666';
    String edge(String name) => '<w:$name w:val="$val" w:sz="$size" w:space="18" w:color="$color"/>';
    return '<w:pgBorders w:offsetFrom="page">${edge('top')}${edge('left')}${edge('bottom')}${edge('right')}</w:pgBorders>';
  }

  static String _headerFooterXml(
    SmartDocumentHeaderFooter config, {
    required bool header,
  }) {
    final root = header ? 'hdr' : 'ftr';
    final align = switch (config.alignment) {
      SmartDocumentHeaderFooterAlignment.left => 'left',
      SmartDocumentHeaderFooterAlignment.center => 'center',
      SmartDocumentHeaderFooterAlignment.right => 'right',
    };
    final border = config.showDivider
        ? '<w:pBdr><w:${header ? 'bottom' : 'top'} w:val="single" w:sz="6" w:space="4" w:color="808080"/></w:pBdr>'
        : '';
    final paragraphs = config.text.split('\n').map((line) {
      return '<w:p><w:pPr><w:jc w:val="$align"/>$border</w:pPr>${_runXml(line, const <String, dynamic>{})}</w:p>';
    }).join();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:$root xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$paragraphs</w:$root>';
  }

  static String _roundTripXml(
    SmartDocument document,
    String documentXml,
    String wordContentFingerprint,
  ) {
    final payload = Uint8List.fromList(utf8.encode(jsonEncode(document.toJson())));
    return '<?xml version="1.0" encoding="UTF-8"?>'
        '<smartDocument xmlns="$roundTripNamespace" version="1" '
        'payloadSha256="${sha256.convert(payload)}" '
        'documentSha256="${sha256.convert(utf8.encode(documentXml))}" '
        'wordContentSha256="$wordContentFingerprint">'
        '<payload>${base64Encode(payload)}</payload></smartDocument>';
  }

  static String _wordContentFingerprint(Iterable<ArchiveFile> files) {
    final parts = files
        .where((file) => file.name.startsWith('word/'))
        .toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
    final canonical = BytesBuilder(copy: false);
    for (final part in parts) {
      final bytes = List<int>.from(part.content as List<int>);
      canonical
        ..add(utf8.encode(part.name))
        ..addByte(0)
        ..add(utf8.encode(sha256.convert(bytes).toString()))
        ..addByte(0);
    }
    return sha256.convert(canonical.takeBytes()).toString();
  }

  static Map<String, String> _hyperlinkRelationships(
    SmartEditorExportProjection projection,
  ) {
    final result = <String, String>{};
    var next = 1;
    for (final block in projection.blocks) {
      if (block is! SmartEditorExportParagraph) continue;
      for (final inline in block.inlines) {
        if (inline is! SmartEditorExportText) continue;
        final target = inline.attributes['link']?.toString().trim();
        if (target == null || target.isEmpty || result.containsKey(target)) {
          continue;
        }
        result[target] = 'rIdHyperlink${next++}';
      }
    }
    return Map<String, String>.unmodifiable(result);
  }

  static String _contentTypesXml(
    Iterable<_MediaPart> media, {
    required bool hasHeader,
    required bool hasFooter,
  }) {
    final imageTypes = <String, String>{};
    for (final part in media) {
      imageTypes[p.extension(part.fileName).replaceFirst('.', '').toLowerCase()] =
          part.contentType;
    }
    final defaults = imageTypes.entries
        .map((entry) => '<Default Extension="${_xml(entry.key)}" ContentType="${_xml(entry.value)}"/>')
        .join();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>$defaults'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
        '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>'
        '<Override PartName="/$roundTripPartName" ContentType="application/xml"/>'
        '${hasHeader ? '<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>' : ''}'
        '${hasFooter ? '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>' : ''}'
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
        '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
        '</Types>';
  }

  static String _rootRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
        '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
        '</Relationships>';
  }

  static String _documentRelsXml(
    Iterable<_MediaPart> media, {
    required Map<String, String> hyperlinks,
    required bool hasHeader,
    required bool hasFooter,
  }) {
    final relationships = StringBuffer()
      ..write('<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>')
      ..write('<Relationship Id="rIdNumbering" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>')
      ..write('<Relationship Id="rIdSmartDocument" Type="$roundTripRelationshipType" Target="../$roundTripPartName"/>');
    if (hasHeader) {
      relationships.write('<Relationship Id="rIdHeader" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>');
    }
    if (hasFooter) {
      relationships.write('<Relationship Id="rIdFooter" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>');
    }
    for (final part in media) {
      relationships.write(
        '<Relationship Id="${part.relationshipId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/${_xml(part.fileName)}"/>',
      );
    }
    for (final entry in hyperlinks.entries) {
      relationships.write(
        '<Relationship Id="${_xml(entry.value)}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="${_xml(entry.key)}" TargetMode="External"/>',
      );
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${relationships.toString()}</Relationships>';
  }

  static String _stylesXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr></w:rPrDefault></w:docDefaults>'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>'
        '<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:sz w:val="32"/></w:rPr></w:style>'
        '<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style>'
        '<w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/><w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:outlineLvl w:val="2"/></w:pPr><w:rPr><w:b/><w:sz w:val="24"/></w:rPr></w:style>'
        '<w:style w:type="character" w:styleId="Hyperlink"><w:name w:val="Hyperlink"/><w:unhideWhenUsed/><w:rPr><w:color w:val="0563C1"/><w:u w:val="single"/></w:rPr></w:style>'
        '</w:styles>';
  }

  static String _numberingXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:abstractNum w:abstractNumId="1"><w:multiLevelType w:val="hybridMultilevel"/>'
        '${_numberingLevels(ordered: true)}</w:abstractNum>'
        '<w:abstractNum w:abstractNumId="2"><w:multiLevelType w:val="hybridMultilevel"/>'
        '${_numberingLevels(ordered: false)}</w:abstractNum>'
        '<w:num w:numId="1"><w:abstractNumId w:val="1"/></w:num>'
        '<w:num w:numId="2"><w:abstractNumId w:val="2"/></w:num>'
        '</w:numbering>';
  }

  static String _numberingLevels({required bool ordered}) {
    final buffer = StringBuffer();
    for (var level = 0; level < 9; level++) {
      final left = 720 * (level + 1);
      if (ordered) {
        buffer.write('<w:lvl w:ilvl="$level"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%${level + 1}."/><w:pPr><w:ind w:left="$left" w:hanging="360"/></w:pPr></w:lvl>');
      } else {
        buffer.write('<w:lvl w:ilvl="$level"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:pPr><w:ind w:left="$left" w:hanging="360"/></w:pPr></w:lvl>');
      }
    }
    return buffer.toString();
  }

  static String _coreXml(SmartDocument document) {
    final created = document.createdAt.toUtc().toIso8601String();
    final modified = document.updatedAt.toUtc().toIso8601String();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>${_xml(document.title)}</dc:title><dc:creator>EduSheet</dc:creator>'
        '<cp:lastModifiedBy>EduSheet</cp:lastModifiedBy>'
        '<dcterms:created xsi:type="dcterms:W3CDTF">$created</dcterms:created>'
        '<dcterms:modified xsi:type="dcterms:W3CDTF">$modified</dcterms:modified>'
        '</cp:coreProperties>';
  }

  static String _appXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
        'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
        '<Application>EduSheet Smart Editor</Application></Properties>';
  }

  static _ImageKind? _imageKind(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return const _ImageKind('png', 'image/png');
    }
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return const _ImageKind('jpg', 'image/jpeg');
    }
    if (bytes.length >= 6 && ascii.decode(bytes.take(6).toList(), allowInvalid: true).startsWith('GIF8')) {
      return const _ImageKind('gif', 'image/gif');
    }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return const _ImageKind('bmp', 'image/bmp');
    }
    return null;
  }

  static String? _hex(Object? value) {
    final raw = value?.toString().replaceAll('#', '').trim();
    if (raw == null || !RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(raw)) return null;
    return raw.toUpperCase();
  }

  static int? _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _xml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

class _MediaPart {
  const _MediaPart({
    required this.relationshipId,
    required this.fileName,
    required this.contentType,
    required this.bytes,
    required this.widthPoints,
    required this.heightPoints,
    required this.altText,
  });

  final String relationshipId;
  final String fileName;
  final String contentType;
  final Uint8List bytes;
  final double widthPoints;
  final double heightPoints;
  final String altText;
}

class _ImageKind {
  const _ImageKind(this.extension, this.contentType);
  final String extension;
  final String contentType;
}
