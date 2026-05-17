import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';

abstract class HeaderBuilder {
  pw.Widget build(Paper paper, pw.ImageProvider? logoImage, PaperTemplate template);

  pw.Widget buildDynamicHeaderFields(Paper paper, PaperTemplate template) {
    if (paper.headerFields.isEmpty) return pw.SizedBox();

    // Group fields in rows of 2 or 3 depending on length
    List<List<PaperHeaderField>> rows = [];
    for (var i = 0; i < paper.headerFields.length; i += 2) {
      rows.add(paper.headerFields.sublist(
          i, i + 2 > paper.headerFields.length ? paper.headerFields.length : i + 2));
    }

    return pw.Column(
      children: rows.map((row) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            children: row.map((field) {
              final content = field.isPlaceholder ? '________________' : field.value;
              return pw.Expanded(
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                          text: '${field.label}: ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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
  pw.Widget build(Paper paper, pw.ImageProvider? logoImage, PaperTemplate template) {
    return pw.Column(
      children: [
        if (logoImage != null)
          pw.Container(
              width: 50, height: 50, margin: const pw.EdgeInsets.only(bottom: 8), child: pw.Image(logoImage)),
        pw.Text(
          paper.schoolName,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.Text(
          paper.title,
          style: pw.TextStyle(fontSize: template.headerFontSize, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 10),
        buildDynamicHeaderFields(paper, template),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('Max Marks: ${paper.totalMarks}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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
  pw.Widget build(Paper paper, pw.ImageProvider? logoImage, PaperTemplate template) {
    final logo = logoImage != null
        ? pw.Container(
            width: 60,
            height: 60,
            margin: isLogoLeft ? const pw.EdgeInsets.only(right: 16) : const pw.EdgeInsets.only(left: 16),
            child: pw.Image(logoImage))
        : pw.SizedBox();

    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (isLogoLeft) logo,
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: isLogoLeft ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    paper.schoolName,
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    paper.title,
                    style: pw.TextStyle(fontSize: template.headerFontSize, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (!isLogoLeft) logo,
          ],
        ),
        pw.Row(
          mainAxisAlignment: isLogoLeft ? pw.MainAxisAlignment.end : pw.MainAxisAlignment.start,
          children: [
            pw.Text('Max Marks: ${paper.totalMarks}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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
  pw.Widget build(Paper paper, pw.ImageProvider? logoImage, PaperTemplate template) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: template.secondaryColor,
        border: pw.Border(bottom: pw.BorderSide(color: template.primaryColor, width: 2)),
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
                  pw.Text(
                    paper.title,
                    style: pw.TextStyle(fontSize: 16),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Max Marks: ${paper.totalMarks}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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
  pw.Widget build(Paper paper, pw.ImageProvider? logoImage, PaperTemplate template) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              paper.schoolName.toUpperCase(),
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey),
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
  pw.Widget build(Paper paper, pw.ImageProvider? logoImage, PaperTemplate template) {
    final layout = template.customLayout;
    if (layout == null) return pw.SizedBox();

    return pw.Container(
      height: layout.canvasHeight,
      width: 595.27 - 64, // A4 width minus margins (32 * 2)
      child: pw.Stack(
        children: layout.elements.map((el) {
          return pw.Positioned(
            left: el.x,
            top: el.y,
            child: _buildElement(el, paper, logoImage, template),
          );
        }).toList(),
      ),
    );
  }

  pw.Widget _buildElement(TemplateElement el, Paper paper, pw.ImageProvider? logoImage, PaperTemplate template) {
    final style = pw.TextStyle(
      fontSize: el.properties['fontSize']?.toDouble() ?? 12,
      fontWeight: el.properties['bold'] == true ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: el.properties['color'] != null ? PdfColor.fromInt(el.properties['color']) : PdfColors.black,
    );

    final alignment = _getPdfAlignment(el.properties['alignment']);

    switch (el.type) {
      case ElementType.schoolName:
        return pw.Container(
          width: el.width,
          alignment: alignment,
          child: pw.Text(paper.schoolName, style: style),
        );
      case ElementType.paperTitle:
        return pw.Container(
          width: el.width,
          alignment: alignment,
          child: pw.Text(paper.title, style: style),
        );
      case ElementType.logo:
        return logoImage != null
            ? pw.Container(
                width: el.width ?? 50,
                height: el.height ?? 50,
                child: pw.Image(logoImage),
              )
            : pw.SizedBox();
      case ElementType.maxMarks:
        return pw.Container(
          width: el.width,
          alignment: alignment,
          child: pw.Text('Max Marks: ${paper.totalMarks}', style: style),
        );
      case ElementType.headerFieldsBlock:
        return pw.Container(
          width: el.width ?? 300,
          child: buildDynamicHeaderFields(paper, template),
        );
      case ElementType.staticText:
        return pw.Container(
          width: el.width,
          alignment: alignment,
          child: pw.Text(el.content, style: style),
        );
      case ElementType.horizontalLine:
        return pw.Container(
          width: el.width ?? 100,
          height: 1,
          color: style.color,
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
}
