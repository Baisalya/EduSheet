import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:edusheet/features/printing/domain/print_document_source.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:edusheet/features/word_converter/services/docx_pdf_renderer.dart';

/// Converts supported device files into the common print-source contract.
class FilePrintSourceFactory {
  const FilePrintSourceFactory._();

  static const Set<String> supportedExtensions = <String>{'.pdf', '.docx'};

  static bool supportsPath(String path) =>
      supportedExtensions.contains(p.extension(path).toLowerCase());

  static PrintDocumentSource fromPath(
    String path, {
    String? displayName,
  }) {
    final extension = p.extension(path).toLowerCase();
    final title = (displayName == null || displayName.trim().isEmpty)
        ? p.basename(path)
        : displayName.trim();

    return switch (extension) {
      '.pdf' => PrintDocumentSource.fixed(
        title: title,
        description: 'PDF selected from this device',
        load: () => File(path).readAsBytes(),
      ),
      '.docx' => PrintDocumentSource.fixed(
        title: title,
        description: 'Word document rendered by EduSheet for printing',
        load: () => _renderDocx(path),
      ),
      _ => throw UnsupportedError(
        'Printing is not available for $extension files.',
      ),
    };
  }

  static Future<Uint8List> _renderDocx(String path) async {
    final document = await DocxConversionParser.parse(File(path));
    if (!document.hasContent) {
      throw const FormatException(
        'No supported printable content was found in this Word document.',
      );
    }
    final bytes = await DocxPdfRenderer.render(document);
    return Uint8List.fromList(bytes);
  }
}
