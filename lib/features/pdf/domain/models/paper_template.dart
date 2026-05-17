import 'package:pdf/pdf.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:uuid/uuid.dart';

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

  CustomLayout get effectiveLayout {
    if (headerLayout == HeaderLayout.custom && customLayout != null) {
      return customLayout!;
    }

    final elements = <TemplateElement>[];
    const uuid = Uuid();
    const double a4Width = 595.27;
    const double contentWidth = a4Width - 64;

    switch (headerLayout) {
      case HeaderLayout.centered:
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.logo,
          x: (contentWidth - 50) / 2,
          y: 0,
          width: 50,
          height: 50,
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.schoolName,
          x: 0,
          y: 58,
          width: contentWidth,
          properties: {'fontSize': 18.0, 'bold': true, 'alignment': 'center'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.paperTitle,
          x: 0,
          y: 80,
          width: contentWidth,
          properties: {'fontSize': headerFontSize, 'bold': true, 'alignment': 'center'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.headerFieldsBlock,
          x: 0,
          y: 110,
          width: contentWidth,
          properties: {'fontSize': 12.0, 'alignment': 'center'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.maxMarks,
          x: 0,
          y: 150,
          width: contentWidth,
          properties: {'fontSize': 12.0, 'bold': true, 'alignment': 'right'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.horizontalLine,
          x: 0,
          y: 175,
          width: contentWidth,
          properties: {'color': 0xFF000000},
        ));
        return CustomLayout(elements: elements, canvasHeight: 180);

      case HeaderLayout.logoLeft:
      case HeaderLayout.logoRight:
        final isLeft = headerLayout == HeaderLayout.logoLeft;
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.logo,
          x: isLeft ? 0 : contentWidth - 60,
          y: 0,
          width: 60,
          height: 60,
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.schoolName,
          x: isLeft ? 76 : 0,
          y: 5,
          width: contentWidth - 76,
          properties: {'fontSize': 18.0, 'bold': true, 'alignment': isLeft ? 'left' : 'right'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.paperTitle,
          x: isLeft ? 76 : 0,
          y: 28,
          width: contentWidth - 76,
          properties: {'fontSize': headerFontSize, 'bold': true, 'alignment': isLeft ? 'left' : 'right'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.maxMarks,
          x: 0,
          y: 70,
          width: contentWidth,
          properties: {'fontSize': 12.0, 'bold': true, 'alignment': isLeft ? 'right' : 'left'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.headerFieldsBlock,
          x: 0,
          y: 95,
          width: contentWidth,
          properties: {'fontSize': 11.0, 'alignment': 'left'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.horizontalLine,
          x: 0,
          y: 135,
          width: contentWidth,
          properties: {'color': 0xFF000000},
        ));
        return CustomLayout(elements: elements, canvasHeight: 140);

      case HeaderLayout.modernCoaching:
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.logo,
          x: 10,
          y: 10,
          width: 60,
          height: 60,
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.schoolName,
          x: 90,
          y: 15,
          width: contentWidth - 200,
          properties: {
            'fontSize': 20.0,
            'bold': true,
            'alignment': 'left',
            'color': primaryColor.toInt(),
          },
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.paperTitle,
          x: 90,
          y: 42,
          width: contentWidth - 200,
          properties: {'fontSize': 16.0, 'alignment': 'left'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.maxMarks,
          x: contentWidth - 110,
          y: 30,
          width: 100,
          properties: {'fontSize': 12.0, 'bold': true, 'alignment': 'right'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.headerFieldsBlock,
          x: 10,
          y: 85,
          width: contentWidth - 20,
          properties: {'fontSize': 11.0, 'alignment': 'left'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.horizontalLine,
          x: 0,
          y: 125,
          width: contentWidth,
          properties: {'color': primaryColor.toInt()},
        ));
        return CustomLayout(elements: elements, canvasHeight: 130);

      case HeaderLayout.minimal:
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.schoolName,
          x: 0,
          y: 0,
          width: contentWidth / 2,
          properties: {'fontSize': 10.0, 'bold': true, 'alignment': 'left', 'color': 0xFF9E9E9E},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.maxMarks,
          x: contentWidth / 2,
          y: 0,
          width: contentWidth / 2,
          properties: {'fontSize': 10.0, 'bold': true, 'alignment': 'right'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.paperTitle,
          x: 0,
          y: 15,
          width: contentWidth,
          properties: {'fontSize': 14.0, 'bold': true, 'alignment': 'left'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.headerFieldsBlock,
          x: 0,
          y: 40,
          width: contentWidth,
          properties: {'fontSize': 11.0, 'alignment': 'left'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.horizontalLine,
          x: 0,
          y: 75,
          width: contentWidth,
          properties: {'color': 0xFF000000},
        ));
        return CustomLayout(elements: elements, canvasHeight: 80);

      default:
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.schoolName,
          x: 0,
          y: 20,
          width: contentWidth,
          properties: {'fontSize': 20.0, 'bold': true, 'alignment': 'center'},
        ));
        return CustomLayout(elements: elements, canvasHeight: 100);
    }
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
