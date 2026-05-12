import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:open_filex/open_filex.dart';
import '../../domain/models/document_model.dart';

class FilePreviewScreen extends StatelessWidget {
  final DocumentFile document;

  const FilePreviewScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: Text(
          document.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => OpenFilex.open(document.path),
            tooltip: 'Open in External App',
          ),
        ],
      ),
      body: _buildPreviewer(context, isDark),
    );
  }

  Widget _buildPreviewer(BuildContext context, bool isDark) {
    switch (document.type) {
      case DocumentType.pdf:
        return SfPdfViewer.file(
          File(document.path),
          onDocumentLoadFailed: (details) => _buildErrorState(context, 'PDF Load Failed: ${details.description}'),
        );
      case DocumentType.word:
        if (document.extension == '.docx') {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: DocxView.file(
              File(document.path),
              config: DocxViewConfig(
                enableZoom: true,
              ),
            ),
          );
        } else {
          return _buildUnsupportedState(context, 'Internal preview only supports .docx files. Please open in an external app.');
        }
      case DocumentType.text:
        return FutureBuilder<String>(
          future: File(document.path).readAsString(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  snapshot.data!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              );
            } else if (snapshot.hasError) {
              return _buildErrorState(context, 'Failed to read text file');
            }
            return const Center(child: CircularProgressIndicator());
          },
        );
      default:
        return _buildUnsupportedState(context, 'In-app preview for ${document.extension.toUpperCase()} is coming soon. Use the external opener for now.');
    }
  }

  Widget _buildUnsupportedState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => OpenFilex.open(document.path),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open with External App'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(error, style: const TextStyle(color: Colors.redAccent)),
        ],
      ),
    );
  }
}
