import 'package:flutter/material.dart';

import '../models/geometry_label.dart';
import '../models/geometry_point.dart';

typedef GeometryLabelSubmit =
    void Function(String text, double fontSize, double rotation, bool isBold);

class LabelEditorSheet extends StatefulWidget {
  final GeometryLabelType type;
  final GeometryLabel? initialLabel;
  final GeometryLabelSubmit onSubmitted;

  const LabelEditorSheet({
    super.key,
    required this.type,
    this.initialLabel,
    required this.onSubmitted,
  });

  @override
  State<LabelEditorSheet> createState() => _LabelEditorSheetState();
}

class _LabelEditorSheetState extends State<LabelEditorSheet> {
  late final TextEditingController _controller;
  late double _fontSize;
  late double _rotation;
  late bool _isBold;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialLabel;
    _controller = TextEditingController(
      text: initial?.text ?? _defaultText(widget.type),
    );
    _fontSize = initial?.fontSize ?? 14;
    _rotation = initial?.rotation ?? 0;
    _isBold = initial?.isBold ?? true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              widget.initialLabel == null
                  ? 'Add ${widget.type.name} text'
                  : 'Edit diagram text',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'After inserting, drag the text anywhere on the diagram. Long-press it to edit again.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Text or measurement',
                hintText: 'Example: AB = 5 cm',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.text_fields_rounded, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Text size')),
                      Text(
                        '${_fontSize.round()} pt',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  Slider(
                    value: _fontSize,
                    min: 8,
                    max: 32,
                    divisions: 24,
                    label: '${_fontSize.round()} pt',
                    onChanged: (value) => setState(() => _fontSize = value),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: FilterChip(
                          avatar: const Icon(Icons.format_bold_rounded, size: 18),
                          label: const Text('Bold'),
                          selected: _isBold,
                          onSelected: (value) => setState(() => _isBold = value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<double>(
                          initialValue: _rotation,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Rotate',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('0°')),
                            DropdownMenuItem(value: -0.785398, child: Text('-45°')),
                            DropdownMenuItem(value: 0.785398, child: Text('45°')),
                            DropdownMenuItem(value: 1.570796, child: Text('90°')),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _rotation = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 70),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Transform.rotate(
                      angle: _rotation,
                      child: Text(
                        _controller.text.isEmpty ? 'Preview' : _controller.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: _fontSize,
                          fontWeight: _isBold
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  widget.initialLabel == null ? 'Add to diagram' : 'Apply changes',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmitted(text, _fontSize, _rotation, _isBold);
    Navigator.of(context).pop();
  }

  String _defaultText(GeometryLabelType type) => '';

}


class PointLabelEditorSheet extends StatefulWidget {
  final GeometryPoint point;
  final GeometryLabelSubmit onSubmitted;

  const PointLabelEditorSheet({
    super.key,
    required this.point,
    required this.onSubmitted,
  });

  @override
  State<PointLabelEditorSheet> createState() => _PointLabelEditorSheetState();
}

class _PointLabelEditorSheetState extends State<PointLabelEditorSheet> {
  late final TextEditingController _controller;
  late double _fontSize;
  late double _rotation;
  late bool _isBold;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.point.label);
    _fontSize = widget.point.labelFontSize;
    _rotation = widget.point.labelRotation;
    _isBold = widget.point.labelBold;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Edit point label',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Rename A, B, C or any vertex. Drag the label on the canvas to place it independently from the point.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 12,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Point name',
                hintText: 'A, B, C, P₁…',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.text_fields_rounded, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Label size')),
                      Text(
                        '${_fontSize.round()} pt',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  Slider(
                    value: _fontSize,
                    min: 8,
                    max: 32,
                    divisions: 24,
                    label: '${_fontSize.round()} pt',
                    onChanged: (value) => setState(() => _fontSize = value),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: FilterChip(
                          avatar: const Icon(Icons.format_bold_rounded, size: 18),
                          label: const Text('Bold'),
                          selected: _isBold,
                          onSelected: (value) => setState(() => _isBold = value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<double>(
                          initialValue: _rotation,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Rotate',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('0°')),
                            DropdownMenuItem(value: -0.785398, child: Text('-45°')),
                            DropdownMenuItem(value: 0.785398, child: Text('45°')),
                            DropdownMenuItem(value: 1.570796, child: Text('90°')),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _rotation = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 64),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Transform.rotate(
                      angle: _rotation,
                      child: Text(
                        _controller.text.trim().isEmpty
                            ? 'A'
                            : _controller.text.trim(),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: _fontSize,
                          fontWeight: _isBold ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Apply label'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmitted(text, _fontSize, _rotation, _isBold);
    Navigator.of(context).pop();
  }
}
