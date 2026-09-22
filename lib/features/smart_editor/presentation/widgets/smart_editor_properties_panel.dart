import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class SmartEditorPropertiesPanel extends StatelessWidget {
  const SmartEditorPropertiesPanel({
    super.key,
    required this.controller,
    required this.document,
    required this.onLayout,
    required this.onHeaderFooter,
    required this.onBorderChanged,
    required this.onInsertPageBreak,
    required this.onInsertSectionBreak,
  });

  final QuillController controller;
  final SmartDocument document;
  final VoidCallback onLayout;
  final VoidCallback onHeaderFooter;
  final ValueChanged<SmartDocumentPageBorderStyle> onBorderChanged;
  final VoidCallback onInsertPageBreak;
  final VoidCallback onInsertSectionBreak;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        key: const Key('smart-editor-properties-panel'),
        width: 310,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Properties',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _PanelSection(
              title: 'Page',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    key: const Key('smart-editor-properties-layout'),
                    onPressed: onLayout,
                    icon: const Icon(Icons.straighten_rounded),
                    label: const Text('Page layout'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('smart-editor-properties-header-footer'),
                    onPressed: onHeaderFooter,
                    icon: const Icon(Icons.view_agenda_outlined),
                    label: const Text('Header & footer'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Page border',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<SmartDocumentPageBorderStyle>(
                    key: const Key('smart-editor-properties-border'),
                    initialValue: document.pageLayout.borderStyle,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: SmartDocumentPageBorderStyle.none,
                        child: Text('None'),
                      ),
                      DropdownMenuItem(
                        value: SmartDocumentPageBorderStyle.subtle,
                        child: Text('Subtle'),
                      ),
                      DropdownMenuItem(
                        value: SmartDocumentPageBorderStyle.solid,
                        child: Text('Solid'),
                      ),
                      DropdownMenuItem(
                        value: SmartDocumentPageBorderStyle.doubleLine,
                        child: Text('Double line'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) onBorderChanged(value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _PanelSection(
              title: 'Paragraph',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _FormatButton(
                        tooltip: 'Align left',
                        icon: Icons.format_align_left_rounded,
                        onPressed: () => controller.formatSelection(
                          Attribute.leftAlignment,
                        ),
                      ),
                      _FormatButton(
                        tooltip: 'Center',
                        icon: Icons.format_align_center_rounded,
                        onPressed: () => controller.formatSelection(
                          Attribute.centerAlignment,
                        ),
                      ),
                      _FormatButton(
                        tooltip: 'Align right',
                        icon: Icons.format_align_right_rounded,
                        onPressed: () => controller.formatSelection(
                          Attribute.rightAlignment,
                        ),
                      ),
                      _FormatButton(
                        tooltip: 'Justify',
                        icon: Icons.format_align_justify_rounded,
                        onPressed: () => controller.formatSelection(
                          Attribute.justifyAlignment,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _FormatButton(
                        tooltip: 'Bullets',
                        icon: Icons.format_list_bulleted_rounded,
                        onPressed: () => _toggle(controller, Attribute.ul),
                      ),
                      _FormatButton(
                        tooltip: 'Numbered list',
                        icon: Icons.format_list_numbered_rounded,
                        onPressed: () => _toggle(controller, Attribute.ol),
                      ),
                      _FormatButton(
                        key: const Key('smart-editor-indent-less'),
                        tooltip: 'Decrease indent',
                        icon: Icons.format_indent_decrease_rounded,
                        onPressed: () => controller.indentSelection(false),
                      ),
                      _FormatButton(
                        key: const Key('smart-editor-indent-more'),
                        tooltip: 'Increase indent',
                        icon: Icons.format_indent_increase_rounded,
                        onPressed: () => controller.indentSelection(true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Line spacing is available directly in the editor ribbon.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _PanelSection(
              title: 'Reusable styles',
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    key: const Key('smart-editor-style-normal'),
                    label: const Text('Normal'),
                    onPressed: () => controller.formatSelection(
                      Attribute.clone(Attribute.h1, null),
                    ),
                  ),
                  ActionChip(
                    key: const Key('smart-editor-style-title'),
                    label: const Text('Title'),
                    onPressed: () => controller.formatSelection(Attribute.h1),
                  ),
                  ActionChip(
                    key: const Key('smart-editor-style-heading1'),
                    label: const Text('Heading 1'),
                    onPressed: () => controller.formatSelection(Attribute.h2),
                  ),
                  ActionChip(
                    key: const Key('smart-editor-style-heading2'),
                    label: const Text('Heading 2'),
                    onPressed: () => controller.formatSelection(Attribute.h3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _PanelSection(
              title: 'Breaks',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    key: const Key('smart-editor-page-break'),
                    onPressed: onInsertPageBreak,
                    icon: const Icon(Icons.insert_page_break_outlined),
                    label: const Text('Insert page break'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('smart-editor-section-break'),
                    onPressed: onInsertSectionBreak,
                    icon: const Icon(Icons.segment_rounded),
                    label: const Text('Insert section break'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _toggle(QuillController controller, Attribute attribute) {
    final current = controller.getSelectionStyle().attributes[attribute.key];
    final active = current?.value == attribute.value;
    controller.formatSelection(
      active ? Attribute.clone(attribute, null) : attribute,
    );
  }
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}
