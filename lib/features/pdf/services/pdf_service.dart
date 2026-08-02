import 'dart:io';

import 'package:printing/printing.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/domain/models/paper_export_config.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/services/export_file_service.dart';
import 'package:edusheet/features/pdf/services/export_task.dart';
import 'package:edusheet/features/pdf/services/question_paper_service.dart';

class PdfService {
  static Future<void> generateAndPreview(
    Paper paper,
    PaperTemplate template, {
    PaperExportConfig config = const PaperExportConfig(),
  }) async {
    final pdf = await QuestionPaperService.generateDocument(
      paper,
      template,
      config: config,
    );
    final bytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<File> export(
    Paper paper,
    PaperTemplate template, {
    String? fileNameBase,
    PaperExportConfig config = const PaperExportConfig(),
    ExportCancellationToken? cancellationToken,
    ExportProgressCallback? onProgress,
  }) async {
    void report(ExportStage stage, double fraction, String message) {
      onProgress?.call(
        ExportProgress(stage: stage, fraction: fraction, message: message),
      );
    }

    report(ExportStage.preparing, 0.05, 'Preparing paper');
    cancellationToken?.throwIfCancelled();
    report(ExportStage.rendering, 0.2, 'Rendering PDF');
    final pdf = await QuestionPaperService.generateDocument(
      paper,
      template,
      config: config,
    );
    cancellationToken?.throwIfCancelled();
    report(ExportStage.serializing, 0.7, 'Finalizing pages');
    final bytes = await pdf.save();
    cancellationToken?.throwIfCancelled();
    final file = await ExportFileService.uniqueFile(
      fileNameBase: fileNameBase ?? paper.title,
      extension: '.pdf',
    );
    report(ExportStage.writing, 0.9, 'Writing file');
    await file.writeAsBytes(bytes, flush: true);
    report(ExportStage.complete, 1, 'Export complete');
    return file;
  }
}
