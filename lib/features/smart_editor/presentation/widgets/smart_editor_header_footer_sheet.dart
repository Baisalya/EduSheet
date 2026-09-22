import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:flutter/material.dart';

class SmartEditorHeaderFooterResult {
  final SmartDocumentHeaderFooter header;
  final SmartDocumentHeaderFooter footer;

  const SmartEditorHeaderFooterResult({
    required this.header,
    required this.footer,
  });
}

class SmartEditorHeaderFooterSheet extends StatefulWidget {
  const SmartEditorHeaderFooterSheet({
    super.key,
    required this.header,
    required this.footer,
  });

  final SmartDocumentHeaderFooter header;
  final SmartDocumentHeaderFooter footer;

  static Future<SmartEditorHeaderFooterResult?> show(
    BuildContext context, {
    required SmartDocumentHeaderFooter header,
    required SmartDocumentHeaderFooter footer,
  }) {
    return showModalBottomSheet<SmartEditorHeaderFooterResult>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SmartEditorHeaderFooterSheet(
        header: header,
        footer: footer,
      ),
    );
  }

  @override
  State<SmartEditorHeaderFooterSheet> createState() =>
      _SmartEditorHeaderFooterSheetState();
}

class _SmartEditorHeaderFooterSheetState
    extends State<SmartEditorHeaderFooterSheet> {
  late bool _headerEnabled;
  late bool _footerEnabled;
  late bool _headerDivider;
  late bool _footerDivider;
  late SmartDocumentHeaderFooterAlignment _headerAlignment;
  late SmartDocumentHeaderFooterAlignment _footerAlignment;
  late final TextEditingController _headerController;
  late final TextEditingController _footerController;

  @override
  void initState() {
    super.initState();
    _headerEnabled = widget.header.enabled;
    _footerEnabled = widget.footer.enabled;
    _headerDivider = widget.header.showDivider;
    _footerDivider = widget.footer.showDivider;
    _headerAlignment = widget.header.alignment;
    _footerAlignment = widget.footer.alignment;
    _headerController = TextEditingController(text: widget.header.text);
    _footerController = TextEditingController(text: widget.footer.text);
  }

  @override
  void dispose() {
    _headerController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Header & footer',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Type any text you want. Nothing here is tied to Subject, Class, Time or Marks.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            _HeaderFooterEditor(
              key: const Key('smart-editor-header-editor'),
              label: 'Header',
              enabled: _headerEnabled,
              controller: _headerController,
              alignment: _headerAlignment,
              showDivider: _headerDivider,
              onEnabledChanged: (value) {
                setState(() => _headerEnabled = value);
              },
              onAlignmentChanged: (value) {
                setState(() => _headerAlignment = value);
              },
              onDividerChanged: (value) {
                setState(() => _headerDivider = value);
              },
            ),
            const SizedBox(height: 18),
            _HeaderFooterEditor(
              key: const Key('smart-editor-footer-editor'),
              label: 'Footer',
              enabled: _footerEnabled,
              controller: _footerController,
              alignment: _footerAlignment,
              showDivider: _footerDivider,
              onEnabledChanged: (value) {
                setState(() => _footerEnabled = value);
              },
              onAlignmentChanged: (value) {
                setState(() => _footerAlignment = value);
              },
              onDividerChanged: (value) {
                setState(() => _footerDivider = value);
              },
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              key: const Key('smart-editor-header-footer-apply'),
              onPressed: () => Navigator.pop(
                context,
                SmartEditorHeaderFooterResult(
                  header: SmartDocumentHeaderFooter(
                    enabled: _headerEnabled,
                    text: _headerController.text,
                    alignment: _headerAlignment,
                    showDivider: _headerDivider,
                  ),
                  footer: SmartDocumentHeaderFooter(
                    enabled: _footerEnabled,
                    text: _footerController.text,
                    alignment: _footerAlignment,
                    showDivider: _footerDivider,
                  ),
                ),
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Apply header & footer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderFooterEditor extends StatelessWidget {
  const _HeaderFooterEditor({
    super.key,
    required this.label,
    required this.enabled,
    required this.controller,
    required this.alignment,
    required this.showDivider,
    required this.onEnabledChanged,
    required this.onAlignmentChanged,
    required this.onDividerChanged,
  });

  final String label;
  final bool enabled;
  final TextEditingController controller;
  final SmartDocumentHeaderFooterAlignment alignment;
  final bool showDivider;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<SmartDocumentHeaderFooterAlignment> onAlignmentChanged;
  final ValueChanged<bool> onDividerChanged;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(enabled ? 'Shown on the page' : 'Hidden'),
              value: enabled,
              onChanged: onEnabledChanged,
            ),
            AnimatedOpacity(
              opacity: enabled ? 1 : 0.45,
              duration: const Duration(milliseconds: 160),
              child: IgnorePointer(
                ignoring: !enabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: controller,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: '$label text',
                        hintText: label == 'Header'
                            ? 'School name, exam title, class…'
                            : 'Notes, signature text, document code…',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<SmartDocumentHeaderFooterAlignment>(
                      segments: const [
                        ButtonSegment(
                          value: SmartDocumentHeaderFooterAlignment.left,
                          icon: Icon(Icons.format_align_left_rounded),
                          label: Text('Left'),
                        ),
                        ButtonSegment(
                          value: SmartDocumentHeaderFooterAlignment.center,
                          icon: Icon(Icons.format_align_center_rounded),
                          label: Text('Center'),
                        ),
                        ButtonSegment(
                          value: SmartDocumentHeaderFooterAlignment.right,
                          icon: Icon(Icons.format_align_right_rounded),
                          label: Text('Right'),
                        ),
                      ],
                      selected: {alignment},
                      onSelectionChanged: (selection) {
                        onAlignmentChanged(selection.first);
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Divider line'),
                      subtitle: Text(
                        label == 'Header'
                            ? 'Show a line below the header'
                            : 'Show a line above the footer',
                      ),
                      value: showDivider,
                      onChanged: (value) => onDividerChanged(value ?? false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
