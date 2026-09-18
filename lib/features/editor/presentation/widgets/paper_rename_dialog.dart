import 'package:flutter/material.dart';

Future<String?> showPaperRenameDialog(
  BuildContext context, {
  required String initialTitle,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _PaperRenameDialog(initialTitle: initialTitle),
  );
}

class _PaperRenameDialog extends StatefulWidget {
  const _PaperRenameDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_PaperRenameDialog> createState() => _PaperRenameDialogState();
}

class _PaperRenameDialogState extends State<_PaperRenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final clean = _controller.text.trim();
    if (clean.isEmpty) return;
    Navigator.of(context).pop(clean);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename paper'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 120,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Paper name',
          hintText: 'e.g. Class 8 Mathematics Test',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Rename')),
      ],
    );
  }
}
