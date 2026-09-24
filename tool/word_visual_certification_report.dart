import 'dart:convert';
import 'dart:io';

import 'package:edusheet/features/document_reader/domain/services/word_visual_certification_snapshot.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/word_visual_certification_report.dart <file.docx> [more.docx ...]',
    );
    exitCode = 64;
    return;
  }

  final reports = <Map<String, Object>>[];
  for (final path in args) {
    final file = File(path);
    if (!await file.exists()) {
      stderr.writeln('DOCX not found: $path');
      exitCode = 66;
      return;
    }
    try {
      final document = await DocxConversionParser.parse(file);
      final snapshot = WordVisualCertificationSnapshot.fromDocument(document);
      reports.add(<String, Object>{
        'path': file.path,
        ...snapshot.toJson(),
      });
    } catch (error) {
      stderr.writeln('Failed to certify $path: $error');
      exitCode = 65;
      return;
    }
  }

  const encoder = JsonEncoder.withIndent('  ');
  stdout.writeln(encoder.convert(<String, Object>{'documents': reports}));
}
