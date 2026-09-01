import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/application/paper_header_layout_factory.dart';
import 'package:edusheet/features/pdf/application/paper_document_marks.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Single header renderer for both built-in and custom layouts.
///
/// Older parallel header builders were unreachable because PDF generation
/// always delegated to the custom-layout path. Keeping one renderer prevents
/// the style chooser and exported paper from drifting apart.
class CustomHeaderBuilder {
  pw.Widget build(
    Paper paper,
    List<pw.ImageProvider?> logos,
    PaperTemplate template, {
    Map<String, pw.ImageProvider>? customImages,
  }) {
    final layout = PaperHeaderLayoutFactory.resolveForPaper(template, paper);

    return pw.LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints?.maxWidth.isFinite == true
            ? constraints!.maxWidth
            : CustomLayout.designWidth;
        final scale = contentWidth / CustomLayout.designWidth;

        var logoIndex = 0;
        final elements = layout.elements
            .map((element) {
              pw.ImageProvider? logoImage;
              if (element.type == ElementType.logo) {
                final currentIndex = logoIndex++;
                if (currentIndex < logos.length &&
                    logos[currentIndex] != null) {
                  logoImage = logos[currentIndex];
                } else if (element.content.isNotEmpty) {
                  logoImage = customImages?[element.content];
                }
              }

              return pw.Positioned(
                left: element.x * scale,
                top: element.y * scale,
                child: _buildElement(
                  element,
                  paper,
                  logoImage,
                  template,
                  scale,
                ),
              );
            })
            .toList(growable: false);

        return pw.Container(
          height: layout.canvasHeight * scale,
          width: contentWidth,
          child: pw.Stack(children: elements),
        );
      },
    );
  }

  pw.Widget _buildElement(
    TemplateElement element,
    Paper paper,
    pw.ImageProvider? logoImage,
    PaperTemplate template,
    double scale,
  ) {
    final style = pw.TextStyle(
      fontSize: _number(element.properties['fontSize'], 12) * scale,
      fontWeight: element.properties['bold'] == true
          ? pw.FontWeight.bold
          : pw.FontWeight.normal,
      fontStyle: element.properties['italic'] == true
          ? pw.FontStyle.italic
          : pw.FontStyle.normal,
      decoration: element.properties['decoration'] == 'underline'
          ? pw.TextDecoration.underline
          : pw.TextDecoration.none,
      color: _pdfColor(element.properties['color']) ?? PdfColors.black,
    );
    final alignment = _alignment(element.properties['alignment']?.toString());

    switch (element.type) {
      case ElementType.schoolName:
        return _textBox(element, scale, alignment, paper.schoolName, style);
      case ElementType.paperTitle:
        return _textBox(element, scale, alignment, paper.title, style);
      case ElementType.logo:
        if (logoImage == null) return pw.SizedBox();
        return pw.SizedBox(
          width: (element.width ?? 50) * scale,
          height: (element.height ?? 50) * scale,
          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
        );
      case ElementType.maxMarks:
        return _textBox(
          element,
          scale,
          alignment,
          PaperDocumentMarks.maximumMarksLabel(paper),
          style,
        );
      case ElementType.headerFieldsBlock:
        return _buildHeaderFields(element, paper, style, scale);
      case ElementType.staticText:
        final content =
            paper.customHeaderValues[element.paperBindingKey] ??
            element.content;
        if (content.trim().isEmpty) return pw.SizedBox();
        final bordered = element.properties['border'] == true;
        return pw.Container(
          width: element.width == null ? null : element.width! * scale,
          height: element.height == null ? null : element.height! * scale,
          padding: pw.EdgeInsets.symmetric(
            vertical: _number(element.properties['paddingVertical'], 0) * scale,
            horizontal:
                _number(element.properties['paddingHorizontal'], 0) * scale,
          ),
          decoration: bordered
              ? pw.BoxDecoration(
                  border: pw.Border.all(
                    color:
                        _pdfColor(element.properties['borderColor']) ??
                        PdfColors.black,
                    width:
                        _number(element.properties['borderWidth'], 1) * scale,
                  ),
                  borderRadius: element.properties['borderRadius'] == null
                      ? null
                      : pw.BorderRadius.circular(
                          _number(element.properties['borderRadius'], 0) *
                              scale,
                        ),
                )
              : null,
          alignment: alignment,
          child: pw.Text(content, style: style, maxLines: 2),
        );
      case ElementType.horizontalLine:
        return pw.Container(
          width: (element.width ?? 100) * scale,
          height: _number(element.properties['thickness'], 1) * scale,
          color:
              _pdfColor(element.properties['color']) ?? template.primaryColor,
        );
      case ElementType.rectangular:
        return pw.Container(
          width: element.width == null ? null : element.width! * scale,
          height: element.height == null ? null : element.height! * scale,
          alignment: alignment,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color:
                  _pdfColor(element.properties['borderColor']) ??
                  PdfColors.black,
              width: _number(element.properties['borderWidth'], 1) * scale,
            ),
            borderRadius: element.properties['borderRadius'] == null
                ? null
                : pw.BorderRadius.circular(
                    _number(element.properties['borderRadius'], 0) * scale,
                  ),
            color: _pdfColor(element.properties['fillColor']),
          ),
          child: element.content.trim().isEmpty
              ? null
              : pw.Text(element.content, style: style, maxLines: 1),
        );
    }
  }

  pw.Widget _buildHeaderFields(
    TemplateElement element,
    Paper paper,
    pw.TextStyle style,
    double scale,
  ) {
    final requestedLabels =
        (element.properties['fieldLabels'] as List?)
            ?.map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];

    final fields = requestedLabels.isEmpty
        ? paper.headerFields
        : requestedLabels
              .map((label) {
                for (final field in paper.headerFields) {
                  if (field.label.trim().toLowerCase() == label.toLowerCase()) {
                    return field;
                  }
                }
                return PaperHeaderField(
                  id: '',
                  label: label,
                  isPlaceholder: true,
                );
              })
              .toList(growable: false);

    if (fields.isEmpty) return pw.SizedBox();

    final fieldStyle = style.copyWith(fontSize: (style.fontSize ?? 12) * 0.88);
    final rows = <pw.Widget>[];
    for (var index = 0; index < fields.length; index += 2) {
      final rowFields = fields.sublist(
        index,
        (index + 2).clamp(0, fields.length).toInt(),
      );
      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var cellIndex = 0; cellIndex < 2; cellIndex++) ...[
              if (cellIndex > 0) pw.SizedBox(width: 18 * scale),
              pw.Expanded(
                child: cellIndex < rowFields.length
                    ? _buildHeaderFieldCell(rowFields[cellIndex], fieldStyle)
                    : pw.SizedBox(),
              ),
            ],
          ],
        ),
      );
      if (index + 2 < fields.length) {
        rows.add(pw.SizedBox(height: 5 * scale));
      }
    }

    return pw.Container(
      width: (element.width ?? 300) * scale,
      height: element.height == null ? null : element.height! * scale,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }

  pw.Widget _buildHeaderFieldCell(
    PaperHeaderField field,
    pw.TextStyle fieldStyle,
  ) {
    final value = field.value.trim();
    final content = field.isPlaceholder || value.isEmpty
        ? '________________'
        : value;
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '${field.label}: ',
            style: fieldStyle.copyWith(fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(text: content, style: fieldStyle),
        ],
      ),
    );
  }

  pw.Widget _textBox(
    TemplateElement element,
    double scale,
    pw.Alignment alignment,
    String text,
    pw.TextStyle style,
  ) {
    if (text.trim().isEmpty) return pw.SizedBox();
    return pw.Container(
      width: element.width == null ? null : element.width! * scale,
      height: element.height == null ? null : element.height! * scale,
      alignment: alignment,
      child: pw.Text(text, style: style, maxLines: 2),
    );
  }

  static double _number(Object? value, double fallback) =>
      value is num ? value.toDouble() : fallback;

  static PdfColor? _pdfColor(Object? value) {
    if (value is num) return PdfColor.fromInt(value.toInt());
    return null;
  }

  static pw.Alignment _alignment(String? value) {
    switch (value) {
      case 'center':
        return pw.Alignment.center;
      case 'right':
        return pw.Alignment.centerRight;
      default:
        return pw.Alignment.centerLeft;
    }
  }
}
