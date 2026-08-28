import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/document_reader/data/services/spreadsheet_parser_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'CSV parser supports quoted commas and multiline quoted fields',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'edusheet-csv-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}sample.csv');
      await file.writeAsString(
        'Name,Note\r\n"Teacher, A","Line one\nLine two"\r\nMath,Ready',
      );

      final workbook = await SpreadsheetParserService().load(file, '.csv');
      final sheet = workbook.sheets.single;

      expect(sheet.rows.length, 3);
      expect(sheet.rows[1].valueAt(0), 'Teacher, A');
      expect(sheet.rows[1].valueAt(1), 'Line one\nLine two');
      expect(sheet.rows[2].valueAt(0), 'Math');
    },
  );

  test(
    'XLSX parser preserves sheets, sparse row numbers and cell values',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'edusheet-xlsx-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}sample.xlsx',
      );

      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            'xl/workbook.xml',
            '''<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
 <sheets><sheet name="Marks" sheetId="1" r:id="rId1"/></sheets>
</workbook>''',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'xl/_rels/workbook.xml.rels',
            '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Target="worksheets/sheet1.xml"/>
</Relationships>''',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'xl/sharedStrings.xml',
            '''<?xml version="1.0" encoding="UTF-8"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
 <si><t>Student</t></si>
</sst>''',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'xl/worksheets/sheet1.xml',
            '''<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
 <sheetData>
  <row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="inlineStr"><is><t>Score</t></is></c></row>
  <row r="3"><c r="A3" t="inlineStr"><is><t>Asha</t></is></c><c r="B3"><v>98</v></c></row>
 </sheetData>
</worksheet>''',
          ),
        );
      await file.writeAsBytes(ZipEncoder().encode(archive));

      final workbook = await SpreadsheetParserService().load(file, '.xlsx');
      final sheet = workbook.sheets.single;

      expect(sheet.name, 'Marks');
      expect(sheet.rows.length, 2);
      expect(sheet.rows[1].rowIndex, 3);
      expect(sheet.rows[0].valueAt(0), 'Student');
      expect(sheet.rows[1].valueAt(1), '98');
      expect(sheet.columnCount, 2);
    },
  );
}
