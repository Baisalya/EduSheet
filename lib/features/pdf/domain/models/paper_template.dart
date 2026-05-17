import 'package:pdf/pdf.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:uuid/uuid.dart';

enum TemplateType { school, college, coaching, kids, board }

enum HeaderLayout {
  centered,
  logoLeft,
  logoRight,
  modernCoaching,
  minimal,
  academic,
  ssvm,
  dps,
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

      case HeaderLayout.academic:
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.logo,
          x: (contentWidth - 60) / 2,
          y: 0,
          width: 60,
          height: 60,
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.schoolName,
          x: 0,
          y: 62,
          width: contentWidth,
          properties: {
            'fontSize': 24.0,
            'bold': true,
            'alignment': 'center',
            'color': primaryColor.toInt(),
          },
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.staticText,
          x: 0,
          y: 88,
          width: contentWidth,
          content: 'AD MAJOREM DEI GLORIAM',
          properties: {
            'fontSize': 8.0,
            'bold': true,
            'alignment': 'center',
            'color': 0xFF757575,
          },
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.paperTitle,
          x: 0,
          y: 102,
          width: contentWidth,
          properties: {'fontSize': 16.0, 'bold': true, 'alignment': 'center'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.headerFieldsBlock,
          x: 0,
          y: 130,
          width: contentWidth,
          properties: {
            'fontSize': 11.0,
            'alignment': 'left',
            'fieldLabels': ['Name', 'Roll No', 'Sec']
          },
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.headerFieldsBlock,
          x: 0,
          y: 155,
          width: contentWidth * 0.7,
          properties: {
            'fontSize': 11.0,
            'alignment': 'left',
            'fieldLabels': ['Subject', 'Class', 'Date']
          },
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.maxMarks,
          x: contentWidth - 150,
          y: 155,
          width: 150,
          properties: {'fontSize': 11.0, 'bold': true, 'alignment': 'right'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.horizontalLine,
          x: 0,
          y: 185,
          width: contentWidth,
          properties: {'color': 0xFF000000},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.horizontalLine,
          x: 0,
          y: 188,
          width: contentWidth,
          properties: {'color': 0xFF000000},
        ));
        return CustomLayout(elements: elements, canvasHeight: 195);

      case HeaderLayout.ssvm:
        // Top text "SIX - ENGLISH" (Left & Right - mocked for now as Series/Subject)
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.staticText,
          x: 0,
          y: 0,
          width: contentWidth / 2,
          content: 'SIX- ENGLISH',
          properties: {'fontSize': 9.0, 'bold': true, 'alignment': 'left'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.staticText,
          x: contentWidth / 2,
          y: 0,
          width: contentWidth / 2,
          content: 'SIX- ENGLISH',
          properties: {'fontSize': 9.0, 'bold': true, 'alignment': 'right'},
        ));

        // Logo on the left
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.logo,
          x: 0,
          y: 15,
          width: 70,
          height: 70,
        ));

        // School Name centered
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.schoolName,
          x: 80,
          y: 20,
          width: contentWidth - 80,
          properties: {
            'fontSize': 20.0,
            'bold': true,
            'alignment': 'center',
            'color': 0xFF000000,
          },
        ));

        // Annual Examination Box (mocked with static text and potentially a border if supported)
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.paperTitle,
          x: 80,
          y: 45,
          width: contentWidth - 80,
          properties: {
            'fontSize': 14.0,
            'bold': true,
            'alignment': 'center',
          },
        ));

        // Fields Row 1
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.headerFieldsBlock,
          x: 80,
          y: 70,
          width: contentWidth - 80,
          properties: {
            'fontSize': 11.0,
            'alignment': 'left',
            'fieldLabels': ['Class', 'Subject']
          },
        ));

        // Fields Row 2
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.headerFieldsBlock,
          x: 80,
          y: 90,
          width: contentWidth - 80,
          properties: {
            'fontSize': 11.0,
            'alignment': 'left',
            'fieldLabels': ['Time', 'Full Marks']
          },
        ));

        // Instructions line
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.staticText,
          x: 0,
          y: 115,
          width: contentWidth,
          content: 'All questions are compulsory. Figures in the margin indicate full marks.',
          properties: {
            'fontSize': 10.0,
            'bold': true,
            'alignment': 'center',
            'italic': true
          },
        ));

        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.horizontalLine,
          x: 0,
          y: 135,
          width: contentWidth,
          properties: {'color': 0xFF000000},
        ));

        return CustomLayout(elements: elements, canvasHeight: 145);

      case HeaderLayout.dps:
        // Series & Code
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.staticText,
          x: 0,
          y: 0,
          width: contentWidth / 2,
          content: 'Series : DPS/ST/SS-SA2/10-11',
          properties: {'fontSize': 10.0, 'alignment': 'left'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.staticText,
          x: contentWidth / 2,
          y: 0,
          width: contentWidth / 2,
          content: 'Code : 087',
          properties: {'fontSize': 10.0, 'alignment': 'right'},
        ));

        // Centered Logo
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.logo,
          x: (contentWidth - 50) / 2,
          y: 15,
          width: 50,
          height: 50,
        ));

        // School Name
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.schoolName,
          x: 0,
          y: 70,
          width: contentWidth,
          properties: {'fontSize': 16.0, 'bold': true, 'alignment': 'center'},
        ));

        // Exam Title
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.paperTitle,
          x: 0,
          y: 90,
          width: contentWidth,
          properties: {'fontSize': 14.0, 'bold': true, 'alignment': 'center'},
        ));

        // Subject (as static text or from paper title if needed)
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.staticText,
          x: 0,
          y: 110,
          width: contentWidth,
          content: 'SOCIAL SCIENCE',
          properties: {'fontSize': 12.0, 'bold': true, 'alignment': 'center'},
        ));

        // Roll No & Class
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.headerFieldsBlock,
          x: 0,
          y: 135,
          width: contentWidth,
          properties: {
            'fontSize': 11.0,
            'alignment': 'left',
            'fieldLabels': ['Roll No', 'Class']
          },
        ));

        // Marks & Time
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.headerFieldsBlock,
          x: 0,
          y: 160,
          width: contentWidth,
          properties: {
            'fontSize': 11.0,
            'alignment': 'left',
            'fieldLabels': ['Marks', 'Time Allowed']
          },
        ));

        // Instructions header
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.staticText,
          x: 0,
          y: 185,
          width: 100,
          content: 'Instructions:',
          properties: {'fontSize': 11.0, 'bold': true, 'alignment': 'left', 'decoration': 'underline'},
        ));

        return CustomLayout(elements: elements, canvasHeight: 205);

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
        // --- SCHOOL TEMPLATES ---
        PaperTemplate(
          id: 'school_classic_centered',
          name: 'Classic Centered',
          type: TemplateType.school,
          hasBorder: true,
          headerLayout: HeaderLayout.centered,
        ),
        PaperTemplate(
          id: 'school_modern_left',
          name: 'Modern Left (Logo)',
          type: TemplateType.school,
          hasBorder: false,
          headerLayout: HeaderLayout.logoLeft,
          primaryColor: PdfColors.blue800,
        ),
        PaperTemplate(
          id: 'school_ssvm_style',
          name: 'SSVM Style',
          type: TemplateType.school,
          hasBorder: true,
          headerLayout: HeaderLayout.ssvm,
          primaryColor: PdfColors.indigo900,
          headerFontSize: 24,
        ),
        PaperTemplate(
          id: 'school_dps_style',
          name: 'DPS Style',
          type: TemplateType.school,
          hasBorder: false,
          headerLayout: HeaderLayout.dps,
          primaryColor: PdfColors.green800,
        ),
        PaperTemplate(
          id: 'school_xavier_style',
          name: 'Xavier Style',
          type: TemplateType.school,
          hasBorder: true,
          headerLayout: HeaderLayout.academic,
          primaryColor: PdfColors.red900,
          headerFontSize: 26,
        ),

        // --- COLLEGE TEMPLATES ---
        PaperTemplate(
          id: 'college_formal',
          name: 'Formal College',
          type: TemplateType.college,
          hasBorder: false,
          headerLayout: HeaderLayout.logoLeft,
          primaryColor: PdfColors.grey900,
        ),
        PaperTemplate(
          id: 'college_modern',
          name: 'University Modern',
          type: TemplateType.college,
          hasBorder: true,
          headerLayout: HeaderLayout.modernCoaching,
          primaryColor: PdfColors.blueGrey900,
        ),

        // --- COACHING TEMPLATES ---
        PaperTemplate(
          id: 'coaching_pro',
          name: 'Coaching Pro',
          type: TemplateType.coaching,
          primaryColor: PdfColors.blue900,
          secondaryColor: PdfColors.blue100,
          headerLayout: HeaderLayout.modernCoaching,
        ),
        PaperTemplate(
          id: 'coaching_minimal',
          name: 'Coaching Lite',
          type: TemplateType.coaching,
          headerLayout: HeaderLayout.minimal,
        ),

        // --- KIDS SCHOOL TEMPLATES ---
        PaperTemplate(
          id: 'kids_playful',
          name: 'Playful Kids',
          type: TemplateType.kids,
          primaryColor: PdfColors.pink300,
          secondaryColor: PdfColors.yellow100,
          headerFontSize: 28,
          headerLayout: HeaderLayout.centered,
        ),
        PaperTemplate(
          id: 'kids_creative',
          name: 'Creative Primary',
          type: TemplateType.kids,
          primaryColor: PdfColors.orange400,
          headerLayout: HeaderLayout.logoRight,
        ),

        // --- BOARD TEMPLATES ---
        PaperTemplate(
          id: 'board_cbse',
          name: 'Board (CBSE Style)',
          type: TemplateType.board,
          headerLayout: HeaderLayout.centered,
        ),
      ];
}
