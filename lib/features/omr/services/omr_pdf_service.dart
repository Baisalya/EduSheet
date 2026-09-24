import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:edusheet/features/pdf/services/pdf_export_theme_service.dart';
import 'package:edusheet/features/pdf/services/shaping/pdf_complex_text_service.dart';
import 'package:edusheet/features/printing/domain/print_document_source.dart';
import 'package:edusheet/features/printing/services/global_print_service.dart';
import '../domain/models/omr_config.dart';
import 'omr_widgets_builder.dart';

class OmrPdfService {
  static Future<Uint8List> generateBytes(OmrConfig config) async {
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

    return Uint8List.fromList(await pdf.save());
  }

  static Future<void> generateAndPreview(OmrConfig config) async {
    final title = config.examName.trim().isEmpty
        ? 'OMR Sheet'
        : '${config.examName.trim()} OMR Sheet';
    final source = PrintDocumentSource.fixed(
      title: title,
      description: 'EduSheet OMR sheet',
      load: () => generateBytes(config),
    );
    await const GlobalPrintService().openSystemPrintDialog(source);
  }
}
