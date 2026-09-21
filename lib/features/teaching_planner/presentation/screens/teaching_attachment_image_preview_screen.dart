import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

class TeachingAttachmentImagePreviewScreen extends StatelessWidget {
  const TeachingAttachmentImagePreviewScreen({
    super.key,
    required this.file,
    required this.title,
  });

  final File file;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Open in another app',
            onPressed: () => _openExternally(context),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('This image could not be previewed in EduSheet.'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openExternally(BuildContext context) async {
    final result = await OpenFilex.open(file.path);
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
