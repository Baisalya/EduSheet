import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'dart:convert';
import 'dart:io';
import 'package:edusheet/features/omr/domain/models/omr_config.dart';
import 'package:edusheet/features/omr/services/omr_widgets_builder.dart';

import 'package:edusheet/features/pdf/domain/models/paper_template.dart';

class PdfService {
  static Future<pw.ThemeData> _loadTheme() async {
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final mathFont = await PdfGoogleFonts.notoSansMathRegular();
    final symbols2Font = await PdfGoogleFonts.notoSansSymbols2Regular();
    final devanagariFont = await PdfGoogleFonts.notoSansDevanagariRegular();
    final odiaFont = await PdfGoogleFonts.notoSansOriyaRegular();
    final bengaliFont = await PdfGoogleFonts.notoSansBengaliRegular();
    final tamilFont = await PdfGoogleFonts.notoSansTamilRegular();
    final teluguFont = await PdfGoogleFonts.notoSansTeluguRegular();
    final kannadaFont = await PdfGoogleFonts.notoSansKannadaRegular();
    final gujaratiFont = await PdfGoogleFonts.notoSansGujaratiRegular();
    final malayalamFont = await PdfGoogleFonts.notoSansMalayalamRegular();
    final gurmukhiFont = await PdfGoogleFonts.notoSansGurmukhiRegular();
    final arabicFont = await PdfGoogleFonts.notoSansArabicRegular();
    final cjkFont = await PdfGoogleFonts.notoSansJPRegular();

    return pw.ThemeData.withFont(
      base: baseFont,
      fontFallback: [
        mathFont,
        symbols2Font,
        devanagariFont,
        odiaFont,
        bengaliFont,
        tamilFont,
        teluguFont,
        kannadaFont,
        gujaratiFont,
        malayalamFont,
        gurmukhiFont,
        arabicFont,
        cjkFont,
      ],
    );
  }

  static Future<void> generateAndPreview(Paper paper) async {
    final theme = await _loadTheme();
    final pdf = pw.Document(theme: theme);
    final template = PaperTemplate.predefinedTemplates.firstWhere(
      (t) => t.id == paper.templateId,
      orElse: () => PaperTemplate.predefinedTemplates.first,
    );

    pw.ImageProvider? logoImage;
    if (paper.schoolLogo != null) {
      final file = File(paper.schoolLogo!);
      if (await file.exists()) {
        logoImage = pw.MemoryImage(await file.readAsBytes());
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          buildBackground: (context) {
            if (template.hasBorder) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Container(
                  margin: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: template.primaryColor, width: 1),
                  ),
                ),
              );
            }
            return pw.SizedBox();
          },
        ),
        build: (context) => [
          _buildHeader(paper, logoImage, template),
          ...paper.sections.map((section) => _buildSection(section, template)),
          if (paper.includeOmr) ..._buildOmrSheet(paper, logoImage),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static pw.Widget _buildHeader(Paper paper, pw.ImageProvider? logoImage, PaperTemplate template) {
    final headerFieldsWidget = _buildDynamicHeaderFields(paper, template);

    if (template.type == TemplateType.coaching) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        color: template.secondaryColor,
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
                    pw.Text('Max Marks: ${paper.totalMarks}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            headerFieldsWidget,
          ],
        ),
      );
    }

    if (template.type == TemplateType.cute) {
      return pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              if (logoImage != null)
                pw.Container(width: 40, height: 40, child: pw.Image(logoImage)),
              pw.SizedBox(width: 10),
          pw.Text(
            paper.schoolName,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: template.primaryColor),
          ),
        ],
      ),
      pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 8),
        padding: const pw.EdgeInsets.all(4),
        decoration: pw.BoxDecoration(
          color: template.secondaryColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Text(
          paper.title,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
          headerFieldsWidget,
          pw.Divider(color: template.primaryColor),
        ],
      );
    }

    // Default / School / Board
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: template.centeredHeader ? pw.MainAxisAlignment.center : pw.MainAxisAlignment.spaceBetween,
          children: [
            if (logoImage != null && !template.centeredHeader)
              pw.Container(width: 50, height: 50, child: pw.Image(logoImage)),
            pw.Column(
              children: [
                if (logoImage != null && template.centeredHeader)
                  pw.Container(width: 50, height: 50, child: pw.Image(logoImage)),
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
            if (!template.centeredHeader) pw.SizedBox(width: 50),
          ],
        ),
        pw.SizedBox(height: 10),
        headerFieldsWidget,
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

  static pw.Widget _buildDynamicHeaderFields(Paper paper, PaperTemplate template) {
    if (paper.headerFields.isEmpty) return pw.SizedBox();

    // Group fields in rows of 2 or 3 depending on length
    List<List<PaperHeaderField>> rows = [];
    for (var i = 0; i < paper.headerFields.length; i += 2) {
      rows.add(paper.headerFields.sublist(i, i + 2 > paper.headerFields.length ? paper.headerFields.length : i + 2));
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
                      pw.TextSpan(text: '${field.label}: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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

  static pw.Widget _buildSection(PaperSection section, PaperTemplate template) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 20),
        if (section.showTitle || section.prefix.isNotEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: template.type == TemplateType.coaching
                ? pw.BoxDecoration(color: template.secondaryColor)
                : null,
            child: pw.Text(
              '${section.prefix} ${section.showTitle ? section.title : ""}'.trim(),
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: template.type == TemplateType.coaching ? template.primaryColor : PdfColors.black,
              ),
            ),
          ),
        if (section.instruction != null && section.instruction!.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              'Instruction: ${section.instruction}',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 12),
            ),
          ),
        if (section.showDivider) pw.Divider(),
        ...section.questions.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final q = entry.value;
          return _buildQuestion(idx, q, template);
        }),
      ],
    );
  }

  static pw.Widget _buildQuestion(int index, Question q, PaperTemplate template) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: 25, child: pw.Text('$index.', style: pw.TextStyle(fontSize: template.questionFontSize, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(
                child: _parseRichTextToPdf(q.text, template.questionFontSize),
              ),
              pw.SizedBox(width: 40, child: pw.Text('[${q.marks}]', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: template.questionFontSize, fontWeight: pw.FontWeight.bold))),
            ],
          ),
          if (q.type == QuestionType.mcq)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 25, top: 4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: q.options.asMap().entries.map((optEntry) {
                  final optIdx = String.fromCharCode(65 + optEntry.key);
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('$optIdx) ', style: pw.TextStyle(fontSize: template.questionFontSize)),
                        pw.Expanded(child: pw.Text(optEntry.value.text, style: pw.TextStyle(fontSize: template.questionFontSize))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          if (q.type == QuestionType.fillInTheBlanks)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 25, top: 4),
              child: pw.Text('Ans: ________________________', style: pw.TextStyle(fontSize: template.questionFontSize)),
            ),
        ],
      ),
    );
  }

  static pw.Widget _parseRichTextToPdf(String text, double fontSize) {
    try {
      if (text.startsWith('[') || text.startsWith('{')) {
        final List<dynamic> deltaJson = jsonDecode(text);
        final converter = QuillDeltaToHtmlConverter(deltaJson.cast<Map<String, dynamic>>());
        final html = converter.convert();
        final document = html_parser.parse(html);
        return pw.RichText(text: pw.TextSpan(children: _domToTextSpans(document.body!, fontSize)));
      }
    } catch (e) {
      // Fallback to plain text
    }
    return pw.Text(text, style: pw.TextStyle(fontSize: fontSize));
  }

  static List<pw.InlineSpan> _domToTextSpans(dom.Node node, double fontSize) {
    List<pw.InlineSpan> spans = [];

    for (var child in node.nodes) {
      if (child is dom.Text) {
        if (child.text.trim().isNotEmpty) {
          spans.add(pw.TextSpan(text: child.text, style: pw.TextStyle(fontSize: fontSize)));
        }
      } else if (child is dom.Element) {
        pw.TextStyle style = pw.TextStyle(fontSize: fontSize);
        if (child.localName == 'strong' || child.localName == 'b') {
          style = style.copyWith(fontWeight: pw.FontWeight.bold);
        } else if (child.localName == 'em' || child.localName == 'i') {
          style = style.copyWith(fontStyle: pw.FontStyle.italic);
        } else if (child.localName == 'u') {
          style = style.copyWith(decoration: pw.TextDecoration.underline);
        }

        spans.add(pw.TextSpan(
          text: child.nodes.isEmpty ? (child.text.isNotEmpty ? child.text : null) : null,
          style: style,
          children: child.nodes.isNotEmpty ? _domToTextSpans(child, fontSize) : null,
        ));
      }
    }
    return spans;
  }

  static List<pw.Widget> _buildOmrSheet(Paper paper, pw.ImageProvider? logoImage) {
    int totalQuestions = 0;
    for (var section in paper.sections) {
      totalQuestions += section.questions.length;
    }
    
    if (totalQuestions == 0) totalQuestions = 20;

    final config = OmrConfig(
      schoolName: paper.schoolName,
      examName: paper.title,
      questionCount: totalQuestions,
      includeBarcode: true,
      barcodeData: paper.id,
    );

    return [
      pw.NewPage(),
      ...OmrWidgetsBuilder.build(config, logoImage: logoImage),
    ];
  }
}
