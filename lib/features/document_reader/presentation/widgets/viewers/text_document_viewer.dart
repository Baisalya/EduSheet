import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../domain/models/document_model.dart';

class TextDocumentViewer extends StatefulWidget {
  final DocumentFile document;

  const TextDocumentViewer({super.key, required this.document});

  @override
  State<TextDocumentViewer> createState() => _TextDocumentViewerState();
}

class _TextDocumentViewerState extends State<TextDocumentViewer> {
  static const int _maxLines = 250000;
  late Future<_TextPreviewData> _future;
  double _fontScale = 1;

  @override
  void initState() {
    super.initState();
    _future = _loadText();
  }

  @override
  void didUpdateWidget(covariant TextDocumentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.path != widget.document.path) {
      _future = _loadText();
    }
  }

  Future<_TextPreviewData> _loadText() async {
    final lines = <String>[];
    var truncated = false;
    await for (final line in File(widget.document.path)
        .openRead()
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())) {
      if (lines.length >= _maxLines) {
        truncated = true;
        break;
      }
      lines.add(line);
    }
    return _TextPreviewData(lines: lines, truncated: truncated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<_TextPreviewData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to read this text file.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Smaller text',
                    onPressed: _fontScale > 0.75
                        ? () => setState(() => _fontScale -= 0.1)
                        : null,
                    icon: const Icon(Icons.text_decrease),
                  ),
                  Text(
                    '${(_fontScale * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    tooltip: 'Larger text',
                    onPressed: _fontScale < 1.8
                        ? () => setState(() => _fontScale += 0.1)
                        : null,
                    icon: const Icon(Icons.text_increase),
                  ),
                  const Spacer(),
                  if (data.truncated)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Tooltip(
                        message:
                            'Preview stopped after 250,000 lines to keep the app responsive.',
                        child: Icon(Icons.info_outline, size: 18),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                key: ValueKey('text-${widget.document.path}'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: data.lines.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: SelectableText(
                      data.lines[index].isEmpty ? ' ' : data.lines[index],
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13.5 * _fontScale,
                        height: 1.45,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TextPreviewData {
  final List<String> lines;
  final bool truncated;

  const _TextPreviewData({required this.lines, required this.truncated});
}
