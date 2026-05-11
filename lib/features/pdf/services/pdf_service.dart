import 'package:printing/printing.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/services/question_paper_service.dart';

class PdfService {
  static Future<void> generateAndPreview(Paper paper) async {
    final template = PaperTemplate.predefinedTemplates.firstWhere(
      (t) => t.id == paper.templateId,
      orElse: () => PaperTemplate.predefinedTemplates.first,
    );

    final pdf = await QuestionPaperService.generateDocument(paper, template);

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
