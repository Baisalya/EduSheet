import 'dart:typed_data';

import 'package:pdf/pdf.dart';

typedef EduPrintDocumentBuilder = Future<Uint8List> Function(
  PdfPageFormat format,
);

/// A print-ready document that can be handed to the global EduSheet print UI.
///
/// Feature modules own document generation. The printing feature only owns
/// preview, printer discovery, and platform print dispatch, which keeps it
/// reusable across Smart Editor, question papers, OMR, and file preview.
class PrintDocumentSource {
  const PrintDocumentSource({
    required this.title,
    required this.build,
    this.description,
    this.initialPageFormat = PdfPageFormat.a4,
    this.dynamicLayout = false,
  });

  factory PrintDocumentSource.fixed({
    required String title,
    required Future<Uint8List> Function() load,
    String? description,
    PdfPageFormat initialPageFormat = PdfPageFormat.a4,
  }) {
    Future<Uint8List>? cachedBytes;
    return PrintDocumentSource(
      title: title,
      description: description,
      initialPageFormat: initialPageFormat,
      dynamicLayout: false,
      build: (_) {
        cachedBytes ??= load();
        return cachedBytes!;
      },
    );
  }

  final String title;
  final String? description;
  final PdfPageFormat initialPageFormat;

  /// True only when the source can genuinely rebuild its document for a page
  /// format requested by the printer driver.
  final bool dynamicLayout;
  final EduPrintDocumentBuilder build;

  String get pdfFileName {
    final trimmed = title.trim().isEmpty ? 'EduSheet document' : title.trim();
    return trimmed.toLowerCase().endsWith('.pdf') ? trimmed : '$trimmed.pdf';
  }
}
