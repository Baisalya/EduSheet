import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:edusheet/core/services/ocr_service.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_job.dart';
import 'package:edusheet/features/word_converter/domain/models/editable_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:edusheet/features/word_converter/services/docx_pdf_renderer.dart';
import 'package:edusheet/features/word_converter/services/editable_docx_writer.dart';
import 'package:edusheet/features/word_converter/services/pdf_editable_reconstructor.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class WordConverterService {
  static const _wordNamespace =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  static const _relationsNamespace =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _pdfRendererChannel = MethodChannel('edusheet/pdf_renderer');

  static const int maxSourceBytes = 300 * 1024 * 1024;
  static const int maxRenderedPageBytes = 350 * 1024 * 1024;

  static bool get supportsPdfAppearancePreservation =>
      Platform.isAndroid || Platform.isWindows;
  static bool get supportsRevealInFolder => Platform.isWindows;

  static Future<ConversionSourceInfo> inspectSource(String sourcePath) async {
    final file = File(sourcePath);
    await _validateSourceFile(file);
    final extension = p.extension(sourcePath).toLowerCase();
    if (extension != '.pdf') {
      return ConversionSourceInfo.fromFile(file);
    }

    final document = sf.PdfDocument(inputBytes: await file.readAsBytes());
    try {
      return await ConversionSourceInfo.fromFile(
        file,
        pageCount: document.pages.count,
      );
    } finally {
      document.dispose();
    }
  }

  static String suggestedOutputName(String sourcePath, String extension) {
    final normalizedExtension = extension.startsWith('.')
        ? extension
        : '.$extension';
    final baseName = _safeFileName(p.basenameWithoutExtension(sourcePath));
    return '$baseName$normalizedExtension';
  }

  static Future<File> convertDocxToPdf(
    String docxPath, {
    String? outputPath,
    ConversionCancellationToken? cancellationToken,
    ConversionProgressCallback? onProgress,
  }) async {
    final token = cancellationToken ?? ConversionCancellationToken();
    final input = File(docxPath);
    _progress(onProgress, ConversionStage.preparing, 'Checking source file…');
    await _validateSourceFile(input);
    token.throwIfCancelled();

    _progress(onProgress, ConversionStage.parsing, 'Parsing Word document…');
    final document = await DocxConversionParser.parse(input);
    token.throwIfCancelled();
    if (!document.hasContent) {
      throw const FormatException(
        'No supported document content found in this Word file.',
      );
    }

    final output = await _outputFile(docxPath, '.pdf', outputPath: outputPath);
    try {
      _progress(onProgress, ConversionStage.rendering, 'Building PDF pages…');
      final bytes = await DocxPdfRenderer.render(
        document,
        shouldCancel: () {
          token.throwIfCancelled();
          return false;
        },
        onSection: (current, total) => _progress(
          onProgress,
          ConversionStage.rendering,
          'Building document section $current of $total…',
          current: current,
          total: total,
        ),
      );
      token.throwIfCancelled();
      _progress(onProgress, ConversionStage.writingOutput, 'Writing PDF…');
      await _writeBytesAtomically(
        output,
        bytes,
        cancellationToken: token,
      );
      _progress(onProgress, ConversionStage.completed, 'Conversion complete.');
      return output;
    } on ConversionCancelledException {
      _progress(onProgress, ConversionStage.cancelled, 'Conversion cancelled.');
      rethrow;
    }
  }

  static Future<File> convertTextToDocx(
    String textPath, {
    String? outputPath,
    ConversionCancellationToken? cancellationToken,
    ConversionProgressCallback? onProgress,
  }) async {
    final token = cancellationToken ?? ConversionCancellationToken();
    final input = File(textPath);
    _progress(onProgress, ConversionStage.preparing, 'Checking source file…');
    await _validateSourceFile(input);
    token.throwIfCancelled();

    _progress(onProgress, ConversionStage.readingSource, 'Reading text…');
    final text = await input.readAsString();
    token.throwIfCancelled();
    final paragraphs = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trimRight())
        .map((line) => _DocxParagraph(line))
        .toList();

    final output = await _outputFile(textPath, '.docx', outputPath: outputPath);
    try {
      _progress(onProgress, ConversionStage.writingOutput, 'Writing Word document…');
      await _writeBytesAtomically(
        output,
        _buildDocx(paragraphs),
        cancellationToken: token,
      );
      _progress(onProgress, ConversionStage.completed, 'Conversion complete.');
      return output;
    } on ConversionCancelledException {
      _progress(onProgress, ConversionStage.cancelled, 'Conversion cancelled.');
      rethrow;
    }
  }

  static Future<File> convertPdfToDocx(
    String pdfPath, {
    String? outputPath,
    ConversionCancellationToken? cancellationToken,
    ConversionProgressCallback? onProgress,
  }) async {
    final token = cancellationToken ?? ConversionCancellationToken();
    final input = File(pdfPath);
    _progress(onProgress, ConversionStage.preparing, 'Checking source PDF…');
    await _validateSourceFile(input);
    token.throwIfCancelled();

    final document = await _reconstructEditablePdf(
      input,
      cancellationToken: token,
      onProgress: onProgress,
    );
    token.throwIfCancelled();
    if (!document.hasContent) {
      throw const FormatException(
        'No readable text found in this PDF. For scanned PDFs, use a clearer scan and try again.',
      );
    }

    final output = await _outputFile(pdfPath, '.docx', outputPath: outputPath);
    try {
      _progress(onProgress, ConversionStage.writingOutput, 'Writing editable Word document…');
      await _writeBytesAtomically(
        output,
        EditableDocxWriter.build(document),
        cancellationToken: token,
      );
      _progress(onProgress, ConversionStage.completed, 'Conversion complete.');
      return output;
    } on ConversionCancelledException {
      _progress(onProgress, ConversionStage.cancelled, 'Conversion cancelled.');
      rethrow;
    }
  }

  static Future<File> convertPdfToDocxExact(
    String pdfPath, {
    String? outputPath,
    ConversionCancellationToken? cancellationToken,
    ConversionProgressCallback? onProgress,
  }) async {
    final token = cancellationToken ?? ConversionCancellationToken();
    final input = File(pdfPath);
    _progress(onProgress, ConversionStage.preparing, 'Checking source PDF…');
    await _validateSourceFile(input);
    token.throwIfCancelled();

    _progress(onProgress, ConversionStage.rendering, 'Rendering PDF pages…');
    final pageImages = await _buildPdfPageImages(
      input,
      cancellationToken: token,
      onProgress: onProgress,
    );
    token.throwIfCancelled();
    if (pageImages.isEmpty) {
      throw const FormatException(
        'Preserve Appearance is unavailable on this device. Please use Editable Document mode instead.',
      );
    }

    final output = await _outputFile(pdfPath, '.docx', outputPath: outputPath);
    try {
      _progress(onProgress, ConversionStage.writingOutput, 'Writing appearance-preserved Word document…');
      await _writeBytesAtomically(
        output,
        _buildImageDocx(pageImages),
        cancellationToken: token,
      );
      _progress(onProgress, ConversionStage.completed, 'Conversion complete.');
      return output;
    } on ConversionCancelledException {
      _progress(onProgress, ConversionStage.cancelled, 'Conversion cancelled.');
      rethrow;
    }
  }

  static Future<void> open(File file) async {
    await OpenFilex.open(file.path);
  }

  static Future<bool> revealInFolder(File file) async {
    if (!Platform.isWindows) return false;
    if (!await file.exists()) return false;
    await Process.start('explorer.exe', <String>['/select,${file.path}']);
    return true;
  }

  static Future<File> saveCopy(File source, String destinationPath) async {
    final destination = File(destinationPath);
    if (p.normalize(p.absolute(source.path)) ==
        p.normalize(p.absolute(destination.path))) {
      return source;
    }
    await _copyFileAtomically(source, destination);
    return destination;
  }

  static Future<File> _outputFile(
    String sourcePath,
    String extension, {
    String? outputPath,
  }) async {
    if (outputPath != null && outputPath.trim().isNotEmpty) {
      final normalizedExtension = extension.startsWith('.')
          ? extension
          : '.$extension';
      final candidate = outputPath.toLowerCase().endsWith(normalizedExtension)
          ? outputPath
          : '$outputPath$normalizedExtension';
      final file = File(candidate);
      await file.parent.create(recursive: true);
      return file;
    }

    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(directory.path, 'EduSheet Conversions'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final baseName = p.basenameWithoutExtension(sourcePath);
    final fileName =
        '${_safeFileName(baseName)}_${DateTime.now().millisecondsSinceEpoch}$extension';
    return File(p.join(exportDir.path, fileName));
  }

  static Future<EditableDocument> _reconstructEditablePdf(
    File file, {
    required ConversionCancellationToken cancellationToken,
    ConversionProgressCallback? onProgress,
  }) async {
    _progress(onProgress, ConversionStage.readingSource, 'Reading PDF structure…');
    final pdf = sf.PdfDocument(inputBytes: await file.readAsBytes());
    try {
      final extractor = sf.PdfTextExtractor(pdf);
      final pageInputs = <PdfLayoutPageInput>[];
      final pagesNeedingOcr = <int>[];
      final totalPages = pdf.pages.count;

      for (var pageIndex = 0; pageIndex < totalPages; pageIndex++) {
        await Future<void>.delayed(Duration.zero);
        cancellationToken.throwIfCancelled();
        _progress(
          onProgress,
          ConversionStage.processingPages,
          'Reading page ${pageIndex + 1} of $totalPages…',
          current: pageIndex + 1,
          total: totalPages,
        );
        final page = pdf.pages[pageIndex];
        final extractedLines = extractor.extractTextLines(
          startPageIndex: pageIndex,
          endPageIndex: pageIndex,
        );
        final lines = extractedLines
            .where((line) => line.text.trim().isNotEmpty)
            .map(_layoutLineFromPdf)
            .toList(growable: false);

        if (lines.isEmpty) {
          pagesNeedingOcr.add(pageIndex);
        }
        pageInputs.add(
          PdfLayoutPageInput(
            pageIndex: pageIndex,
            size: page.size,
            lines: lines,
          ),
        );
      }

      if (pagesNeedingOcr.isNotEmpty) {
        final ocrPages = await _extractPdfLayoutWithOcr(
          file,
          pdf,
          pagesNeedingOcr,
          cancellationToken: cancellationToken,
          onProgress: onProgress,
        );
        for (final entry in ocrPages.entries) {
          pageInputs[entry.key] = entry.value;
        }
      }

      cancellationToken.throwIfCancelled();
      _progress(onProgress, ConversionStage.processingPages, 'Reconstructing editable layout…');
      return const PdfEditableDocumentReconstructor().reconstruct(pageInputs);
    } finally {
      pdf.dispose();
    }
  }

  static PdfLayoutLineInput _layoutLineFromPdf(sf.TextLine line) {
    final lineStyle = _editableTextStyle(
      fontFamily: line.fontName,
      fontSizePoints: line.fontSize,
      styles: line.fontStyle,
    );
    final words = line.wordCollection
        .where((word) => word.text.trim().isNotEmpty)
        .map(
          (word) => PdfLayoutWordInput(
            text: word.text,
            bounds: word.bounds,
            style: _editableTextStyle(
              fontFamily: word.fontName,
              fontSizePoints: word.fontSize,
              styles: word.fontStyle,
            ),
          ),
        )
        .toList(growable: false);

    return PdfLayoutLineInput(
      text: line.text,
      bounds: line.bounds,
      fontSizePoints: line.fontSize,
      fontFamily: line.fontName,
      words: words,
      bold: lineStyle.bold,
      italic: lineStyle.italic,
      underline: lineStyle.underline,
      strike: lineStyle.strike,
    );
  }

  static EditableTextStyle _editableTextStyle({
    required String? fontFamily,
    required double fontSizePoints,
    required List<sf.PdfFontStyle> styles,
  }) {
    return EditableTextStyle(
      fontFamily: fontFamily,
      fontSizePoints: fontSizePoints <= 0 ? 11 : fontSizePoints,
      bold: styles.contains(sf.PdfFontStyle.bold),
      italic: styles.contains(sf.PdfFontStyle.italic),
      underline: styles.contains(sf.PdfFontStyle.underline),
      strike: styles.contains(sf.PdfFontStyle.strikethrough),
    );
  }

  static Future<Map<int, PdfLayoutPageInput>> _extractPdfLayoutWithOcr(
    File file,
    sf.PdfDocument pdf,
    List<int> pageIndices, {
    required ConversionCancellationToken cancellationToken,
    ConversionProgressCallback? onProgress,
  }) async {
    const renderScale = 2.0;
    _progress(onProgress, ConversionStage.rendering, 'Rendering scanned PDF pages for OCR…');
    final imagePaths = await _renderPdfPages(file);
    if (imagePaths.isEmpty) return const {};

    final ocrService = OCRService();
    try {
      final pages = <int, PdfLayoutPageInput>{};
      for (var ocrIndex = 0; ocrIndex < pageIndices.length; ocrIndex++) {
        cancellationToken.throwIfCancelled();
        final pageIndex = pageIndices[ocrIndex];
        _progress(
          onProgress,
          ConversionStage.processingPages,
          'Reading scanned page ${ocrIndex + 1} of ${pageIndices.length}…',
          current: ocrIndex + 1,
          total: pageIndices.length,
        );
        if (pageIndex >= imagePaths.length || pageIndex >= pdf.pages.count) {
          continue;
        }
        final imagePath = imagePaths[pageIndex];
        final recognized = await ocrService.recognizeStructuredTextAuto(imagePath);
        cancellationToken.throwIfCancelled();
        final pageSize = pdf.pages[pageIndex].size;
        final lines = <PdfLayoutLineInput>[];

        for (final block in recognized.blocks) {
          for (final line in block.lines) {
            if (line.text.trim().isEmpty) continue;
            final lineBounds = _scaleOcrBounds(line.boundingBox, renderScale);
            final estimatedFontSize = math
                .max(8.0, math.min(72.0, lineBounds.height * 0.82))
                .toDouble();
            final style = EditableTextStyle(fontSizePoints: estimatedFontSize);
            final words = line.elements
                .where((element) => element.text.trim().isNotEmpty)
                .map(
                  (element) => PdfLayoutWordInput(
                    text: element.text,
                    bounds: _scaleOcrBounds(
                      element.boundingBox,
                      renderScale,
                    ),
                    style: style,
                  ),
                )
                .toList(growable: false);

            lines.add(
              PdfLayoutLineInput(
                text: line.text,
                bounds: lineBounds,
                fontSizePoints: estimatedFontSize,
                fontFamily: null,
                words: words,
              ),
            );
          }
        }

        pages[pageIndex] = PdfLayoutPageInput(
          pageIndex: pageIndex,
          size: pageSize,
          lines: lines,
        );
      }
      return pages;
    } finally {
      ocrService.dispose();
      await _cleanupRenderedPages(imagePaths);
    }
  }

  static Rect _scaleOcrBounds(Rect bounds, double scale) {
    if (scale <= 0) return bounds;
    return Rect.fromLTWH(
      bounds.left / scale,
      bounds.top / scale,
      bounds.width / scale,
      bounds.height / scale,
    );
  }

  static Future<List<_DocxImagePage>> _buildPdfPageImages(
    File file, {
    required ConversionCancellationToken cancellationToken,
    ConversionProgressCallback? onProgress,
  }) async {
    final imagePaths = await _renderPdfPages(file, throwOnFailure: true);
    if (imagePaths.isEmpty) return const [];

    final document = sf.PdfDocument(inputBytes: await file.readAsBytes());
    try {
      var renderedBytes = 0;
      for (final path in imagePaths) {
        final renderedFile = File(path);
        if (await renderedFile.exists()) {
          renderedBytes += await renderedFile.length();
          if (renderedBytes > maxRenderedPageBytes) {
            throw const FormatException(
              'This PDF is too large for Preserve Appearance mode on this device. Use Editable Document mode or split the PDF into smaller files.',
            );
          }
        }
      }

      final pageImages = <_DocxImagePage>[];
      for (var index = 0; index < imagePaths.length; index++) {
        cancellationToken.throwIfCancelled();
        _progress(
          onProgress,
          ConversionStage.processingPages,
          'Packing page ${index + 1} of ${imagePaths.length}…',
          current: index + 1,
          total: imagePaths.length,
        );
        final imageFile = File(imagePaths[index]);
        if (!await imageFile.exists()) continue;

        final pageSize = index < document.pages.count
            ? document.pages[index].size
            : null;
        pageImages.add(
          _DocxImagePage(
            relationshipId: 'rId${index + 1}',
            fileName: 'pdf_page_${index + 1}.png',
            contentType: 'image/png',
            bytes: await imageFile.readAsBytes(),
            widthPoints: pageSize?.width ?? 595,
            heightPoints: pageSize?.height ?? 842,
          ),
        );
      }
      return pageImages;
    } finally {
      document.dispose();
      await _cleanupRenderedPages(imagePaths);
    }
  }

  static Future<List<String>> _renderPdfPages(
    File file, {
    bool throwOnFailure = false,
  }) async {
    try {
      final result = await _pdfRendererChannel.invokeListMethod<String>(
        'renderPagesToImages',
        {'pdfPath': file.path, 'scale': throwOnFailure ? 3 : 2},
      );
      return result ?? const [];
    } on MissingPluginException catch (error) {
      if (throwOnFailure) {
        throw FormatException(
          'Preserve Appearance is unavailable on this platform: ${error.message ?? error.toString()}',
        );
      }
      return const [];
    } on PlatformException catch (error) {
      if (throwOnFailure) {
        throw FormatException(
          'Could not render PDF pages for Preserve Appearance conversion: ${error.message ?? error.code}',
        );
      }
      return const [];
    }
  }

  static List<int> _buildDocx(List<_DocxParagraph> paragraphs) {
    final archive = Archive();

    void addString(String name, String content) {
      archive.addFile(ArchiveFile.string(name, content));
    }

    addString('[Content_Types].xml', _contentTypesXml());
    addString('_rels/.rels', _rootRelsXml());
    addString('docProps/core.xml', _coreXml());
    addString('docProps/app.xml', _appXml());
    addString('word/_rels/document.xml.rels', _documentRelsXml());
    addString('word/document.xml', _documentXml(paragraphs));

    return ZipEncoder().encode(archive);
  }

  static List<int> _buildImageDocx(List<_DocxImagePage> pages) {
    final archive = Archive();

    void addString(String name, String content) {
      archive.addFile(ArchiveFile.string(name, content));
    }

    addString('[Content_Types].xml', _contentTypesXml(imagePages: pages));
    addString('_rels/.rels', _rootRelsXml());
    addString('docProps/core.xml', _coreXml());
    addString('docProps/app.xml', _appXml());
    addString('word/_rels/document.xml.rels', _documentRelsXml(pages));
    addString('word/document.xml', _imageDocumentXml(pages));

    for (final page in pages) {
      archive.addFile(
        ArchiveFile.bytes('word/media/${page.fileName}', page.bytes),
      );
    }

    return ZipEncoder().encode(archive);
  }

  static String _documentXml(List<_DocxParagraph> paragraphs) {
    final content = paragraphs.isEmpty
        ? _paragraph(_DocxParagraph(''))
        : paragraphs.map(_paragraph).join();

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="$_wordNamespace">'
        '<w:body>$content'
        '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720" '
        'w:header="360" w:footer="360" w:gutter="0"/>'
        '</w:sectPr></w:body></w:document>';
  }

  static String _imageDocumentXml(List<_DocxImagePage> pages) {
    final content = <String>[];
    for (var index = 0; index < pages.length; index++) {
      content.add(
        _imagePageParagraph(
          pages[index],
          isLast: index == pages.length - 1,
        ),
      );
    }
    final section = pages.isEmpty
        ? _sectionProperties(595, 842)
        : _sectionProperties(pages.last.widthPoints, pages.last.heightPoints);

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="$_wordNamespace" xmlns:r="$_relationsNamespace" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<w:body>${content.join()}$section</w:body></w:document>';
  }

  static String _imagePageParagraph(
    _DocxImagePage page, {
    required bool isLast,
  }) {
    final sectionBreak = isLast
        ? ''
        : _sectionProperties(
            page.widthPoints,
            page.heightPoints,
            nextPage: true,
          );
    final widthEmu = _pointsToEmu(page.widthPoints);
    final heightEmu = _pointsToEmu(page.heightPoints);
    final id = page.relationshipId.replaceAll(RegExp(r'\D'), '');

    return '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/>'
        '$sectionBreak</w:pPr><w:r><w:drawing>'
        '<wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$widthEmu" cy="$heightEmu"/>'
        '<wp:docPr id="$id" name="PDF Page $id"/>'
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic><pic:nvPicPr><pic:cNvPr id="$id" name="${_xml(page.fileName)}"/>'
        '<pic:cNvPicPr/></pic:nvPicPr><pic:blipFill>'
        '<a:blip r:embed="${page.relationshipId}"/>'
        '<a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/>'
        '<a:ext cx="$widthEmu" cy="$heightEmu"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic></wp:inline>'
        '</w:drawing></w:r></w:p>';
  }

  static String _paragraph(_DocxParagraph paragraph) {
    return '<w:p><w:pPr><w:spacing w:after="120"/></w:pPr>'
        '<w:r><w:rPr><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>'
        '<w:t xml:space="preserve">${_xml(paragraph.text)}</w:t></w:r></w:p>';
  }

  static String _contentTypesXml({List<_DocxImagePage> imagePages = const []}) {
    final imageDefaults = imagePages
        .map(
          (page) =>
              '<Default Extension="${p.extension(page.fileName).substring(1)}" '
              'ContentType="${page.contentType}"/>',
        )
        .toSet()
        .join();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '$imageDefaults'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
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

  static String _documentRelsXml([List<_DocxImagePage> imagePages = const []]) {
    final imageRels = imagePages.map((page) {
      return '<Relationship Id="${page.relationshipId}" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
          'Target="media/${page.fileName}"/>';
    }).join();

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '$imageRels</Relationships>';
  }

  static String _sectionProperties(
    double widthPoints,
    double heightPoints, {
    bool nextPage = false,
  }) {
    final widthTwips = _pointsToTwips(widthPoints);
    final heightTwips = _pointsToTwips(heightPoints);
    final orientation = widthTwips > heightTwips ? ' w:orient="landscape"' : '';
    final sectionType = nextPage ? '<w:type w:val="nextPage"/>' : '';
    return '<w:sectPr>$sectionType'
        '<w:pgSz w:w="$widthTwips" w:h="$heightTwips"$orientation/>'
        '<w:pgMar w:top="0" w:right="0" w:bottom="0" w:left="0" '
        'w:header="0" w:footer="0" w:gutter="0"/></w:sectPr>';
  }

  static String _coreXml() {
    final now = DateTime.now().toUtc().toIso8601String();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>Converted Document</dc:title>'
        '<dc:creator>EduSheet</dc:creator>'
        '<cp:lastModifiedBy>EduSheet</cp:lastModifiedBy>'
        '<dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created>'
        '<dcterms:modified xsi:type="dcterms:W3CDTF">$now</dcterms:modified>'
        '</cp:coreProperties>';
  }

  static String _appXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
        'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
        '<Application>EduSheet</Application></Properties>';
  }

  static Future<void> _validateSourceFile(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('Source file does not exist.', file.path);
    }
    final length = await file.length();
    if (length <= 0) {
      throw const FormatException('The selected file is empty.');
    }
    if (length > maxSourceBytes) {
      throw const FormatException(
        'This document is too large to convert safely in one pass. Split it into smaller files and try again.',
      );
    }
  }

  static Future<void> _writeBytesAtomically(
    File output,
    List<int> bytes, {
    ConversionCancellationToken? cancellationToken,
  }) async {
    await output.parent.create(recursive: true);
    final temporary = _stagingFile(output, 'part');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      cancellationToken?.throwIfCancelled();
      await _commitStagedFile(temporary, output);
    } catch (_) {
      await _deleteBestEffort(temporary);
      rethrow;
    }
  }

  static Future<void> _copyFileAtomically(File source, File output) async {
    await output.parent.create(recursive: true);
    final temporary = _stagingFile(output, 'part');
    try {
      await source.copy(temporary.path);
      await _commitStagedFile(temporary, output);
    } catch (_) {
      await _deleteBestEffort(temporary);
      rethrow;
    }
  }

  static Future<void> _commitStagedFile(File temporary, File output) async {
    final backup = _stagingFile(output, 'bak');
    var movedExisting = false;
    try {
      if (await output.exists()) {
        await output.rename(backup.path);
        movedExisting = true;
      }

      try {
        await temporary.rename(output.path);
      } on FileSystemException {
        await temporary.copy(output.path);
        await temporary.delete();
      }

      if (movedExisting) {
        await _deleteBestEffort(backup);
      }
    } catch (_) {
      await _deleteBestEffort(temporary);
      if (movedExisting && await backup.exists()) {
        try {
          if (await output.exists()) await output.delete();
          await backup.rename(output.path);
        } catch (_) {
          // Preserve the primary error; the backup remains recoverable.
        }
      }
      rethrow;
    }
  }

  static File _stagingFile(File output, String suffix) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return File(
      p.join(output.parent.path, '.${p.basename(output.path)}.$stamp.$suffix'),
    );
  }

  static Future<void> _deleteBestEffort(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Cleanup must not replace the primary conversion result/error.
    }
  }

  static Future<void> _cleanupRenderedPages(List<String> imagePaths) async {
    final parentDirectories = <String>{};
    for (final imagePath in imagePaths) {
      try {
        final file = File(imagePath);
        parentDirectories.add(file.parent.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Cache cleanup is best effort and must not hide conversion results.
      }
    }
    for (final directoryPath in parentDirectories) {
      try {
        final directory = Directory(directoryPath);
        if (await directory.exists() && await directory.list().isEmpty) {
          await directory.delete();
        }
      } catch (_) {
        // Ignore cache cleanup failures.
      }
    }
  }

  static void _progress(
    ConversionProgressCallback? callback,
    ConversionStage stage,
    String message, {
    int? current,
    int? total,
  }) {
    callback?.call(
      ConversionProgress(
        stage: stage,
        message: message,
        current: current,
        total: total,
      ),
    );
  }

  static String _safeFileName(String title) {
    final sanitized = title
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    return sanitized.isEmpty ? 'Converted Document' : sanitized;
  }

  static String _xml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static int _pointsToTwips(double points) => (points * 20).round();

  static int _pointsToEmu(double points) => (points * 12700).round();
}

class _DocxParagraph {
  _DocxParagraph(this.text);

  final String text;
}

class _DocxImagePage {
  _DocxImagePage({
    required this.relationshipId,
    required this.fileName,
    required this.contentType,
    required this.bytes,
    required this.widthPoints,
    required this.heightPoints,
  });

  final String relationshipId;
  final String fileName;
  final String contentType;
  final List<int> bytes;
  final double widthPoints;
  final double heightPoints;
}
