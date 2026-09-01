import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_style_preview.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

enum _TextDensity { compact, normal, large }

class PaperStyleEditorSheet extends ConsumerStatefulWidget {
  final PaperTemplate base;

  const PaperStyleEditorSheet({super.key, required this.base});

  static Future<String?> show(BuildContext context, PaperTemplate base) {
    return showAdaptiveModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.94,
        child: PaperStyleEditorSheet(base: base),
      ),
    );
  }

  @override
  ConsumerState<PaperStyleEditorSheet> createState() =>
      _PaperStyleEditorSheetState();
}

class _PaperStyleEditorSheetState extends ConsumerState<PaperStyleEditorSheet> {
  late final TextEditingController _name;
  late PaperSize _paperSize;
  late HeaderLayout _headerLayout;
  late PaperLayout _paperLayout;
  late bool _hasBorder;
  late bool _centeredHeader;
  late double _headerFontSize;
  late double _questionFontSize;
  late _TextDensity _density;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: '${widget.base.name} Custom');
    _paperSize = widget.base.paperSize;
    _headerLayout =
        widget.base.headerLayout == HeaderLayout.custom &&
            widget.base.customLayout == null
        ? HeaderLayout.centered
        : widget.base.headerLayout;
    _paperLayout = widget.base.paperLayout;
    _hasBorder = widget.base.hasBorder;
    _centeredHeader = widget.base.centeredHeader;
    _headerFontSize = widget.base.headerFontSize.clamp(14, 32).toDouble();
    _questionFontSize = widget.base.questionFontSize.clamp(9, 18).toDouble();
    _density = _densityFor(_questionFontSize);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  PaperTemplate get _previewTemplate => widget.base.copyWith(
    id: 'preview-style',
    name: _name.text.trim().isEmpty ? 'Custom style' : _name.text.trim(),
    paperSize: _paperSize,
    headerLayout: _headerLayout,
    paperLayout: _paperLayout,
    hasBorder: _hasBorder,
    centeredHeader: _centeredHeader,
    headerFontSize: _headerFontSize,
    questionFontSize: _questionFontSize,
  );

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give this paper style a name.')),
      );
      return;
    }

    setState(() => _saving = true);
    final style = _previewTemplate.copyWith(id: const Uuid().v4(), name: name);

    try {
      await ref.read(templateProvider.notifier).saveTemplate(style);
      ref.read(editorStateProvider.notifier).updateTemplate(style.id);
      if (mounted) Navigator.pop(context, style.id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save paper style: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customize appearance',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Visual settings only — paper information and questions are never changed.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final controls = _buildControls(context);
              final preview = _buildPreview(context);
              if (!wide) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [controls, const SizedBox(height: 20), preview],
                  ),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 20, 28),
                      child: controls,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: preview,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
    final theme = Theme.of(context);
    final allowedHeaders = HeaderLayout.values
        .where(
          (layout) =>
              layout != HeaderLayout.custom || widget.base.customLayout != null,
        )
        .toList(growable: false);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Style name',
                prefixIcon: Icon(Icons.style_outlined),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Essentials',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _ResponsivePair(
              first: DropdownButtonFormField<PaperSize>(
                initialValue: _paperSize,
                decoration: const InputDecoration(labelText: 'Page'),
                items: [
                  for (final size in PaperSize.values)
                    DropdownMenuItem(
                      value: size,
                      child: Text(size.name.toUpperCase()),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _paperSize = value);
                },
              ),
              second: DropdownButtonFormField<PaperLayout>(
                initialValue: _paperLayout,
                decoration: const InputDecoration(labelText: 'Questions'),
                items: [
                  for (final layout in PaperLayout.values)
                    DropdownMenuItem(
                      value: layout,
                      child: Text(_paperLayoutLabel(layout)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _paperLayout = value);
                },
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<HeaderLayout>(
              initialValue: _headerLayout,
              decoration: const InputDecoration(
                labelText: 'Header',
                helperText:
                    'Choose a professional starting arrangement; Word Mode can fine-tune header positions.',
              ),
              items: [
                for (final layout in allowedHeaders)
                  DropdownMenuItem(
                    value: layout,
                    child: Text(_headerLayoutLabel(layout)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _headerLayout = value);
              },
            ),
            const SizedBox(height: 14),
            Text('Question text', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<_TextDensity>(
              segments: const [
                ButtonSegment(
                  value: _TextDensity.compact,
                  label: Text('Compact'),
                ),
                ButtonSegment(
                  value: _TextDensity.normal,
                  label: Text('Normal'),
                ),
                ButtonSegment(value: _TextDensity.large, label: Text('Large')),
              ],
              selected: {_density},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                final density = selection.first;
                setState(() {
                  _density = density;
                  _questionFontSize = switch (density) {
                    _TextDensity.compact => 10,
                    _TextDensity.normal => 11.5,
                    _TextDensity.large => 13,
                  };
                });
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Paper border'),
              subtitle: const Text(
                'Useful for formal or worksheet-style papers.',
              ),
              value: _hasBorder,
              onChanged: (value) => setState(() => _hasBorder = value),
            ),
            const SizedBox(height: 4),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('Advanced'),
              subtitle: const Text('Exact typography and alignment controls'),
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Centered main heading'),
                  value: _centeredHeader,
                  onChanged: (value) => setState(() => _centeredHeader = value),
                ),
                _SliderSetting(
                  label: 'Header size',
                  value: _headerFontSize,
                  min: 14,
                  max: 32,
                  divisions: 18,
                  onChanged: (value) => setState(() => _headerFontSize = value),
                ),
                _SliderSetting(
                  label: 'Question size',
                  value: _questionFontSize,
                  min: 9,
                  max: 18,
                  divisions: 18,
                  onChanged: (value) {
                    setState(() {
                      _questionFontSize = value;
                      _density = _densityFor(value);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving…' : 'Save & use style'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Live preview',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${_paperSize.name.toUpperCase()} · ${_paperLayoutLabel(_paperLayout)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PaperStylePreview(template: _previewTemplate, height: 330),
        ],
      ),
    );
  }

  static _TextDensity _densityFor(double questionFontSize) {
    if (questionFontSize <= 10.5) return _TextDensity.compact;
    if (questionFontSize >= 12.5) return _TextDensity.large;
    return _TextDensity.normal;
  }

  static String _paperLayoutLabel(PaperLayout value) {
    switch (value) {
      case PaperLayout.standard:
        return 'Single column';
      case PaperLayout.twoColumn:
        return 'Two columns';
    }
  }

  static String _headerLayoutLabel(HeaderLayout value) {
    switch (value) {
      case HeaderLayout.centered:
        return 'Centered formal';
      case HeaderLayout.logoLeft:
        return 'Identity left';
      case HeaderLayout.logoRight:
        return 'Identity right';
      case HeaderLayout.modernCoaching:
        return 'Modern compact';
      case HeaderLayout.minimal:
        return 'Minimal';
      case HeaderLayout.academic:
        return 'Academic formal';
      case HeaderLayout.ssvm:
        return 'Structured formal';
      case HeaderLayout.dps:
        return 'Board classic';
      case HeaderLayout.custom:
        return 'Saved custom layout';
    }
  }
}

class _ResponsivePair extends StatelessWidget {
  final Widget first;
  final Widget second;

  const _ResponsivePair({required this.first, required this.second});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(children: [first, const SizedBox(height: 14), second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 14),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _SliderSetting extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text('${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} pt'),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: value.toStringAsFixed(1),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
