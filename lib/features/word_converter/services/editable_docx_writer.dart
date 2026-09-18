import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:edusheet/features/word_converter/domain/models/editable_document.dart';

class EditableDocxWriter {
  const EditableDocxWriter._();

  static List<int> build(EditableDocument document) {
    final archive = Archive();

    void addString(String name, String content) {
      archive.addFile(ArchiveFile.string(name, content));
    }

    addString('[Content_Types].xml', _contentTypesXml());
    addString('_rels/.rels', _rootRelsXml());
    addString('docProps/core.xml', _coreXml());
    addString('docProps/app.xml', _appXml());
    addString('word/_rels/document.xml.rels', _documentRelsXml());
    addString('word/styles.xml', _stylesXml());
    addString('word/document.xml', _documentXml(document));

    return ZipEncoder().encode(archive);
  }

  static String _documentXml(EditableDocument document) {
    final pages = document.pages;
    final body = StringBuffer();

    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final page = pages[pageIndex];
      for (final block in page.blocks) {
        body.write(_blockXml(block));
      }

      if (pageIndex < pages.length - 1) {
        body.write(
          '<w:p><w:pPr>${_sectionProperties(page, nextPage: true)}</w:pPr></w:p>',
        );
      }
    }

    final lastPage = pages.isEmpty
        ? const EditablePage(
            pageIndex: 0,
            size: Size(595, 842),
            blocks: [],
          )
        : pages.last;

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<w:body>${body.toString()}${_sectionProperties(lastPage)}</w:body>'
        '</w:document>';
  }

  static String _blockXml(EditableBlock block) {
    return switch (block) {
      EditableParagraphBlock paragraph => _paragraphXml(paragraph),
      EditableTableBlock table => _tableXml(table),
    };
  }

  static String _paragraphXml(EditableParagraphBlock paragraph) {
    final pPr = StringBuffer('<w:pPr>');
    final styleId = switch (paragraph.kind) {
      EditableParagraphKind.heading1 => 'Heading1',
      EditableParagraphKind.heading2 => 'Heading2',
      EditableParagraphKind.listItem => 'ListParagraph',
      EditableParagraphKind.body => 'Normal',
    };
    pPr.write('<w:pStyle w:val="$styleId"/>');

    final alignment = switch (paragraph.alignment) {
      EditableParagraphAlignment.left => 'left',
      EditableParagraphAlignment.center => 'center',
      EditableParagraphAlignment.right => 'right',
      EditableParagraphAlignment.justify => 'both',
    };
    pPr.write('<w:jc w:val="$alignment"/>');

    if (paragraph.leftIndentPoints > 0.5) {
      pPr.write(
        '<w:ind w:left="${_pointsToTwips(paragraph.leftIndentPoints)}"/>',
      );
    }
    pPr.write(
      '<w:spacing w:before="${_pointsToTwips(paragraph.spaceBeforePoints)}" '
      'w:after="${_pointsToTwips(paragraph.spaceAfterPoints)}"/>',
    );
    if (paragraph.kind == EditableParagraphKind.heading1 ||
        paragraph.kind == EditableParagraphKind.heading2) {
      pPr.write('<w:keepNext/>');
    }
    pPr.write('</w:pPr>');

    final runs = paragraph.runs.isEmpty
        ? '<w:r><w:t/></w:r>'
        : paragraph.runs.map(_runXml).join();
    return '<w:p>${pPr.toString()}$runs</w:p>';
  }

  static String _runXml(EditableTextRun run) {
    final style = run.style;
    final rPr = StringBuffer('<w:rPr>');
    final fontFamily = _safeFontFamily(style.fontFamily);
    if (fontFamily != null) {
      final escaped = _xml(fontFamily);
      rPr.write(
        '<w:rFonts w:ascii="$escaped" w:hAnsi="$escaped" w:cs="$escaped"/>',
      );
    }
    if (style.bold) {
      rPr.write('<w:b/><w:bCs/>');
    }
    if (style.italic) rPr.write('<w:i/><w:iCs/>');
    if (style.underline) rPr.write('<w:u w:val="single"/>');
    if (style.strike) rPr.write('<w:strike/>');

    final sourceSize = style.fontSizePoints <= 0 ? 11.0 : style.fontSizePoints;
    final halfPoints = (sourceSize * 2).round().clamp(2, 400);
    rPr.write('<w:sz w:val="$halfPoints"/><w:szCs w:val="$halfPoints"/>');
    rPr.write('</w:rPr>');

    return '<w:r>${rPr.toString()}'
        '<w:t xml:space="preserve">${_xml(run.text)}</w:t></w:r>';
  }

  static String _tableXml(EditableTableBlock table) {
    final grid = table.columnWidthsPoints
        .map((width) => '<w:gridCol w:w="${_pointsToTwips(width)}"/>')
        .join();
    final rows = table.rows.map((row) => _tableRowXml(row, table)).join();

    return '<w:tbl>'
        '<w:tblPr>'
        '<w:tblW w:w="0" w:type="auto"/>'
        '<w:tblLayout w:type="fixed"/>'
        '<w:tblCellMar><w:top w:w="45" w:type="dxa"/>'
        '<w:left w:w="70" w:type="dxa"/>'
        '<w:bottom w:w="45" w:type="dxa"/>'
        '<w:right w:w="70" w:type="dxa"/></w:tblCellMar>'
        '</w:tblPr>'
        '<w:tblGrid>$grid</w:tblGrid>'
        '$rows</w:tbl>';
  }

  static String _tableRowXml(EditableTableRow row, EditableTableBlock table) {
    final cells = <String>[];
    for (var index = 0; index < row.cells.length; index++) {
      final width = index < table.columnWidthsPoints.length
          ? table.columnWidthsPoints[index]
          : 72.0;
      final cell = row.cells[index];
      final content = cell.paragraphs.isEmpty
          ? '<w:p/>'
          : cell.paragraphs.map(_paragraphXml).join();
      cells.add(
        '<w:tc><w:tcPr><w:tcW w:w="${_pointsToTwips(width)}" w:type="dxa"/>'
        '</w:tcPr>$content</w:tc>',
      );
    }
    return '<w:tr>${cells.join()}</w:tr>';
  }

  static String _sectionProperties(
    EditablePage page, {
    bool nextPage = false,
  }) {
    final width = _pointsToTwips(page.size.width);
    final height = _pointsToTwips(page.size.height);
    final orientation = width > height ? ' w:orient="landscape"' : '';
    final margins = page.margins;

    return '<w:sectPr>'
        '${nextPage ? '<w:type w:val="nextPage"/>' : ''}'
        '<w:pgSz w:w="$width" w:h="$height"$orientation/>'
        '<w:pgMar w:top="${_pointsToTwips(margins.topPoints)}" '
        'w:right="${_pointsToTwips(margins.rightPoints)}" '
        'w:bottom="${_pointsToTwips(margins.bottomPoints)}" '
        'w:left="${_pointsToTwips(margins.leftPoints)}" '
        'w:header="360" w:footer="360" w:gutter="0"/>'
        '</w:sectPr>';
  }

  static String _stylesXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:docDefaults><w:rPrDefault><w:rPr>'
        '<w:sz w:val="22"/><w:szCs w:val="22"/>'
        '</w:rPr></w:rPrDefault>'
        '<w:pPrDefault><w:pPr><w:spacing w:after="120"/></w:pPr></w:pPrDefault>'
        '</w:docDefaults>'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
        '<w:name w:val="Normal"/><w:qFormat/></w:style>'
        '<w:style w:type="paragraph" w:styleId="Heading1">'
        '<w:name w:val="heading 1"/><w:basedOn w:val="Normal"/>'
        '<w:next w:val="Normal"/><w:qFormat/>'
        '<w:pPr><w:keepNext/><w:outlineLvl w:val="0"/></w:pPr>'
        '</w:style>'
        '<w:style w:type="paragraph" w:styleId="Heading2">'
        '<w:name w:val="heading 2"/><w:basedOn w:val="Normal"/>'
        '<w:next w:val="Normal"/><w:qFormat/>'
        '<w:pPr><w:keepNext/><w:outlineLvl w:val="1"/></w:pPr>'
        '</w:style>'
        '<w:style w:type="paragraph" w:styleId="ListParagraph">'
        '<w:name w:val="List Paragraph"/><w:basedOn w:val="Normal"/>'
        '<w:qFormat/>'
        '</w:style>'
        '</w:styles>';
  }

  static String _contentTypesXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
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

  static String _documentRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>';
  }

  static String _coreXml() {
    final now = DateTime.now().toUtc().toIso8601String();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>Converted Document</dc:title><dc:creator>EduSheet</dc:creator>'
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

  static String? _safeFontFamily(String? family) {
    if (family == null) return null;
    final normalized = family.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static int _pointsToTwips(double points) => (points * 20).round();

  static String _xml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
