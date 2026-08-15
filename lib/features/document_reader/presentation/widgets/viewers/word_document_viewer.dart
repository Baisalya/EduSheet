import 'dart:io';

import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/document_model.dart';

class WordDocumentViewer extends StatelessWidget {
  final DocumentFile document;

  const WordDocumentViewer({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final horizontalPadding = compact ? 8.0 : 24.0;
        final available = (constraints.maxWidth - horizontalPadding * 2)
            .clamp(320.0, 1400.0)
            .toDouble();
        final pageWidth = compact
            ? available
            : available.clamp(680.0, 860.0).toDouble();

        return ColoredBox(
          color: isDark ? const Color(0xFF15181D) : const Color(0xFFE8ECF2),
          child: DocxView.file(
            File(document.path),
            key: ValueKey('docx-${document.path}'),
            config: DocxViewConfig(
              enableZoom: true,
              minScale: 0.65,
              maxScale: 3.5,
              pageMode: DocxPageMode.paged,
              pageWidth: pageWidth,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: compact ? 8 : 16,
              ),
              backgroundColor: isDark
                  ? const Color(0xFF15181D)
                  : const Color(0xFFE8ECF2),
            ),
          ),
        );
      },
    );
  }
}
