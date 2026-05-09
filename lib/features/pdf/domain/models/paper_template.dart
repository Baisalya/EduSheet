import 'package:pdf/pdf.dart';

enum TemplateType { school, coaching, cute, board }

class PaperTemplate {
  final String id;
  final String name;
  final TemplateType type;
  final PdfColor primaryColor;
  final PdfColor secondaryColor;
  final double headerFontSize;
  final double questionFontSize;
  final bool hasBorder;
  final bool centeredHeader;

  PaperTemplate({
    required this.id,
    required this.name,
    required this.type,
    this.primaryColor = PdfColors.black,
    this.secondaryColor = PdfColors.grey700,
    this.headerFontSize = 22,
    this.questionFontSize = 12,
    this.hasBorder = false,
    this.centeredHeader = true,
  });

  static List<PaperTemplate> get predefinedTemplates => [
        PaperTemplate(
          id: 'school_formal',
          name: 'School Formal',
          type: TemplateType.school,
          hasBorder: true,
          centeredHeader: true,
        ),
        PaperTemplate(
          id: 'coaching_modern',
          name: 'Coaching Pro',
          type: TemplateType.coaching,
          primaryColor: PdfColors.blue900,
          secondaryColor: PdfColors.blue100,
          centeredHeader: false,
        ),
        PaperTemplate(
          id: 'cute_kids',
          name: 'Cute Kids',
          type: TemplateType.cute,
          primaryColor: PdfColors.pink300,
          secondaryColor: PdfColors.yellow100,
          headerFontSize: 26,
        ),
        PaperTemplate(
          id: 'board_cbse',
          name: 'Board (CBSE Style)',
          type: TemplateType.board,
          centeredHeader: true,
        ),
      ];
}
