import 'dart:io';

import 'package:edusheet/features/document_reader/domain/models/document_model.dart';
import 'package:edusheet/features/document_reader/presentation/screens/file_preview_screen.dart';
import 'package:edusheet/features/word_converter/services/word_converter_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class WordConverterScreen extends StatefulWidget {
  const WordConverterScreen({super.key});

  @override
  State<WordConverterScreen> createState() => _WordConverterScreenState();
}

class _WordConverterScreenState extends State<WordConverterScreen> {
  bool _isConverting = false;
  File? _lastOutput;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Word Converter',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ConverterTile(
            icon: Icons.picture_as_pdf_outlined,
            color: Colors.redAccent,
            title: 'Word to PDF',
            subtitle: 'Pick a .docx file and save it as a PDF.',
            buttonLabel: 'Choose Word File',
            enabled: !_isConverting,
            onPressed: _convertDocxToPdf,
          ),
          const SizedBox(height: 16),
          _ConverterTile(
            icon: Icons.edit_document,
            color: Colors.teal,
            title: 'PDF to Word: Exact Look',
            subtitle:
                'Best match: save each PDF page exactly as it looks in Word.',
            buttonLabel: 'Choose PDF File',
            enabled: !_isConverting,
            onPressed: _convertPdfToDocxExact,
          ),
          const SizedBox(height: 16),
          _ConverterTile(
            icon: Icons.edit_note_outlined,
            color: Colors.blueGrey,
            title: 'PDF to Word: Editable Text',
            subtitle:
                'Extract selectable text and OCR scanned pages into editable Word text.',
            buttonLabel: 'Choose PDF File',
            enabled: !_isConverting,
            onPressed: _convertPdfToDocxEditable,
          ),
          const SizedBox(height: 16),
          _ConverterTile(
            icon: Icons.description_outlined,
            color: Colors.indigo,
            title: 'Text to Word',
            subtitle: 'Pick a .txt file and save it as a Word document.',
            buttonLabel: 'Choose Text File',
            enabled: !_isConverting,
            onPressed: _convertTextToDocx,
          ),
          const SizedBox(height: 24),
          if (_isConverting)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
          if (_lastOutput != null && !_isConverting)
            _OutputPanel(
              file: _lastOutput!,
              onOpen: () => _openInApp(_lastOutput!),
            ),
        ],
      ),
    );
  }

  Future<void> _convertDocxToPdf() async {
    final path = await _pickFile(['docx']);
    if (path == null) return;
    await _runConversion(() => WordConverterService.convertDocxToPdf(path));
  }

  Future<void> _convertPdfToDocxExact() async {
    final path = await _pickFile(['pdf']);
    if (path == null) return;
    await _runConversion(
      () => WordConverterService.convertPdfToDocxExact(path),
    );
  }

  Future<void> _convertPdfToDocxEditable() async {
    final path = await _pickFile(['pdf']);
    if (path == null) return;
    await _runConversion(() => WordConverterService.convertPdfToDocx(path));
  }

  Future<void> _convertTextToDocx() async {
    final path = await _pickFile(['txt']);
    if (path == null) return;
    await _runConversion(() => WordConverterService.convertTextToDocx(path));
  }

  Future<String?> _pickFile(List<String> extensions) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: false,
    );
    return result?.files.single.path;
  }

  Future<void> _runConversion(Future<File> Function() convert) async {
    setState(() => _isConverting = true);
    try {
      final output = await convert();
      if (!mounted) return;
      setState(() => _lastOutput = output);
      await _openInApp(output);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: ${output.path}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Conversion failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isConverting = false);
      }
    }
  }

  Future<void> _openInApp(File file) async {
    final stat = await file.stat();
    if (!mounted) return;

    final extension = p.extension(file.path).toLowerCase();
    final document = DocumentFile(
      name: p.basename(file.path),
      path: file.path,
      extension: extension,
      size: stat.size,
      lastModified: stat.modified,
      type: DocumentFile.getDocumentType(extension),
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FilePreviewScreen(document: document),
      ),
    );
  }
}

class _ConverterTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool enabled;
  final VoidCallback onPressed;

  const _ConverterTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: enabled ? onPressed : null,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutputPanel extends StatelessWidget {
  final File file;
  final VoidCallback onOpen;

  const _OutputPanel({required this.file, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              p.basename(file.path),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          IconButton(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open converted file',
          ),
        ],
      ),
    );
  }
}
