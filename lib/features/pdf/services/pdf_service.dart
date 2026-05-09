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

class PdfService {
  static Future<void> generateAndPreview(Paper paper) async {
    final pdf = pw.Document();

    pw.ImageProvider? logoImage;
    if (paper.schoolLogo != null) {
      final file = File(paper.schoolLogo!);
      if (await file.exists()) {
        logoImage = pw.MemoryImage(await file.readAsBytes());
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(paper, logoImage),
          ...paper.sections.map((section) => _buildSection(section)),
          if (paper.includeOmr) ..._buildOmrSheet(paper, logoImage),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static pw.Widget _buildHeader(Paper paper, pw.ImageProvider? logoImage) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (logoImage != null)
              pw.Container(width: 50, height: 50, child: pw.Image(logoImage))
            else
              pw.SizedBox(width: 50),
            pw.Column(
              children: [
                pw.Text(
                  paper.schoolName,
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  paper.title,
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(width: 50),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Time: 3 Hours'),
            pw.Text('Max Marks: ${paper.totalMarks}'),
          ],
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  static pw.Widget _buildSection(PaperSection section) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${section.prefix} ${section.title}'.trim(),
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        if (section.instruction != null && section.instruction!.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              'Instruction: ${section.instruction}',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 12),
            ),
          ),
        pw.Divider(),
        ...section.questions.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final q = entry.value;
          return _buildQuestion(idx, q);
        }),
      ],
    );
  }

  static pw.Widget _buildQuestion(int index, Question q) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: 25, child: pw.Text('$index.')),
              pw.Expanded(
                child: _parseRichTextToPdf(q.text),
              ),
              pw.SizedBox(width: 40, child: pw.Text('[${q.marks}]', textAlign: pw.TextAlign.right)),
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
                      children: [
                        pw.Text('$optIdx) '),
                        pw.Text(optEntry.value.text),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          if (q.type == QuestionType.fillInTheBlanks)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 25, top: 4),
              child: pw.Text('Ans: ________________________'),
            ),
        ],
      ),
    );
  }

  static pw.Widget _parseRichTextToPdf(String text) {
    try {
      if (text.startsWith('[') || text.startsWith('{')) {
        final List<dynamic> deltaJson = jsonDecode(text);
        final converter = QuillDeltaToHtmlConverter(deltaJson.cast<Map<String, dynamic>>());
        final html = converter.convert();
        final document = html_parser.parse(html);
        return pw.RichText(text: pw.TextSpan(children: _domToTextSpans(document.body!)));
      }
    } catch (e) {
      // Fallback to plain text
    }
    return pw.Text(text);
  }

  static List<pw.InlineSpan> _domToTextSpans(dom.Node node) {
    List<pw.InlineSpan> spans = [];

    for (var child in node.nodes) {
      if (child is dom.Text) {
        spans.add(pw.TextSpan(text: child.text));
      } else if (child is dom.Element) {
        pw.TextStyle style = const pw.TextStyle();
        if (child.localName == 'strong' || child.localName == 'b') {
          style = style.copyWith(fontWeight: pw.FontWeight.bold);
        } else if (child.localName == 'em' || child.localName == 'i') {
          style = style.copyWith(fontStyle: pw.FontStyle.italic);
        } else if (child.localName == 'u') {
          style = style.copyWith(decoration: pw.TextDecoration.underline);
        }

        spans.add(pw.TextSpan(
          text: child.nodes.isEmpty ? child.text : null,
          style: style,
          children: child.nodes.isNotEmpty ? _domToTextSpans(child) : null,
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
