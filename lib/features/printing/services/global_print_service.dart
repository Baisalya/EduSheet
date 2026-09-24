import 'dart:io';

import 'package:printing/printing.dart';

import 'package:edusheet/features/printing/domain/print_document_source.dart';

/// Single platform boundary for all printing in EduSheet.
///
/// Windows uses the system printer UI exposed by the printing plugin. Android
/// hands the job to Android Print Service, which lets the OS choose installed
/// or network/cloud printer providers and their supported settings.
class GlobalPrintService {
  const GlobalPrintService();

  Future<bool> openSystemPrintDialog(PrintDocumentSource source) {
    return Printing.layoutPdf(
      name: source.pdfFileName,
      format: source.initialPageFormat,
      dynamicLayout: source.dynamicLayout,
      onLayout: source.build,
    );
  }

  /// Printer enumeration is useful on Windows for status/diagnostics. Android
  /// printer discovery belongs to the native Print Service UI, so we avoid
  /// presenting a second, incomplete printer picker there.
  Future<List<Printer>> discoverDesktopPrinters() async {
    if (!Platform.isWindows) return const <Printer>[];
    try {
      final printers = List<Printer>.of(await Printing.listPrinters());
      printers.sort((a, b) {
        if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return printers;
    } catch (_) {
      return const <Printer>[];
    }
  }
}
