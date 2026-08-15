import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../../domain/models/document_model.dart';

class UnsupportedDocumentViewer extends StatelessWidget {
  final DocumentFile document;

  const UnsupportedDocumentViewer({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final capability = document.capability;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.open_in_new, size: 64, color: Colors.blueGrey),
                  const SizedBox(height: 18),
                  Text(
                    capability.level == DocumentSupportLevel.externalOnly
                        ? 'Open with another app'
                        : capability.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    capability.description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: () => OpenFilex.open(document.path),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open externally'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
