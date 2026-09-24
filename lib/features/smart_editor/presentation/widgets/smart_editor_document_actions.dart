import 'package:flutter/material.dart';

/// Desktop Smart Editor action for opening/importing a Word document.
class SmartEditorDesktopOpenDocxButton extends StatelessWidget {
  const SmartEditorDesktopOpenDocxButton({
    super.key,
    required this.busy,
    required this.onOpen,
  });

  final bool busy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('smart-editor-open-docx'),
      tooltip: 'Open / import Word document (Ctrl+O)',
      onPressed: busy ? null : onOpen,
      icon: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.file_open_outlined),
    );
  }
}

/// Compact/mobile document actions used by Smart Editor.
///
/// Kept independent of the Quill editor so the Android action surface can be
/// certified deterministically without depending on cursor/ticker lifecycle.
class SmartEditorMobileDocumentMenu extends StatelessWidget {
  const SmartEditorMobileDocumentMenu({
    super.key,
    required this.fullMode,
    required this.busy,
    required this.onToggleMode,
    required this.onOpenDocx,
    required this.onExport,
    required this.onPrint,
    required this.onSave,
  });

  final bool fullMode;
  final bool busy;
  final VoidCallback onToggleMode;
  final VoidCallback onOpenDocx;
  final ValueChanged<String> onExport;
  final VoidCallback onPrint;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const Key('smart-editor-mobile-more'),
      tooltip: 'More document actions',
      enabled: !busy,
      icon: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        switch (value) {
          case 'mode':
            onToggleMode();
            break;
          case 'open-docx':
            onOpenDocx();
            break;
          case 'docx':
          case 'pdf':
            onExport(value);
            break;
          case 'print':
            onPrint();
            break;
          case 'save':
            onSave();
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'mode',
          child: Row(
            children: [
              Icon(
                fullMode
                    ? Icons.auto_awesome_rounded
                    : Icons.dashboard_customize_outlined,
              ),
              const SizedBox(width: 10),
              Text(fullMode ? 'Smart mode' : 'Full tools'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'open-docx',
          child: Row(
            children: [
              Icon(Icons.file_open_outlined),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Open / import Word (.docx)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'docx',
          child: Row(
            children: [
              Icon(Icons.description_outlined),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Export Word (.docx)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined),
              SizedBox(width: 10),
              Text('Export PDF'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'print',
          child: Row(
            children: [
              Icon(Icons.print_outlined),
              SizedBox(width: 10),
              Text('Print'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'save',
          child: Row(
            children: [
              Icon(Icons.save_outlined),
              SizedBox(width: 10),
              Text('Save now'),
            ],
          ),
        ),
      ],
    );
  }
}
