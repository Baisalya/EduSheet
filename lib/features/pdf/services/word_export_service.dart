import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/question_numbering_service.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/services/export_file_service.dart';
import 'package:edusheet/features/pdf/services/office_text_formatter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

class WordExportService {
  static const _wordNamespace =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  static const _relationsNamespace =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  static Future<File> exportAndOpen(Paper paper, PaperTemplate template) async {
    final file = await export(paper, template);
    await OpenFilex.open(file.path);
    return file;
  }

  static Future<File> export(
    Paper paper,
    PaperTemplate template, {
    String? fileNameBase,
  }) async {
    final file = await ExportFileService.uniqueFile(
      fileNameBase: fileNameBase ?? paper.title,
      extension: '.docx',
    );
    final package = await _buildPackage(paper, template);
    await file.writeAsBytes(package, flush: true);
    return file;
  }

  static Future<List<int>> _buildPackage(
    Paper paper,
    PaperTemplate template,
  ) async {
    final archive = Archive();
    final imageParts = await _readImageParts(paper);

    void addString(String name, String content) {
      archive.addFile(ArchiveFile.string(name, content));
    }

    addString('[Content_Types].xml', _contentTypesXml(imageParts));
    addString('_rels/.rels', _rootRelsXml());
    addString('docProps/core.xml', _coreXml(paper));
    addString('docProps/app.xml', _appXml());
    addString('word/_rels/document.xml.rels', _documentRelsXml(imageParts));
    addString('word/document.xml', _documentXml(paper, template, imageParts));

    for (final image in imageParts) {
      archive.addFile(
        ArchiveFile.bytes('word/media/${image.fileName}', image.bytes),
      );
    }

    return ZipEncoder().encode(archive);
  }

  static Future<List<_ImagePart>> _readImageParts(Paper paper) async {
    final images = <_ImagePart>[];
    var relationshipIndex = 1;

    for (final logoPath in paper.logos.where(
      (path) => path.trim().isNotEmpty,
    )) {
      final file = File(logoPath);
      if (!await file.exists()) continue;

      final extension = _imageExtension(file.path);
      if (extension == null) continue;

      images.add(
        _ImagePart(
          relationshipId: 'rId$relationshipIndex',
          fileName: 'image$relationshipIndex.$extension',
          contentType: _imageContentType(extension),
          bytes: await file.readAsBytes(),
        ),
      );
      relationshipIndex++;
    }

    return images;
  }

  static String _documentXml(
    Paper paper,
    PaperTemplate template,
    List<_ImagePart> images,
  ) {
    final buffer = StringBuffer();

    buffer
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
        '<w:document xmlns:w="$_wordNamespace" xmlns:r="$_relationsNamespace" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">',
      )
      ..write('<w:body>');

    if (template.hasBorder) {
      buffer.write(_paragraph('', spacingAfter: 80));
    }

    buffer.write(_headerXml(paper, template, images));

    if (paper.instruction.trim().isNotEmpty) {
      buffer.write(
        _paragraph(
          paper.instruction.trim(),
          alignment: 'center',
          bold: true,
          italic: true,
          fontSize: template.questionFontSize,
          spacingAfter: 180,
        ),
      );
    }

    for (final section in paper.sections) {
      buffer.write(_sectionXml(section, template, paper));
    }

    if (paper.includeOmr) {
      buffer.write(
        _paragraph(
          'OMR sheet is included in PDF export only.',
          italic: true,
          fontSize: template.questionFontSize,
          spacingBefore: 240,
        ),
      );
    }

    buffer
      ..write(_sectionProperties(template))
      ..write('</w:body></w:document>');

    return buffer.toString();
  }

  static String _headerXml(
    Paper paper,
    PaperTemplate template,
    List<_ImagePart> images,
  ) {
    final layout = template.effectiveLayout;
    final buffer = StringBuffer();
    var imageIndex = 0;

    final elements = [...layout.elements]
      ..sort((a, b) {
        final y = a.y.compareTo(b.y);
        return y != 0 ? y : a.x.compareTo(b.x);
      });

    for (final element in elements) {
      final alignment = _wordAlignment(element.properties['alignment']);
      final fontSize =
          (element.properties['fontSize'] as num?)?.toDouble() ??
          template.questionFontSize;
      final bold = element.properties['bold'] == true;
      final italic = element.properties['italic'] == true;
      final underline = element.properties['decoration'] == 'underline';

      switch (element.type) {
        case ElementType.logo:
          if (imageIndex < images.length) {
            buffer.write(
              _imageParagraph(images[imageIndex], alignment: alignment),
            );
            imageIndex++;
          }
          break;
        case ElementType.schoolName:
          buffer.write(
            _paragraph(
              paper.schoolName,
              alignment: alignment,
              bold: bold,
              italic: italic,
              underline: underline,
              fontSize: fontSize,
            ),
          );
          break;
        case ElementType.paperTitle:
          buffer.write(
            _paragraph(
              paper.title,
              alignment: alignment,
              bold: bold,
              italic: italic,
              underline: underline,
              fontSize: fontSize,
            ),
          );
          break;
        case ElementType.maxMarks:
          buffer.write(
            _paragraph(
              'Max Marks: ${paper.totalMarks.toStringAsFixed(0)}',
              alignment: alignment,
              bold: true,
              fontSize: fontSize,
            ),
          );
          break;
        case ElementType.headerFieldsBlock:
          buffer.write(_headerFieldsXml(paper, element, fontSize, alignment));
          break;
        case ElementType.staticText:
          final content =
              paper.customHeaderValues[element.paperBindingKey] ??
              element.content;
          if (content.trim().isNotEmpty) {
            buffer.write(
              _paragraph(
                content,
                alignment: alignment,
                bold: bold,
                italic: italic,
                underline: underline,
                fontSize: fontSize,
              ),
            );
          }
          break;
        case ElementType.horizontalLine:
          buffer.write(_divider());
          break;
        case ElementType.rectangular:
          if (element.content.trim().isNotEmpty) {
            buffer.write(
              _paragraph(
                element.content,
                alignment: alignment,
                bold: bold,
                fontSize: fontSize,
              ),
            );
          }
          break;
      }
    }

    return buffer.toString();
  }

  static String _headerFieldsXml(
    Paper paper,
    TemplateElement element,
    double fontSize,
    String alignment,
  ) {
    final labels = List<String>.from(
      element.properties['fieldLabels'] ?? ['Subject', 'Date'],
    );
    if (labels.isEmpty) return '';

    final cells = labels.map((label) {
      final field = paper.headerFields.firstWhere(
        (item) => item.label.toLowerCase() == label.toLowerCase(),
        orElse: () =>
            PaperHeaderField(id: '', label: label, isPlaceholder: true),
      );
      final content = field.isPlaceholder ? '________________' : field.value;
      return _tableCell(
        _paragraphRuns([
          _Run('${field.label}: ', bold: true, fontSize: fontSize * 0.85),
          _Run(content, fontSize: fontSize * 0.85),
        ], alignment: alignment),
      );
    }).join();

    return '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/></w:tblPr>'
        '<w:tr>$cells</w:tr></w:tbl>';
  }

  static String _sectionXml(
    PaperSection section,
    PaperTemplate template,
    Paper paper,
  ) {
    final buffer = StringBuffer();

    if (section.showTitle || section.prefix.isNotEmpty) {
      buffer.write(
        _paragraph(
          '${section.prefix} ${section.showTitle ? section.title : ""}'.trim(),
          bold: true,
          fontSize: 16,
          spacingBefore: 240,
          spacingAfter: 80,
        ),
      );
    }

    if (section.instruction?.trim().isNotEmpty == true) {
      buffer.write(
        _paragraph(
          'Instruction: ${section.instruction!.trim()}',
          italic: true,
          fontSize: 11,
          spacingAfter: 80,
        ),
      );
    }

    if (section.requiredCount != null &&
        section.requiredCount! < section.questions.length) {
      buffer.write(
        _paragraph(
          'Note: Answer any ${section.requiredCount} questions from this section.',
          bold: true,
          fontSize: 10,
          spacingAfter: 80,
        ),
      );
    }

    if (section.showDivider) {
      buffer.write(_divider());
    }

    if (template.paperLayout == PaperLayout.twoColumn) {
      buffer.write(
        '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
        '<w:tblCellMar><w:right w:w="180" w:type="dxa"/>'
        '<w:left w:w="180" w:type="dxa"/></w:tblCellMar></w:tblPr>',
      );
      for (var index = 0; index < section.questions.length; index += 2) {
        final left = _questionXml(
          index + 1,
          section.questions[index],
          template,
          paper,
        );
        final right = index + 1 < section.questions.length
            ? _questionXml(
                index + 2,
                section.questions[index + 1],
                template,
                paper,
              )
            : _paragraph('');
        buffer.write('<w:tr>${_tableCell(left)}${_tableCell(right)}</w:tr>');
      }
      buffer.write('</w:tbl>');
    } else {
      for (final entry in section.questions.asMap().entries) {
        buffer.write(_questionXml(entry.key + 1, entry.value, template, paper));
      }
    }

    return buffer.toString();
  }

  static String _questionXml(
    int index,
    Question question,
    PaperTemplate template,
    Paper paper,
  ) {
    final buffer = StringBuffer();
    final text = OfficeTextFormatter.questionText(question.text).trim();
    final alignment = _wordAlignment(_flutterTextAlignName(question.alignment));
    final label = QuestionNumberingService.paperLabel(index, paper);

    buffer.write(
      _paragraphRuns(
        [
          _Run('$label. ', bold: true, fontSize: template.questionFontSize),
          _Run(text, fontSize: template.questionFontSize),
          _Run(
            ' [${question.marks.toStringAsFixed(question.marks.truncateToDouble() == question.marks ? 0 : 1)}]',
            bold: true,
            fontSize: template.questionFontSize,
          ),
        ],
        alignment: alignment,
        spacingBefore: 80,
        spacingAfter: 80,
      ),
    );

    if (question.isOptional) {
      buffer.write(
        _paragraph(
          '(Optional/OR Choice)',
          italic: true,
          fontSize: 9,
          indentLeft: 360,
        ),
      );
    }

    if (question.type == QuestionType.mcq) {
      for (final option in question.options.asMap().entries) {
        buffer.write(
          _paragraph(
            '${String.fromCharCode(65 + option.key)}) ${option.value.text}',
            fontSize: template.questionFontSize,
            indentLeft: 360,
            spacingAfter: 40,
          ),
        );
      }
    }

    if (question.type == QuestionType.fillInTheBlanks) {
      buffer.write(
        _paragraph(
          'Ans: ________________________',
          fontSize: template.questionFontSize,
          indentLeft: 360,
          spacingAfter: 80,
        ),
      );
    }

    return buffer.toString();
  }

  static String _paragraph(
    String text, {
    String alignment = 'left',
    bool bold = false,
    bool italic = false,
    bool underline = false,
    double fontSize = 12,
    int spacingBefore = 0,
    int spacingAfter = 120,
    int indentLeft = 0,
  }) {
    return _paragraphRuns(
      [
        _Run(
          text,
          bold: bold,
          italic: italic,
          underline: underline,
          fontSize: fontSize,
        ),
      ],
      alignment: alignment,
      spacingBefore: spacingBefore,
      spacingAfter: spacingAfter,
      indentLeft: indentLeft,
    );
  }

  static String _paragraphRuns(
    List<_Run> runs, {
    String alignment = 'left',
    int spacingBefore = 0,
    int spacingAfter = 120,
    int indentLeft = 0,
  }) {
    final paragraphProperties = StringBuffer()
      ..write('<w:pPr>')
      ..write('<w:jc w:val="$alignment"/>')
      ..write('<w:spacing w:before="$spacingBefore" w:after="$spacingAfter"/>');
    if (indentLeft > 0) {
      paragraphProperties.write('<w:ind w:left="$indentLeft"/>');
    }
    paragraphProperties.write('</w:pPr>');

    return '<w:p>$paragraphProperties${runs.map(_runXml).join()}</w:p>';
  }

  static String _runXml(_Run run) {
    final halfPoints = (run.fontSize * 2).round();
    final properties = StringBuffer()
      ..write('<w:rPr>')
      ..write(run.bold ? '<w:b/>' : '')
      ..write(run.italic ? '<w:i/>' : '')
      ..write(run.underline ? '<w:u w:val="single"/>' : '')
      ..write('<w:sz w:val="$halfPoints"/>')
      ..write('<w:szCs w:val="$halfPoints"/>')
      ..write('</w:rPr>');

    return '<w:r>$properties<w:t xml:space="preserve">${_xml(run.text)}</w:t></w:r>';
  }

  static String _imageParagraph(
    _ImagePart image, {
    String alignment = 'center',
  }) {
    const int sizeEmu = 914400;
    final id = image.relationshipId.replaceAll(RegExp(r'\D'), '');

    return '<w:p><w:pPr><w:jc w:val="$alignment"/></w:pPr><w:r><w:drawing>'
        '<wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$sizeEmu" cy="$sizeEmu"/>'
        '<wp:docPr id="$id" name="Logo $id"/>'
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic><pic:nvPicPr><pic:cNvPr id="$id" name="${_xml(image.fileName)}"/>'
        '<pic:cNvPicPr/></pic:nvPicPr><pic:blipFill>'
        '<a:blip r:embed="${image.relationshipId}"/><a:stretch><a:fillRect/></a:stretch>'
        '</pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/>'
        '<a:ext cx="$sizeEmu" cy="$sizeEmu"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic></wp:inline>'
        '</w:drawing></w:r></w:p>';
  }

  static String _divider() {
    return '<w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="6" '
        'w:space="1" w:color="000000"/></w:pBdr>'
        '<w:spacing w:after="120"/></w:pPr></w:p>';
  }

  static String _tableCell(String content) {
    return '<w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr>'
        '$content</w:tc>';
  }

  static String _sectionProperties(PaperTemplate template) {
    final page = _pageSizeTwips(template.paperSize);
    final border = template.hasBorder
        ? '<w:pgBorders w:offsetFrom="page"><w:top w:val="single" w:sz="8" w:space="24" w:color="000000"/>'
              '<w:left w:val="single" w:sz="8" w:space="24" w:color="000000"/>'
              '<w:bottom w:val="single" w:sz="8" w:space="24" w:color="000000"/>'
              '<w:right w:val="single" w:sz="8" w:space="24" w:color="000000"/></w:pgBorders>'
        : '';

    return '<w:sectPr><w:pgSz w:w="${page.width}" w:h="${page.height}"/>'
        '<w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720" '
        'w:header="360" w:footer="360" w:gutter="0"/>'
        '<w:cols w:space="720"/>$border</w:sectPr>';
  }

  static _PageSize _pageSizeTwips(PaperSize size) {
    switch (size) {
      case PaperSize.a3:
        return const _PageSize(16838, 23811);
      case PaperSize.a5:
        return const _PageSize(8391, 11906);
      case PaperSize.letter:
        return const _PageSize(12240, 15840);
      case PaperSize.legal:
        return const _PageSize(12240, 20160);
      case PaperSize.a4:
        return const _PageSize(11906, 16838);
    }
  }

  static String _documentRelsXml(List<_ImagePart> images) {
    final rels = images.map((image) {
      return '<Relationship Id="${image.relationshipId}" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
          'Target="media/${image.fileName}"/>';
    }).join();

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '$rels</Relationships>';
  }

  static String _contentTypesXml(List<_ImagePart> images) {
    final imageDefaults = images
        .map(
          (image) =>
              '<Default Extension="${p.extension(image.fileName).substring(1)}" '
              'ContentType="${image.contentType}"/>',
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

  static String _coreXml(Paper paper) {
    final now = DateTime.now().toUtc().toIso8601String();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>${_xml(paper.title)}</dc:title>'
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

  static String _wordAlignment(String? alignment) {
    switch (alignment) {
      case 'center':
        return 'center';
      case 'right':
      case 'end':
        return 'right';
      case 'justify':
        return 'both';
      default:
        return 'left';
    }
  }

  static String _flutterTextAlignName(dynamic alignment) {
    final name = alignment.toString().split('.').last;
    return name == 'end' ? 'right' : name;
  }

  static String? _imageExtension(String filePath) {
    final extension = p.extension(filePath).replaceFirst('.', '').toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return extension;
      default:
        return null;
    }
  }

  static String _imageContentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/png';
    }
  }

  static String _xml(String value) {
    return OfficeTextFormatter.xml(value);
  }
}

class _Run {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final double fontSize;

  const _Run(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.fontSize = 12,
  });
}

class _ImagePart {
  final String relationshipId;
  final String fileName;
  final String contentType;
  final List<int> bytes;

  const _ImagePart({
    required this.relationshipId,
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });
}

class _PageSize {
  final int width;
  final int height;

  const _PageSize(this.width, this.height);
}
