import 'dart:io';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/application/paper_template_resolver.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/services/pdf_service.dart';
import 'package:edusheet/features/pdf/services/word_export_service.dart';

/// Teacher-facing export formats for question papers.
///
/// PDF is the print-ready copy and Word is the editable copy. Other document
/// services may still exist for unrelated tools, but they are not part of the
/// normal Create Paper export surface.
enum QuestionPaperExportFormat { pdf, word }

class QuestionPaperExportPolicy {
  const QuestionPaperExportPolicy._();

  static const Set<QuestionPaperExportFormat> supportedFormats = {
    QuestionPaperExportFormat.pdf,
    QuestionPaperExportFormat.word,
  };

  static bool supports(QuestionPaperExportFormat format) =>
      supportedFormats.contains(format);
}

class QuestionPaperExportService {
  const QuestionPaperExportService._();

  static Future<File> exportPdf({
    required Paper paper,
    required Iterable<PaperTemplate> availableTemplates,
  }) async {
    final template = PaperTemplateResolver.resolve(
      paper.templateId,
      availableTemplates,
    );
    return PdfService.export(paper, template);
  }

  static Future<File> exportWord({
    required Paper paper,
    required Iterable<PaperTemplate> availableTemplates,
    bool openAfterExport = false,
  }) async {
    final template = PaperTemplateResolver.resolve(
      paper.templateId,
      availableTemplates,
    );

    if (openAfterExport) {
      return WordExportService.exportAndOpen(paper, template);
    }
    return WordExportService.export(paper, template);
  }
}
