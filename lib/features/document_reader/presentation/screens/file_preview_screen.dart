import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../domain/models/document_model.dart';
import '../widgets/viewers/pdf_document_viewer.dart';
import '../widgets/viewers/presentation_document_viewer.dart';
import '../widgets/viewers/spreadsheet_document_viewer.dart';
import '../widgets/viewers/text_document_viewer.dart';
import '../widgets/viewers/unsupported_document_viewer.dart';
import '../widgets/viewers/word_document_viewer.dart';

class FilePreviewScreen extends StatelessWidget {
  final DocumentFile document;

  const FilePreviewScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        foregroundColor: scheme.onSurface,
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              document.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${document.displayExtension} • ${document.sizeString}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open in another app',
            onPressed: () => _openExternally(context),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: Column(
        children: [
          _DocumentCapabilityStrip(document: document),
          Expanded(child: _DocumentViewerHost(document: document)),
        ],
      ),
    );
  }

  Future<void> _openExternally(BuildContext context) async {
    final result = await OpenFilex.open(document.path);
    if (!context.mounted || result.type == ResultType.done) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message.isEmpty
              ? 'No compatible external app was found.'
              : result.message,
        ),
      ),
    );
  }
}

class _DocumentViewerHost extends StatelessWidget {
  final DocumentFile document;

  const _DocumentViewerHost({required this.document});

  @override
  Widget build(BuildContext context) {
    if (!document.canPreview) {
      return UnsupportedDocumentViewer(document: document);
    }

    switch (document.extension) {
      case '.pdf':
        return PdfDocumentViewer(document: document);
      case '.docx':
        return WordDocumentViewer(document: document);
      case '.xlsx':
      case '.csv':
        return SpreadsheetDocumentViewer(document: document);
      case '.pptx':
        return PresentationDocumentViewer(document: document);
      case '.txt':
        return TextDocumentViewer(document: document);
      default:
        return UnsupportedDocumentViewer(document: document);
    }
  }
}

class _DocumentCapabilityStrip extends StatelessWidget {
  final DocumentFile document;

  const _DocumentCapabilityStrip({required this.document});

  @override
  Widget build(BuildContext context) {
    final capability = document.capability;
    final scheme = Theme.of(context).colorScheme;
    final color = _colorFor(document.type);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the strip's actual allocation rather than the outer MediaQuery.
        // This keeps the capability chrome responsive inside split panes,
        // Android free-form windows, resizable desktop panes and widget tests.
        final compact = constraints.maxWidth < 650;
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_iconFor(document.type), size: 17, color: color),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      capability.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!compact)
                      Text(
                        capability.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              ),
              if (document.originalUri != null)
                Tooltip(
                  message: 'Opened from another Android app or file manager',
                  child: Icon(
                    Icons.mobile_friendly,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Color _colorFor(DocumentType type) {
    return switch (type) {
      DocumentType.pdf => Colors.redAccent,
      DocumentType.word => Colors.blue,
      DocumentType.excel => Colors.green,
      DocumentType.powerpoint => Colors.deepOrange,
      DocumentType.text => Colors.blueGrey,
      DocumentType.other => Colors.blueGrey,
    };
  }

  IconData _iconFor(DocumentType type) {
    return switch (type) {
      DocumentType.pdf => Icons.picture_as_pdf,
      DocumentType.word => Icons.description,
      DocumentType.excel => Icons.table_chart,
      DocumentType.powerpoint => Icons.slideshow,
      DocumentType.text => Icons.text_snippet,
      DocumentType.other => Icons.insert_drive_file,
    };
  }
}
