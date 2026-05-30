import 'package:flutter/material.dart';

import '../models/geometry_label.dart';

class LabelEditorSheet extends StatefulWidget {
  final GeometryLabelType type;
  final ValueChanged<String> onSubmitted;

  const LabelEditorSheet({
    super.key,
    required this.type,
    required this.onSubmitted,
  });

  @override
  State<LabelEditorSheet> createState() => _LabelEditorSheetState();
}

class _LabelEditorSheetState extends State<LabelEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _defaultText(widget.type));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add ${widget.type.name} label',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Label text',
            ),
            onSubmitted: _submit,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _submit(_controller.text),
              icon: const Icon(Icons.check),
              label: const Text('Add label'),
            ),
          ),
        ],
      ),
    );
  }

  void _submit(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    widget.onSubmitted(text);
    Navigator.of(context).pop();
  }

  String _defaultText(GeometryLabelType type) {
    return switch (type) {
      GeometryLabelType.side => 'AB = 5 cm',
      GeometryLabelType.angle => 'angle A = 60 deg',
      GeometryLabelType.height => 'h = 8 cm',
      GeometryLabelType.width => 'w = 12 cm',
      GeometryLabelType.radius => 'r = 4 cm',
      GeometryLabelType.diameter => 'd = 8 cm',
      GeometryLabelType.area => 'Area = 24 cm2',
      GeometryLabelType.perimeter => 'Perimeter = 20 cm',
      GeometryLabelType.custom => 'Label',
    };
  }
}
