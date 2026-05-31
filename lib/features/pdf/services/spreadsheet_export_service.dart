import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/question_numbering_service.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/services/office_text_formatter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SpreadsheetExportService {
  static Future<File> exportAndOpen(Paper paper, PaperTemplate template) async {
    final file = await export(paper, template);
    await OpenFilex.open(file.path);
    return file;
  }

  static Future<File> export(Paper paper, PaperTemplate template) async {
    final exportDir = await _exportDirectory();
    final fileName =
        '${OfficeTextFormatter.safeFileName(paper.title, 'Question Paper')}.xlsx';
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
    final archive = Archive();

    void addString(String name, String content) {
      archive.addFile(ArchiveFile.string(name, content));
    }

    addString('[Content_Types].xml', _contentTypesXml());
    addString('_rels/.rels', _rootRelsXml());
    addString('docProps/core.xml', _coreXml(paper));
    addString('docProps/app.xml', _appXml());
    addString('xl/workbook.xml', _workbookXml());
    addString('xl/_rels/workbook.xml.rels', _workbookRelsXml());
    addString('xl/styles.xml', _stylesXml());
    addString(
      'xl/worksheets/sheet1.xml',
      _sheetXml(_summaryRows(paper, template)),
    );
    addString('xl/worksheets/sheet2.xml', _sheetXml(_questionRows(paper)));
    addString('xl/worksheets/sheet3.xml', _sheetXml(_optionRows(paper)));

    return ZipEncoder().encode(archive);
  }

  static List<List<Object?>> _summaryRows(Paper paper, PaperTemplate template) {
    final rows = <List<Object?>>[
      ['Field', 'Value'],
      ['Title', paper.title],
      ['School', paper.schoolName],
      ['Total Marks', paper.totalMarks],
      ['Template', template.name],
      ['Instruction', paper.instruction],
      ['OMR', paper.includeOmr ? 'PDF only' : 'No'],
    ];

    if (paper.headerFields.isNotEmpty) {
      rows.add([]);
      rows.add(['Header Field', 'Value']);
      for (final field in paper.headerFields) {
        rows.add([
          field.label,
          field.isPlaceholder ? '________________' : field.value,
        ]);
      }
    }

    return rows;
  }

  static List<List<Object?>> _questionRows(Paper paper) {
    final rows = <List<Object?>>[
      [
        'Section',
        'Number',
        'Type',
        'Question',
        'Marks',
        'Optional',
        'Required Count Note',
      ],
    ];

    for (final section in paper.sections) {
      final note = section.requiredCount == null
          ? ''
          : 'Answer any ${section.requiredCount}';
      for (final entry in section.questions.asMap().entries) {
        final question = entry.value;
        final questionNumber = QuestionNumberingService.paperLabel(
          entry.key + 1,
          paper,
        );
        rows.add([
          _sectionLabel(section),
          questionNumber,
          _questionType(question.type),
          OfficeTextFormatter.questionText(question.text),
          question.marks,
          question.isOptional ? 'Yes' : 'No',
          note,
        ]);
      }
    }

    return rows;
  }

  static List<List<Object?>> _optionRows(Paper paper) {
    final rows = <List<Object?>>[
      ['Question Number', 'Option', 'Text', 'Correct'],
    ];

    for (final section in paper.sections) {
      for (final questionEntry in section.questions.asMap().entries) {
        final questionNumber = QuestionNumberingService.paperLabel(
          questionEntry.key + 1,
          paper,
        );
        for (final optionEntry in questionEntry.value.options.asMap().entries) {
          rows.add([
            '${_sectionLabel(section)} Q$questionNumber',
            String.fromCharCode(65 + optionEntry.key),
            optionEntry.value.text,
            optionEntry.value.isCorrect ? 'Yes' : 'No',
          ]);
        }
      }
    }

    return rows;
  }

  static String _sheetXml(List<List<Object?>> rows) {
    final rowXml = rows.asMap().entries.map((entry) {
      final rowIndex = entry.key + 1;
      final cells = entry.value.asMap().entries.map((cellEntry) {
        final ref = '${_columnName(cellEntry.key)}$rowIndex';
        return _cell(ref, cellEntry.value, style: rowIndex == 1 ? 1 : 0);
      }).join();
      return '<row r="$rowIndex">$cells</row>';
    }).join();

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetViews><sheetView workbookViewId="0"/></sheetViews>'
        '<cols><col min="1" max="1" width="22" customWidth="1"/>'
        '<col min="2" max="8" width="32" customWidth="1"/></cols>'
        '<sheetData>$rowXml</sheetData>'
        '</worksheet>';
  }

  static String _cell(String ref, Object? value, {int style = 0}) {
    final styleAttr = style > 0 ? ' s="$style"' : '';
    if (value is num) {
      return '<c r="$ref"$styleAttr><v>$value</v></c>';
    }

    final text = OfficeTextFormatter.xml(value?.toString() ?? '');
    return '<c r="$ref" t="inlineStr"$styleAttr><is><t xml:space="preserve">$text</t></is></c>';
  }

  static String _workbookXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets>'
        '<sheet name="Summary" sheetId="1" r:id="rId1"/>'
        '<sheet name="Questions" sheetId="2" r:id="rId2"/>'
        '<sheet name="Options" sheetId="3" r:id="rId3"/>'
        '</sheets></workbook>';
  }

  static String _workbookRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>'
        '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/>'
        '<Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>';
  }

  static String _stylesXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
        '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
        '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>'
        '</styleSheet>';
  }

  static String _contentTypesXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
        '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
        '</Types>';
  }

  static String _rootRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
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

  static String _appXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
        'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
        '<Application>EduSheet</Application></Properties>';
  }

  static String _sectionLabel(PaperSection section) {
    final label = '${section.prefix} ${section.title}'.trim();
    return label.isEmpty ? 'Section' : label;
  }

  static String _questionType(QuestionType type) {
    switch (type) {
      case QuestionType.mcq:
        return 'MCQ';
      case QuestionType.fillInTheBlanks:
        return 'Fill in the blanks';
      case QuestionType.descriptive:
        return 'Descriptive';
    }
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
