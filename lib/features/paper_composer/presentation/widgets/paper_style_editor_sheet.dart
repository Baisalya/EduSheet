import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Focused replacement for the legacy free-form template designer.
///
/// It only exposes properties already persisted by [PaperTemplate], so custom
/// paper styles remain compatible with the existing PDF/Word renderers.
class PaperStyleEditorSheet extends ConsumerStatefulWidget {
  final PaperTemplate base;

  const PaperStyleEditorSheet({super.key, required this.base});

  static Future<String?> show(BuildContext context, PaperTemplate base) {
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: '${widget.base.name} Custom');
    _paperSize = widget.base.paperSize;
    _headerLayout = widget.base.headerLayout == HeaderLayout.custom
        ? HeaderLayout.centered
        : widget.base.headerLayout;
    _paperLayout = widget.base.paperLayout;
    _hasBorder = widget.base.hasBorder;
    _centeredHeader = widget.base.centeredHeader;
    _headerFontSize = widget.base.headerFontSize.clamp(14, 32).toDouble();
    _questionFontSize = widget.base.questionFontSize.clamp(9, 18).toDouble();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

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
    final style = widget.base.copyWith(
      id: const Uuid().v4(),
      name: name,
      paperSize: _paperSize,
      headerLayout: _headerLayout,
      paperLayout: _paperLayout,
      hasBorder: _hasBorder,
      centeredHeader: _centeredHeader,
      headerFontSize: _headerFontSize,
      questionFontSize: _questionFontSize,
    );

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
    final allowedHeaders = HeaderLayout.values
        .where((layout) => layout != HeaderLayout.custom)
        .toList();

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
                      'Customize paper style',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Print settings only — questions stay unchanged.',
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Style name',
                        prefixIcon: Icon(Icons.style_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _TwoColumn(
                      first: DropdownButtonFormField<PaperSize>(
                        initialValue: _paperSize,
                        decoration: const InputDecoration(labelText: 'Page size'),
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
                        decoration: const InputDecoration(labelText: 'Question layout'),
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
                        labelText: 'Header style',
                        helperText: 'Choose a clean supported header arrangement.',
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
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Paper border'),
                      subtitle: const Text('Draw the template border when supported.'),
                      value: _hasBorder,
                      onChanged: (value) => setState(() => _hasBorder = value),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Centered heading'),
                      subtitle: const Text('Keep the main heading centered in compatible styles.'),
                      value: _centeredHeader,
                      onChanged: (value) => setState(() => _centeredHeader = value),
                    ),
                    const SizedBox(height: 8),
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
                      onChanged: (value) => setState(() => _questionFontSize = value),
                    ),
                    const SizedBox(height: 20),
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
            ),
          ),
        ),
      ],
    );
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
        return 'Centered';
      case HeaderLayout.logoLeft:
        return 'Logo left';
      case HeaderLayout.logoRight:
        return 'Logo right';
      case HeaderLayout.modernCoaching:
        return 'Modern coaching';
      case HeaderLayout.minimal:
        return 'Minimal';
      case HeaderLayout.academic:
        return 'Academic';
      case HeaderLayout.ssvm:
        return 'SSVM';
      case HeaderLayout.dps:
        return 'DPS';
      case HeaderLayout.custom:
        return 'Custom';
    }
  }
}

class _TwoColumn extends StatelessWidget {
  final Widget first;
  final Widget second;

  const _TwoColumn({required this.first, required this.second});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: [first, const SizedBox(height: 14), second],
          );
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
