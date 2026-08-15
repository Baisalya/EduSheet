import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart' as xml;

import '../../domain/models/spreadsheet_model.dart';
import 'document_file_read_service.dart';

class SpreadsheetParserService {
  static const int maxRowsPerSheet = 50000;
  static const int maxColumns = 512;
  static const int maxCellsPerWorkbook = 1000000;

  Future<SpreadsheetWorkbook> load(File file, String extension) async {
    final bytes = await DocumentFileReadService.readAllBytes(file);
    final payload = await compute(_parseSpreadsheetPayload, <String, Object>{
      'extension': extension.toLowerCase(),
      'bytes': bytes,
    });
    return _workbookFromPayload(payload);
  }

  SpreadsheetWorkbook _workbookFromPayload(Map<String, Object?> payload) {
    final rawSheets = payload['sheets'];
    final sheets = <SpreadsheetSheet>[];
    if (rawSheets is List) {
      for (final rawSheet in rawSheets) {
        if (rawSheet is! Map) continue;
        final rows = <SpreadsheetRow>[];
        final rawRows = rawSheet['rows'];
        if (rawRows is List) {
          for (final rawRow in rawRows) {
            if (rawRow is! Map) continue;
            final cells = <int, String>{};
            final rawCells = rawRow['cells'];
            if (rawCells is Map) {
              for (final entry in rawCells.entries) {
                final index = entry.key is int
                    ? entry.key as int
                    : int.tryParse(entry.key.toString());
                if (index != null) cells[index] = entry.value?.toString() ?? '';
              }
            }
            rows.add(
              SpreadsheetRow(
                rowIndex: (rawRow['rowIndex'] as num?)?.toInt() ?? rows.length + 1,
                cells: cells,
              ),
            );
          }
        }
        sheets.add(
          SpreadsheetSheet(
            name: rawSheet['name']?.toString() ?? 'Sheet',
            rows: rows,
            columnCount: (rawSheet['columnCount'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }

    return SpreadsheetWorkbook(
      sheets: sheets,
      truncated: payload['truncated'] == true,
    );
  }
}

Map<String, Object?> _parseSpreadsheetPayload(Map<String, Object> input) {
  final extension = input['extension']?.toString().toLowerCase() ?? '';
  final rawBytes = input['bytes'];
  final bytes = rawBytes is Uint8List
      ? rawBytes
      : Uint8List.fromList((rawBytes as List).cast<int>());

  if (extension == '.csv') return _parseCsv(bytes);
  if (extension == '.xlsx') return _parseXlsx(bytes);
  throw const FormatException('Unsupported spreadsheet format.');
}

Map<String, Object?> _parseCsv(Uint8List bytes) {
  final text = utf8.decode(bytes, allowMalformed: true);
  final rows = <Map<String, Object?>>[];
  final currentRow = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  var rowIndex = 1;
  var columnCount = 0;
  var totalCells = 0;
  var truncated = false;

  void addCell() {
    if (currentRow.length >= SpreadsheetParserService.maxColumns) {
      truncated = true;
      buffer.clear();
      return;
    }
    currentRow.add(buffer.toString());
    buffer.clear();
  }

  void addRow() {
    if (rows.length >= SpreadsheetParserService.maxRowsPerSheet ||
        totalCells >= SpreadsheetParserService.maxCellsPerWorkbook) {
      truncated = true;
      currentRow.clear();
      return;
    }
    if (currentRow.any((cell) => cell.trim().isNotEmpty)) {
      final cells = <int, String>{};
      for (var index = 0; index < currentRow.length; index++) {
        final value = currentRow[index];
        if (value.isNotEmpty) cells[index] = value;
      }
      rows.add(<String, Object?>{'rowIndex': rowIndex, 'cells': cells});
      totalCells += currentRow.length;
      if (currentRow.length > columnCount) columnCount = currentRow.length;
    }
    rowIndex++;
    currentRow.clear();
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '"') {
      if (inQuotes && i + 1 < text.length && text[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (char == ',' && !inQuotes) {
      addCell();
      continue;
    }

    if ((char == '\n' || char == '\r') && !inQuotes) {
      if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      addCell();
      addRow();
      if (truncated) break;
      continue;
    }

    buffer.write(char);
  }

  if (!truncated && (buffer.isNotEmpty || currentRow.isNotEmpty)) {
    addCell();
    addRow();
  }

  return <String, Object?>{
    'sheets': <Object>[
      <String, Object?>{
        'name': 'CSV',
        'rows': rows,
        'columnCount': columnCount,
      },
    ],
    'truncated': truncated,
  };
}

Map<String, Object?> _parseXlsx(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final files = <String, ArchiveFile>{
    for (final entry in archive.files) p.posix.normalize(entry.name): entry,
  };
  final sharedStrings = _readSharedStrings(files);
  final sheetRefs = _readSheetRefs(files);
  final sheets = <Object>[];
  var totalCells = 0;
  var truncated = false;

  for (final sheetRef in sheetRefs) {
    if (totalCells >= SpreadsheetParserService.maxCellsPerWorkbook) {
      truncated = true;
      break;
    }
    final entry = files[sheetRef.path];
    if (entry == null) continue;

    final parsed = xml.XmlDocument.parse(utf8.decode(_entryBytes(entry)));
    final rows = <Object>[];
    var maxColumn = 0;

    for (final row in parsed.descendants.whereType<xml.XmlElement>().where(
      (element) => element.name.local == 'row',
    )) {
      if (rows.length >= SpreadsheetParserService.maxRowsPerSheet ||
          totalCells >= SpreadsheetParserService.maxCellsPerWorkbook) {
        truncated = true;
        break;
      }

      final rowNumber = int.tryParse(row.getAttribute('r') ?? '') ?? rows.length + 1;
      final cells = <int, String>{};
      for (final cell in row.childElements.where(
        (element) => element.name.local == 'c',
      )) {
        final index = _columnIndex(cell.getAttribute('r'));
        if (index < 0 || index >= SpreadsheetParserService.maxColumns) {
          truncated = true;
          continue;
        }
        final value = _cellValue(cell, sharedStrings);
        if (value.isNotEmpty) cells[index] = value;
        if (index + 1 > maxColumn) maxColumn = index + 1;
        totalCells++;
        if (totalCells >= SpreadsheetParserService.maxCellsPerWorkbook) {
          truncated = true;
          break;
        }
      }

      if (cells.isNotEmpty) {
        rows.add(<String, Object?>{'rowIndex': rowNumber, 'cells': cells});
      }
    }

    sheets.add(<String, Object?>{
      'name': sheetRef.name,
      'rows': rows,
      'columnCount': maxColumn,
    });
  }

  return <String, Object?>{'sheets': sheets, 'truncated': truncated};
}

List<String> _readSharedStrings(Map<String, ArchiveFile> files) {
  final entry = files['xl/sharedStrings.xml'];
  if (entry == null) return const [];

  final parsed = xml.XmlDocument.parse(utf8.decode(_entryBytes(entry)));
  return parsed.descendants
      .whereType<xml.XmlElement>()
      .where((element) => element.name.local == 'si')
      .map(
        (element) => element.descendants
            .whereType<xml.XmlElement>()
            .where((child) => child.name.local == 't')
            .map((child) => child.innerText)
            .join(),
      )
      .toList();
}

List<_SheetRef> _readSheetRefs(Map<String, ArchiveFile> files) {
  final workbook = files['xl/workbook.xml'];
  final rels = files['xl/_rels/workbook.xml.rels'];
  if (workbook == null || rels == null) return const [];

  final relTargets = <String, String>{};
  final relXml = xml.XmlDocument.parse(utf8.decode(_entryBytes(rels)));
  for (final rel in relXml.descendants.whereType<xml.XmlElement>()) {
    if (rel.name.local != 'Relationship') continue;
    final id = rel.getAttribute('Id');
    final target = rel.getAttribute('Target');
    if (id != null && target != null) {
      relTargets[id] = _normalizeWorkbookTarget(target);
    }
  }

  final workbookXml = xml.XmlDocument.parse(utf8.decode(_entryBytes(workbook)));
  final result = <_SheetRef>[];
  for (final sheet in workbookXml.descendants.whereType<xml.XmlElement>().where(
    (element) => element.name.local == 'sheet',
  )) {
    String? relId;
    for (final attribute in sheet.attributes) {
      if (attribute.name.local == 'id') {
        relId = attribute.value;
        break;
      }
    }
    final target = relTargets[relId];
    if (target == null || target.isEmpty) continue;
    result.add(_SheetRef(sheet.getAttribute('name') ?? 'Sheet', target));
  }
  return result;
}

String _normalizeWorkbookTarget(String target) {
  final normalized = p.posix.normalize(target.replaceAll('\\', '/'));
  if (normalized.startsWith('/')) return normalized.substring(1);
  if (normalized.startsWith('xl/')) return normalized;
  return p.posix.normalize(p.posix.join('xl', normalized));
}

int _columnIndex(String? cellRef) {
  final letters = RegExp(r'^[A-Za-z]+').stringMatch(cellRef ?? '');
  if (letters == null || letters.isEmpty) return -1;
  var index = 0;
  for (final codeUnit in letters.toUpperCase().codeUnits) {
    index = (index * 26) + (codeUnit - 64);
  }
  return index - 1;
}

String _cellValue(xml.XmlElement cell, List<String> sharedStrings) {
  final type = cell.getAttribute('t');
  if (type == 'inlineStr') {
    return cell.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 't')
        .map((element) => element.innerText)
        .join();
  }

  final raw = _firstChildText(cell, 'v');
  if (raw == null) {
    if (type == 'str') return _firstChildText(cell, 'f') ?? '';
    return '';
  }

  if (type == 's') {
    final index = int.tryParse(raw);
    if (index != null && index >= 0 && index < sharedStrings.length) {
      return sharedStrings[index];
    }
  }
  if (type == 'b') return raw == '1' ? 'TRUE' : 'FALSE';
  return raw;
}

String? _firstChildText(xml.XmlElement element, String localName) {
  for (final child in element.childElements) {
    if (child.name.local == localName) return child.innerText;
  }
  return null;
}

Uint8List _entryBytes(ArchiveFile entry) => entry.content;

class _SheetRef {
  final String name;
  final String path;

  const _SheetRef(this.name, this.path);
}
