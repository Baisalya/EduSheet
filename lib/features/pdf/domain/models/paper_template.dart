import 'package:pdf/pdf.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';

enum TemplateType { school, coaching, cute, board }

enum HeaderLayout {
  centered,
  logoLeft,
  logoRight,
  modernCoaching,
  minimal,
  custom,
}

enum PaperLayout {
  standard,
  twoColumn,
}

enum PaperSize {
  a4,
  a5,
  a3,
  letter,
  legal,
}

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
  final HeaderLayout headerLayout;
  final PaperLayout paperLayout;
  final PaperSize paperSize;
  final CustomLayout? customLayout;

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
    this.headerLayout = HeaderLayout.centered,
    this.paperLayout = PaperLayout.standard,
    this.paperSize = PaperSize.a4,
    this.customLayout,
  });

  PaperTemplate copyWith({
    String? id,
    String? name,
    TemplateType? type,
    PdfColor? primaryColor,
    PdfColor? secondaryColor,
    double? headerFontSize,
    double? questionFontSize,
    bool? hasBorder,
    bool? centeredHeader,
    HeaderLayout? headerLayout,
    PaperLayout? paperLayout,
    PaperSize? paperSize,
    CustomLayout? customLayout,
  }) {
    return PaperTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      headerFontSize: headerFontSize ?? this.headerFontSize,
      questionFontSize: questionFontSize ?? this.questionFontSize,
      hasBorder: hasBorder ?? this.hasBorder,
      centeredHeader: centeredHeader ?? this.centeredHeader,
      headerLayout: headerLayout ?? this.headerLayout,
      paperLayout: paperLayout ?? this.paperLayout,
      paperSize: paperSize ?? this.paperSize,
      customLayout: customLayout ?? this.customLayout,
    );
  }

  static List<PaperTemplate> get predefinedTemplates => [
        PaperTemplate(
          id: 'school_formal',
          name: 'School Formal',
          type: TemplateType.school,
          hasBorder: true,
          centeredHeader: true,
          headerLayout: HeaderLayout.centered,
        ),
        PaperTemplate(
          id: 'coaching_modern',
          name: 'Coaching Pro',
          type: TemplateType.coaching,
          primaryColor: PdfColors.blue900,
          secondaryColor: PdfColors.blue100,
          centeredHeader: false,
          headerLayout: HeaderLayout.modernCoaching,
        ),
        PaperTemplate(
          id: 'cute_kids',
          name: 'Cute Kids',
          type: TemplateType.cute,
          primaryColor: PdfColors.pink300,
          secondaryColor: PdfColors.yellow100,
          headerFontSize: 26,
          headerLayout: HeaderLayout.centered,
        ),
        PaperTemplate(
          id: 'board_cbse',
          name: 'Board (CBSE Style)',
          type: TemplateType.board,
          centeredHeader: true,
          headerLayout: HeaderLayout.centered,
        ),
        PaperTemplate(
          id: 'minimalist',
          name: 'Minimalist',
          type: TemplateType.school,
          headerLayout: HeaderLayout.minimal,
          hasBorder: false,
        ),
      ];
}
