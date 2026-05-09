import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/models/omr_config.dart';
import 'omr_widgets_builder.dart';

class OmrPdfService {
  static Future<void> generateAndPreview(OmrConfig config) async {
    final pdf = pw.Document();

    pw.ImageProvider? logoImage;
    if (config.schoolLogo != null) {
      final file = File(config.schoolLogo!);
      if (await file.exists()) {
        logoImage = pw.MemoryImage(await file.readAsBytes());
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => OmrWidgetsBuilder.build(config, logoImage: logoImage),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
