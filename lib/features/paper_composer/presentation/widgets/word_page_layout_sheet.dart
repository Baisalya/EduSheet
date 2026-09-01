import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';

class WordPageLayoutDraft {
  final PaperPageLayout layout;
  final String headerText;
  final String footerText;
  final bool showPageNumbers;

  const WordPageLayoutDraft({
    required this.layout,
    required this.headerText,
    required this.footerText,
    required this.showPageNumbers,
  });
}

/// Word-style page setup shared by Android and Windows.
///
/// The sheet edits canonical paper layout values rather than an export-only
/// copy, so the same settings are visible in Word Mode, preview, PDF and DOCX.
class WordPageLayoutSheet {
  const WordPageLayoutSheet._();

  static Future<WordPageLayoutDraft?> show(
    BuildContext context, {
    required Paper paper,
  }) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      return showDialog<WordPageLayoutDraft>(
        context: context,
        builder: (context) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
            child: _PageLayoutEditor(paper: paper, dialog: true),
          ),
        ),
      );
    }

    return showAdaptiveModalBottomSheet<WordPageLayoutDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _PageLayoutEditor(paper: paper, dialog: false),
      ),
    );
  }
}

class _PageLayoutEditor extends StatefulWidget {
  final Paper paper;
  final bool dialog;

  const _PageLayoutEditor({required this.paper, required this.dialog});

  @override
  State<_PageLayoutEditor> createState() => _PageLayoutEditorState();
}

class _PageLayoutEditorState extends State<_PageLayoutEditor> {
  late PaperPageSize _pageSize;
  late PaperPageOrientation _orientation;
  late PaperPageNumberPosition _pageNumberPosition;
  late double _lineSpacing;
  late double _paragraphSpacing;
  late double _headerDistance;
  late double _footerDistance;
  late bool _showPageNumbers;

  late final TextEditingController _topMargin;
  late final TextEditingController _rightMargin;
  late final TextEditingController _bottomMargin;
  late final TextEditingController _leftMargin;
  late final TextEditingController _headerText;
  late final TextEditingController _footerText;

  @override
  void initState() {
    super.initState();
    final layout = widget.paper.pageLayout;
    _pageSize = layout.pageSize;
    _orientation = layout.orientation;
    _pageNumberPosition = layout.pageNumberPosition;
    _lineSpacing = layout.lineSpacing;
    _paragraphSpacing = layout.paragraphSpacingPoints;
    _headerDistance = layout.headerDistancePoints;
    _footerDistance = layout.footerDistancePoints;
    _showPageNumbers = widget.paper.showPageNumbers;
    _topMargin = TextEditingController(
      text: _formatMm(_pointsToMm(layout.margins.topPoints)),
    );
    _rightMargin = TextEditingController(
      text: _formatMm(_pointsToMm(layout.margins.rightPoints)),
    );
    _bottomMargin = TextEditingController(
      text: _formatMm(_pointsToMm(layout.margins.bottomPoints)),
    );
    _leftMargin = TextEditingController(
      text: _formatMm(_pointsToMm(layout.margins.leftPoints)),
    );
    _headerText = TextEditingController(text: widget.paper.headerText);
    _footerText = TextEditingController(text: widget.paper.footerText);
  }

  @override
  void dispose() {
    _topMargin.dispose();
    _rightMargin.dispose();
    _bottomMargin.dispose();
    _leftMargin.dispose();
    _headerText.dispose();
    _footerText.dispose();
    super.dispose();
  }

  void _applyMarginPreset(double points) {
    final mm = _formatMm(_pointsToMm(points));
    setState(() {
      _topMargin.text = mm;
      _rightMargin.text = mm;
      _bottomMargin.text = mm;
      _leftMargin.text = mm;
    });
  }

  double _marginPoints(TextEditingController controller) {
    final millimetres = double.tryParse(controller.text.trim()) ?? 12.7;
    return _mmToPoints(millimetres).clamp(12, 144).toDouble();
  }

  void _save() {
    final layout = PaperPageLayout(
      pageSize: _pageSize,
      orientation: _orientation,
      margins: PaperPageMargins(
        topPoints: _marginPoints(_topMargin),
        rightPoints: _marginPoints(_rightMargin),
        bottomPoints: _marginPoints(_bottomMargin),
        leftPoints: _marginPoints(_leftMargin),
      ),
      headerDistancePoints: _headerDistance,
      footerDistancePoints: _footerDistance,
      lineSpacing: _lineSpacing,
      paragraphSpacingPoints: _paragraphSpacing,
      pageNumberPosition: _pageNumberPosition,
    );

    Navigator.of(context).pop(
      WordPageLayoutDraft(
        layout: layout,
        headerText: _headerText.text.trim(),
        footerText: _footerText.text.trim(),
        showPageNumbers: _showPageNumbers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, widget.dialog ? 18 : 4, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Page & layout',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'These settings stay with this paper and are used by preview, PDF and Word export.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionTitle('Page'),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 520;
                    final size = DropdownButtonFormField<PaperPageSize>(
                      key: const Key('word-page-size'),
                      initialValue: _pageSize,
                      decoration: const InputDecoration(
                        labelText: 'Paper size',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final value in PaperPageSize.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(_pageSizeLabel(value)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _pageSize = value);
                        }
                      },
                    );
                    final orientation = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Orientation', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 6),
                        SegmentedButton<PaperPageOrientation>(
                          key: const Key('word-page-orientation'),
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: PaperPageOrientation.portrait,
                              icon: Icon(Icons.stay_current_portrait_rounded),
                              label: Text('Portrait'),
                            ),
                            ButtonSegment(
                              value: PaperPageOrientation.landscape,
                              icon: Icon(Icons.stay_current_landscape_rounded),
                              label: Text('Landscape'),
                            ),
                          ],
                          selected: {_orientation},
                          onSelectionChanged: (selection) =>
                              setState(() => _orientation = selection.first),
                        ),
                      ],
                    );
                    if (stacked) {
                      return Column(
                        children: [
                          size,
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: orientation,
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: size),
                        const SizedBox(width: 18),
                        orientation,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                _SectionTitle('Margins'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Normal 12.7 mm'),
                      onPressed: () => _applyMarginPreset(36),
                    ),
                    ActionChip(
                      label: const Text('Narrow 8.5 mm'),
                      onPressed: () => _applyMarginPreset(24),
                    ),
                    ActionChip(
                      label: const Text('Moderate 19 mm'),
                      onPressed: () => _applyMarginPreset(54),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth < 520
                        ? (constraints.maxWidth - 10) / 2
                        : (constraints.maxWidth - 30) / 4;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: width,
                          child: _MarginField(
                            key: const Key('word-margin-top'),
                            label: 'Top (mm)',
                            controller: _topMargin,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _MarginField(
                            key: const Key('word-margin-right'),
                            label: 'Right (mm)',
                            controller: _rightMargin,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _MarginField(
                            key: const Key('word-margin-bottom'),
                            label: 'Bottom (mm)',
                            controller: _bottomMargin,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _MarginField(
                            key: const Key('word-margin-left'),
                            label: 'Left (mm)',
                            controller: _leftMargin,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                _SectionTitle('Header, footer & page number'),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('word-header-text'),
                  controller: _headerText,
                  decoration: const InputDecoration(
                    labelText: 'Header text',
                    hintText: 'Optional repeated header',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('word-footer-text'),
                  controller: _footerText,
                  decoration: const InputDecoration(
                    labelText: 'Footer text',
                    hintText: 'Optional repeated footer',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile.adaptive(
                  key: const Key('word-show-page-numbers'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show page numbers'),
                  value: _showPageNumbers,
                  onChanged: (value) =>
                      setState(() => _showPageNumbers = value),
                ),
                if (_showPageNumbers)
                  DropdownButtonFormField<PaperPageNumberPosition>(
                    key: const Key('word-page-number-position'),
                    initialValue: _pageNumberPosition,
                    decoration: const InputDecoration(
                      labelText: 'Page number position',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final value in PaperPageNumberPosition.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(_pageNumberPositionLabel(value)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _pageNumberPosition = value);
                      }
                    },
                  ),
                const SizedBox(height: 12),
                _DistanceSlider(
                  label: 'Header distance',
                  value: _headerDistance,
                  onChanged: (value) => setState(() => _headerDistance = value),
                ),
                _DistanceSlider(
                  label: 'Footer distance',
                  value: _footerDistance,
                  onChanged: (value) => setState(() => _footerDistance = value),
                ),
                const SizedBox(height: 22),
                _SectionTitle('Document spacing'),
                const SizedBox(height: 10),
                DropdownButtonFormField<double>(
                  key: const Key('word-line-spacing'),
                  initialValue: _nearestLineSpacing(_lineSpacing),
                  decoration: const InputDecoration(
                    labelText: 'Line spacing',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1.0, child: Text('Single (1.0)')),
                    DropdownMenuItem(value: 1.15, child: Text('1.15')),
                    DropdownMenuItem(value: 1.5, child: Text('1.5')),
                    DropdownMenuItem(value: 2.0, child: Text('Double (2.0)')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _lineSpacing = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Paragraph spacing: ${_paragraphSpacing.toStringAsFixed(0)} pt',
                  style: theme.textTheme.labelLarge,
                ),
                Slider(
                  key: const Key('word-paragraph-spacing'),
                  min: 0,
                  max: 24,
                  divisions: 12,
                  value: _paragraphSpacing.clamp(0, 24).toDouble(),
                  label: '${_paragraphSpacing.toStringAsFixed(0)} pt',
                  onChanged: (value) =>
                      setState(() => _paragraphSpacing = value),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const Key('word-page-layout-save'),
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Apply'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static double _nearestLineSpacing(double value) {
    const values = [1.0, 1.15, 1.5, 2.0];
    return values.reduce(
      (a, b) => (a - value).abs() <= (b - value).abs() ? a : b,
    );
  }

  static String _pageSizeLabel(PaperPageSize value) {
    return switch (value) {
      PaperPageSize.useTemplate => 'Use paper style',
      PaperPageSize.a4 => 'A4',
      PaperPageSize.a5 => 'A5',
      PaperPageSize.a3 => 'A3',
      PaperPageSize.letter => 'Letter',
      PaperPageSize.legal => 'Legal',
    };
  }

  static String _pageNumberPositionLabel(PaperPageNumberPosition value) {
    return switch (value) {
      PaperPageNumberPosition.footerCenter => 'Footer — center',
      PaperPageNumberPosition.footerRight => 'Footer — right',
      PaperPageNumberPosition.headerRight => 'Header — right',
    };
  }

  static double _pointsToMm(double points) => points * 25.4 / 72;
  static double _mmToPoints(double millimetres) => millimetres * 72 / 25.4;
  static String _formatMm(double value) => value.toStringAsFixed(1);
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _MarginField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _MarginField({
    super.key,
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _DistanceSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _DistanceSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final millimetres = value * 25.4 / 72;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${millimetres.toStringAsFixed(1)} mm'),
        Slider(
          min: 0,
          max: 54,
          divisions: 18,
          value: value.clamp(0, 54).toDouble(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
