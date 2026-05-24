import 'package:pdf/widgets.dart' as pw;
import '../domain/models/omr_config.dart';

class OmrWidgetsBuilder {
  static List<pw.Widget> build(
    OmrConfig config, {
    pw.ImageProvider? logoImage,
  }) {
    return [
      _buildBranding(config, logoImage),
      pw.SizedBox(height: 10),
      _buildStudentInfo(config),
      pw.SizedBox(height: 20),
      _buildOmrGrid(config),
      _buildFooter(config),
    ];
  }

  static pw.Widget _buildBranding(
    OmrConfig config,
    pw.ImageProvider? logoImage,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (logoImage != null)
              pw.Container(width: 60, height: 60, child: pw.Image(logoImage))
            else
              pw.SizedBox(width: 60),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(
                    config.schoolName,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(config.examName, style: pw.TextStyle(fontSize: 16)),
                ],
              ),
            ),
            if (config.includeBarcode)
              pw.Container(
                width: 60,
                height: 60,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: config.barcodeData ?? 'EDUSHEET-OMR',
                  width: 60,
                  height: 60,
                ),
              )
            else
              pw.SizedBox(width: 60),
          ],
        ),
        pw.Divider(thickness: 1),
      ],
    );
  }

  static pw.Widget _buildStudentInfo(OmrConfig config) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            children: [
              pw.Expanded(child: _infoField('Student Name:')),
              if (config.includeSection) ...[
                pw.SizedBox(width: 20),
                pw.SizedBox(width: 100, child: _infoField('Section:')),
              ],
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              if (config.includeRollNumber) ...[
                pw.Expanded(child: _infoField('Roll Number:')),
                pw.SizedBox(width: 20),
              ],
              pw.Expanded(child: _infoField('Date:')),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoField(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.Container(
          height: 20,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildOmrGrid(OmrConfig config) {
    final totalQuestions = config.questionCount;

    // Calculate columns needed
    int actualCols = 4;
    if (totalQuestions <= 25) {
      actualCols = 1;
    } else if (totalQuestions <= 50) {
      actualCols = 2;
    } else if (totalQuestions <= 75) {
      actualCols = 3;
    }

    return pw.GridView(
      crossAxisCount: actualCols,
      childAspectRatio: 0.35,
      children: List.generate(totalQuestions, (index) {
        return _buildQuestionRow(index + 1, config.optionsIntValue);
      }),
    );
  }

  static pw.Widget _buildQuestionRow(int questionNumber, int optionsCount) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 22,
            child: pw.Text(
              '$questionNumber.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          ...List.generate(optionsCount, (i) {
            return pw.Container(
              width: 12,
              height: 12,
              margin: const pw.EdgeInsets.symmetric(horizontal: 1),
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                border: pw.Border.all(width: 0.7),
              ),
              child: pw.Center(
                child: pw.Text(
                  String.fromCharCode(65 + i),
                  style: const pw.TextStyle(fontSize: 6),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(OmrConfig config) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Invigilator\'s Signature: __________________',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            'Student\'s Signature: __________________',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }
}
