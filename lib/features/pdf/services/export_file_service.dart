import 'dart:io';

import 'package:edusheet/features/pdf/services/office_text_formatter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ExportFileService {
  static const folderName = 'EduSheet';
  static final RegExp invalidFileNameCharacters = RegExp(
    r'[<>:"/\\|?*\x00-\x1F]',
  );

  static bool hasInvalidFileNameCharacters(String value) {
    return invalidFileNameCharacters.hasMatch(value);
  }

  static String cleanFileNameBase(
    String value, {
    String fallback = 'Question Paper',
  }) {
    return OfficeTextFormatter.safeFileName(value, fallback).trim();
  }

  static Future<Directory> eduSheetDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(directory.path, folderName));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }

  static Future<File> uniqueFile({
    required String fileNameBase,
    required String extension,
    String fallback = 'Question Paper',
  }) async {
    final directory = await eduSheetDirectory();
    final cleanBase = cleanFileNameBase(fileNameBase, fallback: fallback);
    final normalizedExtension = extension.startsWith('.')
        ? extension
        : '.$extension';

    var index = 0;
    while (true) {
      final suffix = index == 0 ? '' : ' ($index)';
      final candidate = File(
        p.join(directory.path, '$cleanBase$suffix$normalizedExtension'),
      );
      if (!await candidate.exists()) return candidate;
      index++;
    }
  }
}
