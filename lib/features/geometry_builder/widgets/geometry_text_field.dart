import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/geometry_diagram.dart';
import '../painters/geometry_painter.dart';
import '../services/geometry_diagram_registry.dart';
import 'geometry_builder_screen.dart';

class GeometryTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final int? maxLines;
  final ValueChanged<List<GeometryDiagram>>? onAttachmentsChanged;

  const GeometryTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration,
    this.maxLines,
    this.onAttachmentsChanged,
  });

  @override
  State<GeometryTextField> createState() => _GeometryTextFieldState();
}

class _GeometryTextFieldState extends State<GeometryTextField> {
  final List<GeometryDiagram> _attachments = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          maxLines: widget.maxLines,
          decoration: (widget.decoration ?? const InputDecoration()).copyWith(
            suffixIcon: IconButton(
              onPressed: () => _openBuilder(),
              icon: const Icon(Icons.architecture),
              tooltip: 'Geometry Builder',
            ),
          ),
        ),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final diagram in _attachments)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _GeometryAttachmentCard(
                diagram: diagram,
                onEdit: () => _openBuilder(diagram),
                onDuplicate: () => _duplicateAttachment(diagram),
                onDelete: () => _removeAttachment(diagram),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _openBuilder([GeometryDiagram? existing]) async {
    final diagram = await GeometryBuilderScreen.show(
      context,
      initialDiagram: existing,
    );
    if (diagram == null) return;
    if (existing == null) {
      _insertPlaceholder(diagram.placeholderToken);
      _addAttachment(diagram);
    } else {
      setState(() {
        final index = _attachments.indexWhere((item) => item.id == existing.id);
        if (index >= 0) _attachments[index] = diagram;
      });
      widget.onAttachmentsChanged?.call(List.unmodifiable(_attachments));
    }
  }

  void _insertPlaceholder(String token) {
    final value = widget.controller.value;
    final selection = value.selection;
    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? value.text.length : selection.end;
    final next = value.text.replaceRange(start, end, token);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  void _addAttachment(GeometryDiagram diagram) {
    GeometryDiagramRegistry.instance.save(diagram);
    setState(() => _attachments.add(diagram));
    widget.onAttachmentsChanged?.call(List.unmodifiable(_attachments));
  }

  void _duplicateAttachment(GeometryDiagram diagram) {
    final duplicate = GeometryDiagram(
      id: const Uuid().v4(),
      name: '${diagram.name} copy',
      canvasSize: diagram.canvasSize,
      points: diagram.points,
      shapes: diagram.shapes,
      labels: diagram.labels,
      marks: diagram.marks,
      showGrid: diagram.showGrid,
      snapToGrid: diagram.snapToGrid,
      examMode: diagram.examMode,
      transparentBackground: diagram.transparentBackground,
    );
    _insertPlaceholder(duplicate.placeholderToken);
    _addAttachment(duplicate);
  }

  void _removeAttachment(GeometryDiagram diagram) {
    setState(() => _attachments.removeWhere((item) => item.id == diagram.id));
    widget.controller.text = widget.controller.text.replaceAll(
      diagram.placeholderToken,
      '',
    );
    widget.onAttachmentsChanged?.call(List.unmodifiable(_attachments));
  }
}

class _GeometryAttachmentCard extends StatelessWidget {
  final GeometryDiagram diagram;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _GeometryAttachmentCard({
    required this.diagram,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.architecture, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    diagram.name,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onDuplicate,
                  icon: const Icon(Icons.copy),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: CustomPaint(
                  painter: GeometryPainter(
                    diagram: diagram.copyWith(showGrid: false),
                    showPointHandles: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
