import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:pdf/pdf.dart';

/// Persisted template categories. Do not reorder: custom template JSON stores
/// enum indexes for backwards compatibility.
enum TemplateType { school, college, coaching, kids, board }

/// Persisted header layout identifiers. Do not reorder.
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

/// Persisted question layout identifiers. Do not reorder.
enum PaperLayout { standard, twoColumn }

/// Persisted page-size identifiers. Do not reorder.
enum PaperSize { a4, a5, a3, letter, legal }

/// Data-only print style model.
///
/// Layout generation and the predefined style catalog deliberately live in
/// application services so selecting a style never mutates paper content.
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

  const PaperTemplate({
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
    bool clearCustomLayout = false,
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
      customLayout: clearCustomLayout
          ? null
          : (customLayout ?? this.customLayout),
    );
  }
}
