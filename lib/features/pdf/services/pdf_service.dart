import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';

class PdfService {
  static Future<void> generateAndPreview(Paper paper) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(paper.title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          ...paper.sections.map((section) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 20),
                pw.Text(section.title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                ...section.questions.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final q = entry.value;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Q$idx. ${q.text}'),
                        if (q.options.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 20, top: 4),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: q.options.asMap().entries.map((optEntry) {
                                final optIdx = String.fromCharCode(65 + optEntry.key);
                                return pw.Text('$optIdx) ${optEntry.value}');
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            );
          }).toList(),
          if (paper.includeOmr) ...[
            pw.NewPage(),
            pw.Header(level: 1, child: pw.Text('OMR Answer Sheet')),
            pw.Text('Please bubble in your answers below:'),
            pw.SizedBox(height: 20),
            pw.GridView(
              crossAxisCount: 2,
              childAspectRatio: 0.2,
              children: List.generate(20, (index) {
                return pw.Row(
                  children: [
                    pw.Text('${index + 1}. '),
                    ...List.generate(4, (i) => pw.Container(
                      width: 15,
                      height: 15,
                      margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(),
                      ),
                      child: pw.Center(child: pw.Text(String.fromCharCode(65 + i), style: const pw.TextStyle(fontSize: 8))),
                    )),
                  ],
                );
              }),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
