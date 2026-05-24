import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';

abstract class HeaderBuilder {
  pw.Widget build(
    Paper paper,
    List<pw.ImageProvider?> logos,
    PaperTemplate template, {
    Map<String, pw.ImageProvider>? customImages,
  });

  pw.Widget buildDynamicHeaderFields(Paper paper, PaperTemplate template) {
    if (paper.headerFields.isEmpty) return pw.SizedBox();

    // Group fields in rows of 2 or 3 depending on length
    List<List<PaperHeaderField>> rows = [];
    for (var i = 0; i < paper.headerFields.length; i += 2) {
      rows.add(
        paper.headerFields.sublist(
          i,
          i + 2 > paper.headerFields.length ? paper.headerFields.length : i + 2,
        ),
      );
    }

    return pw.Column(
      children: rows.map((row) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            children: row.map((field) {
              final content = field.isPlaceholder
                  ? '________________'
                  : field.value;
              return pw.Expanded(
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: '${field.label}: ',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.TextSpan(text: content),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class CenteredHeaderBuilder extends HeaderBuilder {
  @override
  pw.Widget build(
    Paper paper,
    List<pw.ImageProvider?> logos,
    PaperTemplate template, {
    Map<String, pw.ImageProvider>? customImages,
  }) {
    final logoImage = logos.isNotEmpty ? logos.first : null;
    return pw.Column(
      children: [
        if (logoImage != null)
          pw.Container(
            width: 50,
            height: 50,
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Image(logoImage),
          ),
        pw.Text(
          paper.schoolName,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.Text(
          paper.title,
          style: pw.TextStyle(
            fontSize: template.headerFontSize,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 10),
        buildDynamicHeaderFields(paper, template),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Max Marks: ${paper.totalMarks}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }
}

class LogoSideHeaderBuilder extends HeaderBuilder {
  final bool isLogoLeft;

  LogoSideHeaderBuilder({required this.isLogoLeft});

  @override
  pw.Widget build(
    Paper paper,
    List<pw.ImageProvider?> logos,
    PaperTemplate template, {
    Map<String, pw.ImageProvider>? customImages,
  }) {
    final logoImage = logos.isNotEmpty ? logos.first : null;
    final logo = logoImage != null
        ? pw.Container(
            width: 60,
            height: 60,
            margin: isLogoLeft
                ? const pw.EdgeInsets.only(right: 16)
                : const pw.EdgeInsets.only(left: 16),
            child: pw.Image(logoImage),
          )
        : pw.SizedBox();

    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (isLogoLeft) logo,
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: isLogoLeft
                    ? pw.CrossAxisAlignment.start
                    : pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    paper.schoolName,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    paper.title,
                    style: pw.TextStyle(
                      fontSize: template.headerFontSize,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLogoLeft) logo,
          ],
        ),
        pw.Row(
          mainAxisAlignment: isLogoLeft
              ? pw.MainAxisAlignment.end
              : pw.MainAxisAlignment.start,
          children: [
            pw.Text(
              'Max Marks: ${paper.totalMarks}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        buildDynamicHeaderFields(paper, template),
        pw.Divider(thickness: 1),
      ],
    );
  }
}

class LogoLeftHeaderBuilder extends LogoSideHeaderBuilder {
  LogoLeftHeaderBuilder() : super(isLogoLeft: true);
}

class LogoRightHeaderBuilder extends LogoSideHeaderBuilder {
  LogoRightHeaderBuilder() : super(isLogoLeft: false);
}

class ModernCoachingHeaderBuilder extends HeaderBuilder {
  @override
  pw.Widget build(
    Paper paper,
    List<pw.ImageProvider?> logos,
    PaperTemplate template, {
    Map<String, pw.ImageProvider>? customImages,
  }) {
    final logoImage = logos.isNotEmpty ? logos.first : null;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: template.secondaryColor,
        border: pw.Border(
          bottom: pw.BorderSide(color: template.primaryColor, width: 2),
        ),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            children: [
              if (logoImage != null)
                pw.Container(width: 60, height: 60, child: pw.Image(logoImage)),
              pw.SizedBox(width: 20),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    paper.schoolName,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: template.primaryColor,
                    ),
                  ),
                  pw.Text(paper.title, style: pw.TextStyle(fontSize: 16)),
                ],
              ),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Max Marks: ${paper.totalMarks}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          buildDynamicHeaderFields(paper, template),
        ],
      ),
    );
  }
}

class MinimalHeaderBuilder extends HeaderBuilder {
  @override
  pw.Widget build(
    Paper paper,
    List<pw.ImageProvider?> logos,
    PaperTemplate template, {
    Map<String, pw.ImageProvider>? customImages,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              paper.schoolName.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey,
              ),
            ),
            pw.Text(
              'MM: ${paper.totalMarks}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          paper.title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        buildDynamicHeaderFields(paper, template),
        pw.Divider(thickness: 0.5),
      ],
    );
  }
}

class CustomHeaderBuilder extends HeaderBuilder {
  @override
  pw.Widget build(
    Paper paper,
    List<pw.ImageProvider?> logos,
    PaperTemplate template, {
    Map<String, pw.ImageProvider>? customImages,
  }) {
    final layout = template.customLayout ?? template.effectiveLayout;

    return pw.LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints?.maxWidth.isFinite == true
            ? constraints!.maxWidth
            : CustomLayout.designWidth;
        final scale = contentWidth / CustomLayout.designWidth;

        int logoIdx = 0;
        final elements = layout.elements.map((el) {
          pw.ImageProvider? logoImg;
          if (el.type == ElementType.logo) {
            final currentIdx = logoIdx++;
            if (logos.length > currentIdx && logos[currentIdx] != null) {
              logoImg = logos[currentIdx];
            } else if (el.content.isNotEmpty) {
              logoImg = customImages?[el.content];
            }
          }

          return pw.Positioned(
            left: el.x * scale,
            top: el.y * scale,
            child: _buildElement(el, paper, logoImg, template, scale),
          );
        }).toList();

        return pw.Container(
          height: layout.canvasHeight * scale,
          width: contentWidth,
          child: pw.Stack(children: elements),
        );
      },
    );
  }

  pw.Widget _buildElement(
    TemplateElement el,
    Paper paper,
    pw.ImageProvider? logoImage,
    PaperTemplate template,
    double scale,
  ) {
    final style = pw.TextStyle(
      fontSize: (el.properties['fontSize']?.toDouble() ?? 12) * scale,
      fontWeight: el.properties['bold'] == true
          ? pw.FontWeight.bold
          : pw.FontWeight.normal,
      fontStyle: el.properties['italic'] == true
          ? pw.FontStyle.italic
          : pw.FontStyle.normal,
      decoration: el.properties['decoration'] == 'underline'
          ? pw.TextDecoration.underline
          : pw.TextDecoration.none,
      color: el.properties['color'] != null
          ? PdfColor.fromInt(el.properties['color'])
          : PdfColors.black,
    );

    final alignment = _getPdfAlignment(el.properties['alignment']);

    switch (el.type) {
      case ElementType.schoolName:
        return pw.Container(
          width: el.width != null ? el.width! * scale : null,
          height: el.height != null ? el.height! * scale : null,
          alignment: alignment,
          child: pw.Text(paper.schoolName, style: style, maxLines: 1),
        );
      case ElementType.paperTitle:
        return pw.Container(
          width: el.width != null ? el.width! * scale : null,
          height: el.height != null ? el.height! * scale : null,
          alignment: alignment,
          child: pw.Text(paper.title, style: style, maxLines: 1),
        );
      case ElementType.logo:
        if (logoImage != null) {
          return pw.Container(
            width: (el.width ?? 50) * scale,
            height: (el.height ?? 50) * scale,
            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
          );
        }
        return pw.SizedBox();
      case ElementType.maxMarks:
        return pw.Container(
          width: el.width != null ? el.width! * scale : null,
          height: el.height != null ? el.height! * scale : null,
          alignment: alignment,
          child: pw.Text(
            'Max Marks: ${paper.totalMarks.toStringAsFixed(0)}',
            style: style,
          ),
        );
      case ElementType.headerFieldsBlock:
        final List<dynamic> labels =
            el.properties['fieldLabels'] ?? ['Subject', 'Date'];
        return pw.Container(
          width: (el.width ?? 300) * scale,
          height: el.height != null ? el.height! * scale : null,
          child: pw.Wrap(
            spacing: 16 * scale,
            runSpacing: 4 * scale,
            alignment: _getWrapAlignment(el.properties['alignment']),
            children: labels.map((l) {
              final field = paper.headerFields.firstWhere(
                (f) => f.label.toLowerCase() == l.toString().toLowerCase(),
                orElse: () => PaperHeaderField(
                  id: '',
                  label: l.toString(),
                  isPlaceholder: true,
                ),
              );
              final content = field.isPlaceholder
                  ? '________________'
                  : field.value;
              return pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: '${field.label}: ',
                      style: style.copyWith(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: style.fontSize! * 0.85,
                      ),
                    ),
                    pw.TextSpan(
                      text: content,
                      style: style.copyWith(fontSize: style.fontSize! * 0.85),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      case ElementType.staticText:
        final hasBorder = el.properties['border'] == true;
        final content =
            paper.customHeaderValues[el.paperBindingKey] ?? el.content;
        return pw.Container(
          width: el.width != null ? el.width! * scale : null,
          height: el.height != null ? el.height! * scale : null,
          padding: pw.EdgeInsets.symmetric(
            vertical:
                (el.properties['paddingVertical']?.toDouble() ?? 0) * scale,
            horizontal:
                (el.properties['paddingHorizontal']?.toDouble() ?? 0) * scale,
          ),
          decoration: hasBorder
              ? pw.BoxDecoration(
                  border: pw.Border.all(
                    color: el.properties['borderColor'] != null
                        ? PdfColor.fromInt(el.properties['borderColor'])
                        : PdfColors.black,
                    width:
                        (el.properties['borderWidth']?.toDouble() ?? 1) * scale,
                  ),
                  borderRadius: el.properties['borderRadius'] != null
                      ? pw.BorderRadius.circular(
                          el.properties['borderRadius'].toDouble() * scale,
                        )
                      : null,
                )
              : null,
          alignment: alignment,
          child: pw.Text(content, style: style, maxLines: 1),
        );
      case ElementType.horizontalLine:
        return pw.Container(
          width: (el.width ?? 100) * scale,
          height: (el.properties['thickness']?.toDouble() ?? 1) * scale,
          color: style.color,
        );
      case ElementType.rectangular:
        return pw.Container(
          width: el.width != null ? el.width! * scale : null,
          height: el.height != null ? el.height! * scale : null,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: el.properties['borderColor'] != null
                  ? PdfColor.fromInt(el.properties['borderColor'])
                  : PdfColors.black,
              width: (el.properties['borderWidth']?.toDouble() ?? 1) * scale,
            ),
            borderRadius: el.properties['borderRadius'] != null
                ? pw.BorderRadius.circular(
                    el.properties['borderRadius'].toDouble() * scale,
                  )
                : null,
            color: el.properties['fillColor'] != null
                ? PdfColor.fromInt(el.properties['fillColor'])
                : null,
          ),
          alignment: alignment,
          child: el.content.isNotEmpty
              ? pw.Text(el.content, style: style, maxLines: 1)
              : null,
        );
    }
  }

  pw.Alignment _getPdfAlignment(String? align) {
    switch (align) {
      case 'center':
        return pw.Alignment.center;
      case 'right':
        return pw.Alignment.centerRight;
      default:
        return pw.Alignment.centerLeft;
    }
  }

  pw.WrapAlignment _getWrapAlignment(String? align) {
    switch (align) {
      case 'center':
        return pw.WrapAlignment.center;
      case 'right':
        return pw.WrapAlignment.end;
      default:
        return pw.WrapAlignment.start;
    }
  }
}
