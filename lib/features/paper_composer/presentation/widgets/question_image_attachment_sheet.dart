import 'dart:io';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_math_text_field.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class QuestionImageAttachmentSheet extends StatefulWidget {
  final QuestionAttachment? initial;

  const QuestionImageAttachmentSheet({super.key, this.initial});

  static Future<QuestionAttachment?> show(
    BuildContext context, {
    QuestionAttachment? initial,
  }) {
    return showAdaptiveModalBottomSheet<QuestionAttachment>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => QuestionImageAttachmentSheet(initial: initial),
    );
  }

  @override
  State<QuestionImageAttachmentSheet> createState() =>
      _QuestionImageAttachmentSheetState();
}

class _QuestionImageAttachmentSheetState
    extends State<QuestionImageAttachmentSheet> {
  String? _path;
  late final TextEditingController _caption;
  late final TextEditingController _altText;
  String? _error;

  @override
  void initState() {
    super.initState();
    _path = widget.initial?.path;
    _caption = TextEditingController(text: widget.initial?.caption ?? '');
    _altText = TextEditingController(
      text: widget.initial?.alternativeText ?? '',
    );
  }

  @override
  void dispose() {
    _caption.dispose();
    _altText.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'gif'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    setState(() {
      _path = path;
      _error = null;
    });
  }

  void _save() {
    final path = _path?.trim() ?? '';
    if (path.isEmpty) {
      setState(() => _error = 'Choose an image first.');
      return;
    }
    Navigator.pop(
      context,
      QuestionAttachment(
        id: widget.initial?.id ?? const Uuid().v4(),
        kind: QuestionAttachmentKind.image,
        path: path,
        alternativeText: _altText.text.trim(),
        caption: _caption.text.trim(),
        mimeType: _mimeType(path),
        width: widget.initial?.width,
        height: widget.initial?.height,
      ),
    );
  }

  String? _mimeType(String path) {
    return switch (p.extension(path).toLowerCase()) {
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.gif' => 'image/gif',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = _path;
    final exists = path != null && File(path).existsSync();

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.initial == null ? 'Add image' : 'Edit image',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Use this for a photo, map, chart or scanned diagram. Geometry created with EduSheet still uses the dedicated Geometry tool.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      path == null ? 'Choose image' : 'Replace image',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  if (path != null) ...[
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: exists
                            ? Image.file(
                                File(path),
                                height: 190,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const SizedBox(
                                  height: 120,
                                  child: Center(
                                    child: Text('Image preview unavailable'),
                                  ),
                                ),
                              )
                            : const SizedBox(
                                height: 120,
                                child: Center(
                                  child: Text(
                                    'The selected image file is unavailable.',
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.basename(path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 14),
                  QuestionMathTextField(
                    controller: _caption,
                    decoration: const InputDecoration(
                      labelText: 'Caption (optional)',
                      hintText: 'Figure 1: Observe the diagram',
                    ),
                  ),
                  const SizedBox(height: 10),
                  QuestionMathTextField(
                    controller: _altText,
                    minLines: 2,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      alignLabelWithHint: true,
                      labelText: 'Accessibility description (optional)',
                      hintText:
                          'Describe the important information in the image.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Use image'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
