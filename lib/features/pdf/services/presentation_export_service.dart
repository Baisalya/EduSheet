import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/services/office_text_formatter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PresentationExportService {
  static Future<File> exportAndOpen(Paper paper, PaperTemplate template) async {
    final file = await export(paper, template);
    await OpenFilex.open(file.path);
    return file;
  }

  static Future<File> export(Paper paper, PaperTemplate template) async {
    final exportDir = await _exportDirectory();
    final fileName =
        '${OfficeTextFormatter.safeFileName(paper.title, 'Question Paper')}.pptx';
    final file = File(p.join(exportDir.path, fileName));
    await file.writeAsBytes(_buildPackage(paper, template), flush: true);
    return file;
  }

  static Future<Directory> _exportDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(directory.path, 'EduSheet Exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }

  static List<int> _buildPackage(Paper paper, PaperTemplate template) {
    final slides = _slides(paper);
    final archive = Archive();

    void addString(String name, String content) {
      archive.addFile(ArchiveFile.string(name, content));
    }

    addString('[Content_Types].xml', _contentTypesXml(slides.length));
    addString('_rels/.rels', _rootRelsXml());
    addString('docProps/core.xml', _coreXml(paper));
    addString('docProps/app.xml', _appXml(slides.length));
    addString('ppt/presentation.xml', _presentationXml(slides.length));
    addString(
      'ppt/_rels/presentation.xml.rels',
      _presentationRelsXml(slides.length),
    );
    addString('ppt/theme/theme1.xml', _themeXml());
    addString('ppt/slideMasters/slideMaster1.xml', _slideMasterXml());
    addString(
      'ppt/slideMasters/_rels/slideMaster1.xml.rels',
      _slideMasterRelsXml(),
    );
    addString('ppt/slideLayouts/slideLayout1.xml', _slideLayoutXml());
    addString(
      'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
      _slideLayoutRelsXml(),
    );

    for (final entry in slides.asMap().entries) {
      addString(
        'ppt/slides/slide${entry.key + 1}.xml',
        _slideXml(entry.value, entry.key + 1),
      );
      addString(
        'ppt/slides/_rels/slide${entry.key + 1}.xml.rels',
        _slideRelsXml(),
      );
    }

    return ZipEncoder().encode(archive);
  }

  static List<_SlideSpec> _slides(Paper paper) {
    final slides = <_SlideSpec>[
      _SlideSpec(
        title: paper.title.isEmpty ? 'Question Paper' : paper.title,
        lines: [
          if (paper.schoolName.trim().isNotEmpty) paper.schoolName,
          'Total Marks: ${paper.totalMarks.toStringAsFixed(0)}',
          if (paper.instruction.trim().isNotEmpty) paper.instruction.trim(),
        ],
        kind: _SlideKind.title,
      ),
    ];

    for (final section in paper.sections) {
      final sectionTitle = _sectionLabel(section);
      slides.add(
        _SlideSpec(
          title: sectionTitle,
          lines: [
            if (section.instruction?.trim().isNotEmpty == true)
              section.instruction!.trim(),
            if (section.requiredCount != null)
              'Answer any ${section.requiredCount}',
          ],
          kind: _SlideKind.section,
        ),
      );

      for (final entry in section.questions.asMap().entries) {
        final question = entry.value;
        slides.add(
          _SlideSpec(
            title:
                '$sectionTitle - Q${entry.key + 1} (${_marks(question.marks)} marks)',
            lines: [
              OfficeTextFormatter.questionText(question.text),
              if (question.isOptional) '(Optional/OR Choice)',
              ..._questionDetailLines(question),
            ],
            kind: _SlideKind.question,
          ),
        );
      }
    }

    return slides;
  }

  static List<String> _questionDetailLines(Question question) {
    if (question.type == QuestionType.mcq) {
      return question.options.asMap().entries.map((entry) {
        return '${String.fromCharCode(65 + entry.key)}) ${entry.value.text}';
      }).toList();
    }
    if (question.type == QuestionType.fillInTheBlanks) {
      return const ['Ans: ________________________'];
    }
    return const [];
  }

  static String _slideXml(_SlideSpec slide, int slideNumber) {
    final accent = switch (slide.kind) {
      _SlideKind.title => '1F4E79',
      _SlideKind.section => '2F6F4E',
      _SlideKind.question => '333333',
    };

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">'
        '<p:cSld><p:spTree>'
        '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
        '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
        '${_shape(2, 'Title', slide.title, 685800, 457200, 10820400, 960120, 3600, true, accent)}'
        '${_shape(3, 'Body', slide.lines.join('\n'), 914400, 1600200, 10363200, 4343400, 2100, false, '222222')}'
        '${_shape(4, 'Footer', 'EduSheet  |  Slide $slideNumber', 914400, 6172200, 10363200, 365760, 1100, false, '777777')}'
        '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>';
  }

  static String _shape(
    int id,
    String name,
    String text,
    int x,
    int y,
    int width,
    int height,
    int fontSize,
    bool bold,
    String color,
  ) {
    final paragraphs = text
        .split('\n')
        .map((line) => _paragraph(line, fontSize, bold, color))
        .join();

    return '<p:sp><p:nvSpPr><p:cNvPr id="$id" name="$name"/>'
        '<p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>'
        '<p:spPr><a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$width" cy="$height"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/></p:spPr>'
        '<p:txBody><a:bodyPr wrap="square"><a:spAutoFit/></a:bodyPr><a:lstStyle/>'
        '$paragraphs</p:txBody></p:sp>';
  }

  static String _paragraph(String text, int fontSize, bool bold, String color) {
    final boldAttr = bold ? ' b="1"' : '';
    return '<a:p><a:r><a:rPr lang="en-US" sz="$fontSize"$boldAttr>'
        '<a:solidFill><a:srgbClr val="$color"/></a:solidFill></a:rPr>'
        '<a:t>${OfficeTextFormatter.xml(text)}</a:t></a:r></a:p>';
  }

  static String _presentationXml(int slideCount) {
    final slideIds = List.generate(slideCount, (index) {
      return '<p:sldId id="${256 + index}" r:id="rId${index + 2}"/>';
    }).join();

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">'
        '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>'
        '<p:sldIdLst>$slideIds</p:sldIdLst>'
        '<p:sldSz cx="12192000" cy="6858000" type="screen16x9"/>'
        '<p:notesSz cx="6858000" cy="9144000"/>'
        '</p:presentation>';
  }

  static String _presentationRelsXml(int slideCount) {
    final slideRels = List.generate(slideCount, (index) {
      return '<Relationship Id="rId${index + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide${index + 1}.xml"/>';
    }).join();

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>'
        '$slideRels</Relationships>';
  }

  static String _slideRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>'
        '</Relationships>';
  }

  static String _slideMasterXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">'
        '<p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/>'
        '<p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm>'
        '<a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/>'
        '<a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld>'
        '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" '
        'accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" '
        'accent6="accent6" hlink="hlink" folHlink="folHlink"/>'
        '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>'
        '<p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles>'
        '</p:sldMaster>';
  }

  static String _slideMasterRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>'
        '</Relationships>';
  }

  static String _slideLayoutXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank">'
        '<p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/>'
        '<p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm>'
        '<a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/>'
        '<a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld>'
        '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>';
  }

  static String _slideLayoutRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>'
        '</Relationships>';
  }

  static String _themeXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="EduSheet">'
        '<a:themeElements><a:clrScheme name="EduSheet">'
        '<a:dk1><a:srgbClr val="222222"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>'
        '<a:dk2><a:srgbClr val="333333"/></a:dk2><a:lt2><a:srgbClr val="F7F9FC"/></a:lt2>'
        '<a:accent1><a:srgbClr val="1F4E79"/></a:accent1><a:accent2><a:srgbClr val="2F6F4E"/></a:accent2>'
        '<a:accent3><a:srgbClr val="B45F06"/></a:accent3><a:accent4><a:srgbClr val="8064A2"/></a:accent4>'
        '<a:accent5><a:srgbClr val="4BACC6"/></a:accent5><a:accent6><a:srgbClr val="F79646"/></a:accent6>'
        '<a:hlink><a:srgbClr val="0000FF"/></a:hlink><a:folHlink><a:srgbClr val="800080"/></a:folHlink>'
        '</a:clrScheme><a:fontScheme name="EduSheet"><a:majorFont><a:latin typeface="Calibri"/>'
        '</a:majorFont><a:minorFont><a:latin typeface="Calibri"/></a:minorFont></a:fontScheme>'
        '<a:fmtScheme name="EduSheet"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>'
        '<a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst>'
        '<a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>'
        '<a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst>'
        '</a:fmtScheme></a:themeElements></a:theme>';
  }

  static String _contentTypesXml(int slideCount) {
    final slideOverrides = List.generate(slideCount, (index) {
      return '<Override PartName="/ppt/slides/slide${index + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>';
    }).join();

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>'
        '<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>'
        '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>'
        '<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>'
        '$slideOverrides'
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
        '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
        '</Types>';
  }

  static String _rootRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>'
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
        '<dc:title>${OfficeTextFormatter.xml(paper.title)}</dc:title>'
        '<dc:creator>EduSheet</dc:creator>'
        '<cp:lastModifiedBy>EduSheet</cp:lastModifiedBy>'
        '<dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created>'
        '<dcterms:modified xsi:type="dcterms:W3CDTF">$now</dcterms:modified>'
        '</cp:coreProperties>';
  }

  static String _appXml(int slideCount) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
        'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
        '<Application>EduSheet</Application><Slides>$slideCount</Slides></Properties>';
  }

  static String _sectionLabel(PaperSection section) {
    final label = '${section.prefix} ${section.title}'.trim();
    return label.isEmpty ? 'Section' : label;
  }

  static String _marks(double marks) {
    return marks.toStringAsFixed(marks.truncateToDouble() == marks ? 0 : 1);
  }
}

class _SlideSpec {
  final String title;
  final List<String> lines;
  final _SlideKind kind;

  const _SlideSpec({
    required this.title,
    required this.lines,
    required this.kind,
  });
}

enum _SlideKind { title, section, question }
