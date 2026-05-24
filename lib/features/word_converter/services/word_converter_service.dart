import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/core/services/ocr_service.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:xml/xml.dart' as xml;

class WordConverterService {
  static const _wordNamespace =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  static const _relationsNamespace =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _pdfRendererChannel = MethodChannel('edusheet/pdf_renderer');

  static Future<File> convertDocxToPdf(String docxPath) async {
    final paragraphs = await _extractDocxParagraphs(File(docxPath));
    if (paragraphs.isEmpty) {
      throw const FormatException('No readable text found in this Word file.');
    }

    final output = await _outputFile(docxPath, '.pdf');
    final font = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
    );

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            p.basenameWithoutExtension(docxPath),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          ...paragraphs.map(
            (paragraph) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                paragraph,
                style: const pw.TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );

    await output.writeAsBytes(await pdf.save(), flush: true);
    return output;
  }

  static Future<File> convertTextToDocx(String textPath) async {
    final input = File(textPath);
    final text = await input.readAsString();
    final paragraphs = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trimRight())
        .map((line) => _DocxParagraph(line))
        .toList();

    final output = await _outputFile(textPath, '.docx');
    await output.writeAsBytes(_buildDocx(paragraphs), flush: true);
    return output;
  }

  static Future<File> convertPdfToDocx(String pdfPath) async {
    final paragraphs = await _extractPdfParagraphs(File(pdfPath));
    if (paragraphs.isEmpty) {
      throw const FormatException(
        'No readable text found in this PDF. For scanned PDFs, use a clearer scan and try again.',
      );
    }

    final output = await _outputFile(pdfPath, '.docx');
    await output.writeAsBytes(_buildDocx(paragraphs), flush: true);
    return output;
  }

  static Future<File> convertPdfToDocxExact(String pdfPath) async {
    final input = File(pdfPath);
    final pageImages = await _buildPdfPageImages(input);
    if (pageImages.isEmpty) {
      throw const FormatException(
        'Exact PDF conversion is unavailable on this device. Please use Editable Text mode instead.',
      );
    }

    final output = await _outputFile(pdfPath, '.docx');
    await output.writeAsBytes(_buildImageDocx(pageImages), flush: true);
    return output;
  }

  static Future<void> open(File file) async {
    await OpenFilex.open(file.path);
  }

  static Future<File> _outputFile(String sourcePath, String extension) async {
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

  static Future<List<String>> _extractDocxParagraphs(File file) async {
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final documentFile = archive.files.firstWhere(
      (entry) => entry.name == 'word/document.xml',
      orElse: () => throw const FormatException('Invalid .docx file.'),
    );
    final documentXml = utf8.decode(documentFile.content);
    final document = xml.XmlDocument.parse(documentXml);

    final paragraphs = <String>[];
    final paragraphElements = document.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 'p');

    for (final paragraph in paragraphElements) {
      final buffer = StringBuffer();
      for (final element in paragraph.descendants.whereType<xml.XmlElement>()) {
        switch (element.name.local) {
          case 't':
            buffer.write(element.innerText);
            break;
          case 'tab':
            buffer.write('\t');
            break;
          case 'br':
            buffer.write('\n');
            break;
        }
      }

      final text = buffer.toString().trim();
      if (text.isNotEmpty) {
        paragraphs.add(text);
      }
    }

    return paragraphs;
  }

  static Future<List<_DocxParagraph>> _extractPdfParagraphs(File file) async {
    final document = sf.PdfDocument(inputBytes: await file.readAsBytes());
    try {
      final extractor = sf.PdfTextExtractor(document);
      final pageParagraphs = <List<_DocxParagraph>>[];
      final pagesNeedingOcr = <int>[];

      for (var pageIndex = 0; pageIndex < document.pages.count; pageIndex++) {
        final pageText = extractor.extractText(
          startPageIndex: pageIndex,
          endPageIndex: pageIndex,
        );
        final paragraphs = _normalizePdfText(pageText);
        pageParagraphs.add(paragraphs);

        if (paragraphs.isEmpty) {
          pagesNeedingOcr.add(pageIndex);
        }
      }

      if (pagesNeedingOcr.isNotEmpty) {
        final ocrPages = await _extractPdfParagraphsWithOcr(file);
        for (final pageIndex in pagesNeedingOcr) {
          if (pageIndex < ocrPages.length && ocrPages[pageIndex].isNotEmpty) {
            pageParagraphs[pageIndex] = ocrPages[pageIndex];
          }
        }
      }

      return _flattenPages(pageParagraphs);
    } finally {
      document.dispose();
    }
  }

  static Future<List<List<_DocxParagraph>>> _extractPdfParagraphsWithOcr(
    File file,
  ) async {
    final imagePaths = await _renderPdfPages(file);
    if (imagePaths.isEmpty) return const [];

    final ocrService = OCRService();
    try {
      final pages = <List<_DocxParagraph>>[];
      for (final imagePath in imagePaths) {
        final text = await ocrService.recognizeTextAuto(imagePath);
        pages.add(_normalizePdfText(text));
      }
      return pages;
    } finally {
      ocrService.dispose();
    }
  }

  static Future<List<_DocxImagePage>> _buildPdfPageImages(File file) async {
    final imagePaths = await _renderPdfPages(file, throwOnFailure: true);
    if (imagePaths.isEmpty) return const [];

    final document = sf.PdfDocument(inputBytes: await file.readAsBytes());
    try {
      final pageImages = <_DocxImagePage>[];
      for (var index = 0; index < imagePaths.length; index++) {
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
          'Exact PDF conversion is unavailable on this platform: ${error.message ?? error.toString()}',
        );
      }
      return const [];
    } on PlatformException catch (error) {
      if (throwOnFailure) {
        throw FormatException(
          'Could not render PDF pages for exact conversion: ${error.message ?? error.code}',
        );
      }
      return const [];
    }
  }

  static List<_DocxParagraph> _normalizePdfText(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final paragraphs = <_DocxParagraph>[];
    var previousWasBlank = false;

    for (final rawLine in normalized.split('\n')) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        if (paragraphs.isNotEmpty && !previousWasBlank) {
          paragraphs.add(_DocxParagraph(''));
        }
        previousWasBlank = true;
        continue;
      }

      paragraphs.add(_DocxParagraph(line));
      previousWasBlank = false;
    }

    while (paragraphs.isNotEmpty && paragraphs.last.text.trim().isEmpty) {
      paragraphs.removeLast();
    }

    return paragraphs;
  }

  static List<_DocxParagraph> _flattenPages(
    List<List<_DocxParagraph>> pageParagraphs,
  ) {
    final paragraphs = <_DocxParagraph>[];

    for (final page in pageParagraphs) {
      if (page.isEmpty) continue;
      if (paragraphs.isNotEmpty) {
        page.first.pageBreakBefore = true;
      }
      paragraphs.addAll(page);
    }

    return paragraphs;
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
    final content = pages.map(_imagePageParagraph).join();
    final section = pages.isEmpty
        ? _sectionProperties(595, 842)
        : _sectionProperties(pages.last.widthPoints, pages.last.heightPoints);

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="$_wordNamespace" xmlns:r="$_relationsNamespace" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<w:body>$content$section</w:body></w:document>';
  }

  static String _imagePageParagraph(_DocxImagePage page) {
    final pageBreak = page.isFirst ? '' : '<w:r><w:br w:type="page"/></w:r>';
    final widthEmu = _pointsToEmu(page.widthPoints);
    final heightEmu = _pointsToEmu(page.heightPoints);
    final id = page.relationshipId.replaceAll(RegExp(r'\D'), '');

    return '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr>'
        '$pageBreak<w:r><w:drawing>'
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
    final pageBreak = paragraph.pageBreakBefore
        ? '<w:r><w:br w:type="page"/></w:r>'
        : '';
    return '<w:p><w:pPr><w:spacing w:after="120"/></w:pPr>$pageBreak'
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

  static String _sectionProperties(double widthPoints, double heightPoints) {
    final widthTwips = _pointsToTwips(widthPoints);
    final heightTwips = _pointsToTwips(heightPoints);
    final orientation = widthTwips > heightTwips ? ' w:orient="landscape"' : '';
    return '<w:sectPr><w:pgSz w:w="$widthTwips" w:h="$heightTwips"$orientation/>'
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
  bool pageBreakBefore = false;
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

  bool get isFirst => relationshipId == 'rId1';
}
