import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/domain/models/paper_export_config.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/services/export_file_service.dart';
import 'package:edusheet/features/pdf/services/export_task.dart';
import 'package:edusheet/features/pdf/services/question_paper_service.dart';
import 'package:edusheet/features/printing/domain/print_document_source.dart';
import 'package:edusheet/features/printing/services/global_print_service.dart';

class PdfService {
  static PdfPageFormat resolvePageFormat(
    Paper paper,
    PaperTemplate template, {
    PaperExportConfig? config,
  }) {
    return QuestionPaperService.resolvePageFormat(
      paper,
      template,
      config: config,
    );
  }

  static Future<Uint8List> generateBytes(
    Paper paper,
    PaperTemplate template, {
    PaperExportConfig? config,
  }) async {
    final pdf = await QuestionPaperService.generateDocument(
      paper,
      template,
      config: config,
    );
    return Uint8List.fromList(await pdf.save());
  }

  static Future<void> generateAndPreview(
    Paper paper,
    PaperTemplate template, {
    PaperExportConfig? config,
  }) async {
    final source = PrintDocumentSource.fixed(
      title: paper.title,
      description: 'EduSheet question paper',
      initialPageFormat: resolvePageFormat(paper, template, config: config),
      load: () => generateBytes(paper, template, config: config),
    );
    await const GlobalPrintService().openSystemPrintDialog(source);
  }

  static Future<File> export(
    Paper paper,
    PaperTemplate template, {
    String? fileNameBase,
    PaperExportConfig? config,
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
