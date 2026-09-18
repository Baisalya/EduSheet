import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:edusheet/features/pdf/services/pdf_export_theme_service.dart';
import 'package:edusheet/features/pdf/services/shaping/pdf_complex_text_service.dart';
import '../domain/models/omr_config.dart';
import 'omr_widgets_builder.dart';

class OmrPdfService {
  static Future<void> generateAndPreview(OmrConfig config) async {
    final semanticText = '${config.schoolName} ${config.examName}';
    final requiresUnicode = semanticText.runes.any((rune) => rune > 0x7F);
    if (PdfComplexTextService.containsComplexScript(semanticText)) {
      await PdfComplexTextService.ensureInitialized();
    }
    final theme = await PdfExportThemeService.loadTheme(
      requireUnicode: requiresUnicode,
    );
    final pdf = pw.Document(theme: theme);

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
        build: (context) =>
            OmrWidgetsBuilder.build(config, logoImage: logoImage),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
