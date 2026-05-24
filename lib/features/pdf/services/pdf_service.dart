import 'dart:io';

import 'package:printing/printing.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/services/export_file_service.dart';
import 'package:edusheet/features/pdf/services/question_paper_service.dart';

class PdfService {
  static Future<void> generateAndPreview(
    Paper paper,
    PaperTemplate template,
  ) async {
    final pdf = await QuestionPaperService.generateDocument(paper, template);
    final bytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<File> export(
    Paper paper,
    PaperTemplate template, {
    String? fileNameBase,
  }) async {
    final pdf = await QuestionPaperService.generateDocument(paper, template);
    final file = await ExportFileService.uniqueFile(
      fileNameBase: fileNameBase ?? paper.title,
      extension: '.pdf',
    );
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }
}
