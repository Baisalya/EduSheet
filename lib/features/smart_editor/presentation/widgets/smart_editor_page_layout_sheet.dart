import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:flutter/material.dart';

class SmartEditorPageLayoutSheet extends StatefulWidget {
  const SmartEditorPageLayoutSheet({
    super.key,
    required this.initial,
  });

  final SmartDocumentPageLayout initial;

  static Future<SmartDocumentPageLayout?> show(
    BuildContext context,
    SmartDocumentPageLayout initial,
  ) {
    return showModalBottomSheet<SmartDocumentPageLayout>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SmartEditorPageLayoutSheet(initial: initial),
    );
  }

  @override
  State<SmartEditorPageLayoutSheet> createState() =>
      _SmartEditorPageLayoutSheetState();
}

class _SmartEditorPageLayoutSheetState
    extends State<SmartEditorPageLayoutSheet> {
  late SmartDocumentPageSize _size;
  late SmartDocumentOrientation _orientation;
  late SmartDocumentMarginPreset _margins;
  late SmartDocumentPageBorderStyle _borderStyle;
  late double _topMargin;
  late double _rightMargin;
  late double _bottomMargin;
  late double _leftMargin;

  @override
  void initState() {
    super.initState();
    _size = widget.initial.pageSize;
    _orientation = widget.initial.orientation;
    _margins = widget.initial.marginPreset;
    _borderStyle = widget.initial.borderStyle;
    _topMargin = widget.initial.customTopMargin;
    _rightMargin = widget.initial.customRightMargin;
    _bottomMargin = widget.initial.customBottomMargin;
    _leftMargin = widget.initial.customLeftMargin;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
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
              'Page layout',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'These settings belong to this document. They do not force any paper or question structure.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Text('Page size', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<SmartDocumentPageSize>(
              segments: const [
                ButtonSegment(
                  value: SmartDocumentPageSize.a4,
                  label: Text('A4'),
                ),
                ButtonSegment(
                  value: SmartDocumentPageSize.letter,
                  label: Text('Letter'),
                ),
              ],
              selected: {_size},
              onSelectionChanged: (selection) {
                setState(() => _size = selection.first);
              },
            ),
            const SizedBox(height: 18),
            Text('Orientation', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<SmartDocumentOrientation>(
              segments: const [
                ButtonSegment(
                  value: SmartDocumentOrientation.portrait,
                  icon: Icon(Icons.stay_current_portrait_rounded),
                  label: Text('Portrait'),
                ),
                ButtonSegment(
                  value: SmartDocumentOrientation.landscape,
                  icon: Icon(Icons.stay_current_landscape_rounded),
                  label: Text('Landscape'),
                ),
              ],
              selected: {_orientation},
              onSelectionChanged: (selection) {
                setState(() => _orientation = selection.first);
              },
            ),
            const SizedBox(height: 18),
            Text('Margins', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<SmartDocumentMarginPreset>(
              key: const Key('smart-editor-margin-preset'),
              initialValue: _margins,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: SmartDocumentMarginPreset.narrow,
                  child: Text('Narrow'),
                ),
                DropdownMenuItem(
                  value: SmartDocumentMarginPreset.normal,
                  child: Text('Normal'),
                ),
                DropdownMenuItem(
                  value: SmartDocumentMarginPreset.wide,
                  child: Text('Wide'),
                ),
                DropdownMenuItem(
                  value: SmartDocumentMarginPreset.custom,
                  child: Text('Custom'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _margins = value);
              },
            ),
            if (_margins == SmartDocumentMarginPreset.custom) ...[
              const SizedBox(height: 12),
              _MarginSlider(
                label: 'Top',
                value: _topMargin,
                onChanged: (value) => setState(() => _topMargin = value),
              ),
              _MarginSlider(
                label: 'Right',
                value: _rightMargin,
                onChanged: (value) => setState(() => _rightMargin = value),
              ),
              _MarginSlider(
                label: 'Bottom',
                value: _bottomMargin,
                onChanged: (value) => setState(() => _bottomMargin = value),
              ),
              _MarginSlider(
                label: 'Left',
                value: _leftMargin,
                onChanged: (value) => setState(() => _leftMargin = value),
              ),
            ],
            const SizedBox(height: 18),
            Text('Page border', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<SmartDocumentPageBorderStyle>(
              key: const Key('smart-editor-page-border'),
              initialValue: _borderStyle,
              decoration: const InputDecoration(border: OutlineInputBorder()),
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
                if (value != null) setState(() => _borderStyle = value);
              },
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              key: const Key('smart-editor-layout-apply'),
              onPressed: () => Navigator.pop(
                context,
                SmartDocumentPageLayout(
                  pageSize: _size,
                  orientation: _orientation,
                  marginPreset: _margins,
                  borderStyle: _borderStyle,
                  customTopMargin: _topMargin,
                  customRightMargin: _rightMargin,
                  customBottomMargin: _bottomMargin,
                  customLeftMargin: _leftMargin,
                ),
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Apply layout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarginSlider extends StatelessWidget {
  const _MarginSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 58, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(18.0, 180.0).toDouble(),
            min: 18,
            max: 180,
            divisions: 18,
            label: '${value.round()} pt',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 58,
          child: Text('${value.round()} pt', textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
