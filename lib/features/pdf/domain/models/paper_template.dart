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

enum PaperLayout { standard, twoColumn }

enum PaperSize { a4, a5, a3, letter, legal }

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
    const double contentWidth = CustomLayout.designWidth;

    switch (headerLayout) {
      case HeaderLayout.centered:
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.logo,
            x: (contentWidth - 50) / 2,
            y: 0,
            width: 50,
            height: 50,
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.schoolName,
            x: 0,
            y: 58,
            width: contentWidth,
            properties: {'fontSize': 18.0, 'bold': true, 'alignment': 'center'},
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.paperTitle,
            x: 0,
            y: 80,
            width: contentWidth,
            properties: {
              'fontSize': headerFontSize,
              'bold': true,
              'alignment': 'center',
            },
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.headerFieldsBlock,
            x: 0,
            y: 110,
            width: contentWidth,
            properties: {'fontSize': 12.0, 'alignment': 'center'},
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.maxMarks,
            x: 0,
            y: 150,
            width: contentWidth,
            properties: {'fontSize': 12.0, 'bold': true, 'alignment': 'right'},
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.horizontalLine,
            x: 0,
            y: 175,
            width: contentWidth,
            properties: {'color': 0xFF000000},
          ),
        );
        return CustomLayout(elements: elements, canvasHeight: 180);

      case HeaderLayout.logoLeft:
      case HeaderLayout.logoRight:
        final isLeft = headerLayout == HeaderLayout.logoLeft;
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.logo,
            x: isLeft ? 0 : contentWidth - 60,
            y: 0,
            width: 60,
            height: 60,
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.schoolName,
            x: isLeft ? 76 : 0,
            y: 5,
            width: contentWidth - 76,
            properties: {
              'fontSize': 18.0,
              'bold': true,
              'alignment': isLeft ? 'left' : 'right',
            },
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.paperTitle,
            x: isLeft ? 76 : 0,
            y: 28,
            width: contentWidth - 76,
            properties: {
              'fontSize': headerFontSize,
              'bold': true,
              'alignment': isLeft ? 'left' : 'right',
            },
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.maxMarks,
            x: 0,
            y: 70,
            width: contentWidth,
            properties: {
              'fontSize': 12.0,
              'bold': true,
              'alignment': isLeft ? 'right' : 'left',
            },
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.headerFieldsBlock,
            x: 0,
            y: 95,
            width: contentWidth,
            properties: {'fontSize': 11.0, 'alignment': 'left'},
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.horizontalLine,
            x: 0,
            y: 135,
            width: contentWidth,
            properties: {'color': 0xFF000000},
          ),
        );
        return CustomLayout(elements: elements, canvasHeight: 140);

      case HeaderLayout.modernCoaching:
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.logo,
            x: 10,
            y: 10,
            width: 60,
            height: 60,
          ),
        );
        elements.add(
          TemplateElement(
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
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.paperTitle,
            x: 90,
            y: 42,
            width: contentWidth - 200,
            properties: {'fontSize': 16.0, 'alignment': 'left'},
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.maxMarks,
            x: contentWidth - 110,
            y: 30,
            width: 100,
            properties: {'fontSize': 12.0, 'bold': true, 'alignment': 'right'},
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.headerFieldsBlock,
            x: 10,
            y: 85,
            width: contentWidth - 20,
            properties: {'fontSize': 11.0, 'alignment': 'left'},
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.horizontalLine,
            x: 0,
            y: 125,
            width: contentWidth,
            properties: {'color': primaryColor.toInt()},
          ),
        );
        return CustomLayout(elements: elements, canvasHeight: 130);

      case HeaderLayout.minimal:
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.schoolName,
            x: 0,
            y: 0,
            width: contentWidth / 2,
            properties: {
              'fontSize': 10.0,
              'bold': true,
              'alignment': 'left',
              'color': 0xFF9E9E9E,
            },
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.maxMarks,
            x: contentWidth / 2,
            y: 0,
            width: contentWidth / 2,
            properties: {'fontSize': 10.0, 'bold': true, 'alignment': 'right'},
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.paperTitle,
            x: 0,
            y: 15,
            width: contentWidth,
            properties: {'fontSize': 14.0, 'bold': true, 'alignment': 'left'},
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.headerFieldsBlock,
            x: 0,
            y: 40,
            width: contentWidth,
            properties: {'fontSize': 11.0, 'alignment': 'left'},
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.horizontalLine,
            x: 0,
            y: 75,
            width: contentWidth,
            properties: {'color': 0xFF000000},
          ),
        );
        return CustomLayout(elements: elements, canvasHeight: 80);

      case HeaderLayout.academic:
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.logo,
            x: (contentWidth - 60) / 2,
            y: 0,
            width: 60,
            height: 60,
          ),
        );
        elements.add(
          TemplateElement(
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
          ),
        );
        elements.add(
          TemplateElement(
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
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.paperTitle,
            x: 0,
            y: 102,
            width: contentWidth,
            properties: {'fontSize': 16.0, 'bold': true, 'alignment': 'center'},
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.headerFieldsBlock,
            x: 0,
            y: 130,
            width: contentWidth,
            properties: {
              'fontSize': 11.0,
              'alignment': 'left',
              'fieldLabels': ['Name', 'Roll No', 'Sec'],
            },
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.headerFieldsBlock,
            x: 0,
            y: 155,
            width: contentWidth * 0.7,
            properties: {
              'fontSize': 11.0,
              'alignment': 'left',
              'fieldLabels': ['Subject', 'Class', 'Date'],
            },
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.maxMarks,
            x: contentWidth - 150,
            y: 155,
            width: 150,
            properties: {'fontSize': 11.0, 'bold': true, 'alignment': 'right'},
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.horizontalLine,
            x: 0,
            y: 185,
            width: contentWidth,
            properties: {'color': 0xFF000000},
          ),
        );
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.horizontalLine,
            x: 0,
            y: 188,
            width: contentWidth,
            properties: {'color': 0xFF000000},
          ),
        );
        return CustomLayout(elements: elements, canvasHeight: 195);

      case HeaderLayout.ssvm:
        const double logoSize = 72;
        const double topY = 4;

        // =========================
        // TOP SMALL TEXTS
        // =========================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.staticText,
            x: 6,
            y: topY,
            width: 120,
            content: 'SIX-ENGLISH',
            properties: {
              'fontSize': 8.5,
              'bold': true,
              'alignment': 'left',
              'fontFamily': 'times',
            },
          ),
        );

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.staticText,
            x: contentWidth - 126,
            y: topY,
            width: 120,
            content: 'SIX-ENGLISH',
            properties: {
              'fontSize': 8.5,
              'bold': true,
              'alignment': 'right',
              'fontFamily': 'times',
            },
          ),
        );

        // =========================
        // LEFT LOGO
        // =========================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.logo,
            x: 8,
            y: 18,
            width: logoSize,
            height: logoSize,
          ),
        );

        // =========================
        // SCHOOL NAME
        // =========================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.schoolName,
            x: 92,
            y: 20,
            width: contentWidth - 100,
            properties: {
              'fontSize': 22.0,
              'bold': true,
              'alignment': 'center',
              'fontFamily': 'timesBold',
              'letterSpacing': 0.3,
              'color': 0xFF111111,
            },
          ),
        );

        // =========================
        // EXAM BOX
        // =========================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.staticText,
            x: 185,
            y: 52,
            width: 230,
            height: 24,
            content: 'Annual Examination : 2024-25',
            properties: {
              'fontSize': 13.5,
              'bold': true,
              'alignment': 'center',
              'fontFamily': 'timesBold',
              'border': true,
              'borderRadius': 4,
              'paddingVertical': 4,
              'paddingHorizontal': 8,
            },
          ),
        );

        // =========================
        // LEFT DETAILS
        // =========================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.staticText,
            x: 95,
            y: 84,
            width: 170,
            content: '[Class : Six]',
            properties: {
              'fontSize': 11,
              'bold': true,
              'alignment': 'left',
              'fontFamily': 'times',
            },
          ),
        );

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.staticText,
            x: 95,
            y: 104,
            width: 170,
            content: '[Time : 2:30 Hours]',
            properties: {
              'fontSize': 11,
              'bold': true,
              'alignment': 'left',
              'fontFamily': 'times',
            },
          ),
        );

        // =========================
        // RIGHT DETAILS
        // =========================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.staticText,
            x: contentWidth - 180,
            y: 84,
            width: 170,
            content: '[Subject : English]',
            properties: {
              'fontSize': 11,
              'bold': true,
              'alignment': 'right',
              'fontFamily': 'times',
            },
          ),
        );

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.staticText,
            x: contentWidth - 180,
            y: 104,
            width: 170,
            content: '[Full Marks : 80]',
            properties: {
              'fontSize': 11,
              'bold': true,
              'alignment': 'right',
              'fontFamily': 'times',
            },
          ),
        );

        // =========================
        // FIRST DIVIDER
        // =========================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.horizontalLine,
            x: 0,
            y: 126,
            width: contentWidth,
            properties: {'thickness': 1.2, 'color': 0xFF000000},
          ),
        );

        // =========================
        // INSTRUCTION TEXT
        // =========================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.staticText,
            x: 0,
            y: 132,
            width: contentWidth,
            content:
                'All questions are compulsory. Figures in the margin indicate full marks.',
            properties: {
              'fontSize': 10.5,
              'bold': true,
              'italic': true,
              'alignment': 'center',
              'fontFamily': 'timesItalic',
            },
          ),
        );

        // =========================
        // SECOND DIVIDER
        // =========================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.horizontalLine,
            x: 0,
            y: 152,
            width: contentWidth,
            properties: {'thickness': 1.2, 'color': 0xFF000000},
          ),
        );

        return CustomLayout(elements: elements, canvasHeight: 158);

      case HeaderLayout.dps:
        const double logoSize = 42;
        const double topY = 8;

        // ======================================================
        // TOP SERIES + CODE
        // ======================================================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.staticText,
            x: 18,
            y: topY,
            width: 220,
            content: 'Series : DPS/ST/SS-SA2/10-11',
            properties: {
              'fontSize': 9.5,
              'alignment': 'left',
              'fontFamily': 'times',
            },
          ),
        );

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.staticText,
            x: contentWidth - 150,
            y: topY,
            width: 130,
            content: 'Code : 087',
            properties: {
              'fontSize': 9.5,
              'alignment': 'right',
              'fontFamily': 'times',
            },
          ),
        );

        // ======================================================
        // CENTER LOGO
        // ======================================================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.logo,
            x: (contentWidth - logoSize) / 2,
            y: 18,
            width: logoSize,
            height: logoSize,
          ),
        );

        // ======================================================
        // SCHOOL NAME
        // ======================================================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.schoolName,
            x: 0,
            y: 66,
            width: contentWidth,
            properties: {
              'fontSize': 16.5,
              'bold': false,
              'alignment': 'center',
              'fontFamily': 'timesBold',
              'letterSpacing': 0.2,
            },
          ),
        );

        // ======================================================
        // SAMPLE PAPER
        // ======================================================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.staticText,
            x: 0,
            y: 88,
            width: contentWidth,
            content: 'SAMPLE PAPER',
            properties: {
              'fontSize': 14,
              'bold': true,
              'alignment': 'center',
              'fontFamily': 'timesBold',
            },
          ),
        );

        // ======================================================
        // SUBJECT
        // ======================================================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.paperTitle,
            x: 0,
            y: 108,
            width: contentWidth,
            properties: {
              'fontSize': 14,
              'bold': true,
              'alignment': 'center',
              'fontFamily': 'timesBold',
            },
          ),
        );

        // ======================================================
        // ROLL NO
        // ======================================================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.staticText,
            x: 20,
            y: 145,
            width: 120,
            content: 'Roll No :',
            properties: {
              'fontSize': 11,
              'bold': true,
              'alignment': 'left',
              'fontFamily': 'timesBold',
            },
          ),
        );

        // Roll number boxes
        for (int i = 0; i < 3; i++) {
          elements.add(
            TemplateElement(
              id: uuid.v4(),
              type: ElementType.rectangular,
              x: 78 + (i * 24),
              y: 142,
              width: 22,
              height: 18,
              properties: {'borderColor': 0xFF000000, 'borderWidth': 1},
            ),
          );
        }

        // ======================================================
        // CLASS
        // ======================================================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.staticText,
            x: contentWidth - 120,
            y: 145,
            width: 100,
            content: 'Class : X',
            properties: {
              'fontSize': 11,
              'bold': true,
              'alignment': 'right',
              'fontFamily': 'timesBold',
            },
          ),
        );

        // ======================================================
        // MARKS
        // ======================================================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.staticText,
            x: 20,
            y: 175,
            width: 150,
            content: 'Marks : 80',
            properties: {
              'fontSize': 11,
              'bold': true,
              'alignment': 'left',
              'fontFamily': 'timesBold',
            },
          ),
        );

        // ======================================================
        // TIME
        // ======================================================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.staticText,
            x: contentWidth - 180,
            y: 175,
            width: 160,
            content: 'Time Allowed : 3 Hrs',
            properties: {
              'fontSize': 11,
              'bold': true,
              'italic': true,
              'alignment': 'right',
              'fontFamily': 'timesItalic',
            },
          ),
        );

        // ======================================================
        // INSTRUCTIONS TITLE
        // ======================================================

        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.staticText,
            x: 20,
            y: 205,
            width: 150,
            content: 'Instructions:',
            properties: {
              'fontSize': 11,
              'bold': true,
              'italic': true,
              'alignment': 'left',
              'fontFamily': 'timesBoldItalic',
              'decoration': 'underline',
            },
          ),
        );

        return CustomLayout(elements: elements, canvasHeight: 230);
      default:
        elements.add(
          TemplateElement(
            id: uuid.v4(),
            type: ElementType.schoolName,
            x: 0,
            y: 20,
            width: contentWidth,
            properties: {'fontSize': 20.0, 'bold': true, 'alignment': 'center'},
          ),
        );
        return CustomLayout(elements: elements, canvasHeight: 100);
    }
  }

  static List<PaperTemplate> get predefinedTemplates => [
    // =========================================================
    // SCHOOL TEMPLATES
    // =========================================================
    PaperTemplate(
      id: 'school_ssvm_style',
      name: 'SSVM Style',
      type: TemplateType.school,
      hasBorder: true,
      headerLayout: HeaderLayout.ssvm,
      primaryColor: PdfColors.black,
      headerFontSize: 22,
      questionFontSize: 12,
    ),

    PaperTemplate(
      id: 'school_dps_style',
      name: 'DPS Board Style',
      type: TemplateType.school,
      hasBorder: false,
      headerLayout: HeaderLayout.dps,
      primaryColor: PdfColors.green900,
      headerFontSize: 18,
      questionFontSize: 11,
    ),

    PaperTemplate(
      id: 'school_xavier_style',
      name: 'Xavier Academic',
      type: TemplateType.school,
      hasBorder: true,
      headerLayout: HeaderLayout.academic,
      primaryColor: PdfColors.red900,
      headerFontSize: 24,
      questionFontSize: 11,
    ),

    PaperTemplate(
      id: 'school_modern_left',
      name: 'Modern School',
      type: TemplateType.school,
      hasBorder: false,
      headerLayout: HeaderLayout.logoLeft,
      primaryColor: PdfColors.blue800,
      headerFontSize: 18,
    ),

    // =========================================================
    // BOARD EXAM TEMPLATES
    // =========================================================
    PaperTemplate(
      id: 'board_cbse',
      name: 'CBSE Official',
      type: TemplateType.board,
      hasBorder: false,
      headerLayout: HeaderLayout.centered,
      primaryColor: PdfColors.black,
      headerFontSize: 17,
      questionFontSize: 11,
    ),

    PaperTemplate(
      id: 'board_icse',
      name: 'ICSE Council',
      type: TemplateType.board,
      hasBorder: true,
      headerLayout: HeaderLayout.academic,
      primaryColor: PdfColors.blueGrey900,
      headerFontSize: 18,
      questionFontSize: 11,
    ),

    // =========================================================
    // COLLEGE / UNIVERSITY
    // =========================================================
    PaperTemplate(
      id: 'college_formal',
      name: 'Formal University',
      type: TemplateType.college,
      hasBorder: false,
      headerLayout: HeaderLayout.logoLeft,
      primaryColor: PdfColors.grey900,
      headerFontSize: 19,
      questionFontSize: 11,
    ),

    PaperTemplate(
      id: 'college_modern',
      name: 'University Modern',
      type: TemplateType.college,
      hasBorder: true,
      headerLayout: HeaderLayout.modernCoaching,
      primaryColor: PdfColors.blueGrey800,
      headerFontSize: 18,
      questionFontSize: 11,
    ),

    PaperTemplate(
      id: 'college_semester',
      name: 'Semester Exam',
      type: TemplateType.college,
      hasBorder: true,
      headerLayout: HeaderLayout.minimal,
      primaryColor: PdfColors.black,
      headerFontSize: 16,
      questionFontSize: 11,
    ),

    // =========================================================
    // COACHING / INSTITUTE
    // =========================================================
    PaperTemplate(
      id: 'coaching_allen',
      name: 'Allen Style',
      type: TemplateType.coaching,
      hasBorder: false,
      headerLayout: HeaderLayout.modernCoaching,
      primaryColor: PdfColors.blue900,
      secondaryColor: PdfColors.blue100,
      headerFontSize: 17,
      questionFontSize: 11,
    ),

    PaperTemplate(
      id: 'coaching_akash',
      name: 'Aakash Style',
      type: TemplateType.coaching,
      hasBorder: false,
      headerLayout: HeaderLayout.logoLeft,
      primaryColor: PdfColors.green800,
      headerFontSize: 17,
      questionFontSize: 11,
    ),

    PaperTemplate(
      id: 'coaching_minimal',
      name: 'Coaching Lite',
      type: TemplateType.coaching,
      hasBorder: false,
      headerLayout: HeaderLayout.minimal,
      primaryColor: PdfColors.black,
      headerFontSize: 15,
      questionFontSize: 11,
    ),

    // =========================================================
    // KIDS / PRIMARY SCHOOL
    // =========================================================
    PaperTemplate(
      id: 'kids_playful',
      name: 'Playful Kids',
      type: TemplateType.kids,
      hasBorder: true,
      headerLayout: HeaderLayout.centered,
      primaryColor: PdfColors.pink400,
      secondaryColor: PdfColors.yellow100,
      headerFontSize: 28,
      questionFontSize: 14,
    ),

    PaperTemplate(
      id: 'kids_creative',
      name: 'Creative Primary',
      type: TemplateType.kids,
      hasBorder: true,
      headerLayout: HeaderLayout.logoRight,
      primaryColor: PdfColors.orange400,
      secondaryColor: PdfColors.orange100,
      headerFontSize: 24,
      questionFontSize: 13,
    ),

    PaperTemplate(
      id: 'kids_cartoon',
      name: 'Fun Worksheet',
      type: TemplateType.kids,
      hasBorder: true,
      headerLayout: HeaderLayout.centered,
      primaryColor: PdfColors.lightBlue400,
      secondaryColor: PdfColors.lightBlue100,
      headerFontSize: 26,
      questionFontSize: 14,
    ),
  ];
}
