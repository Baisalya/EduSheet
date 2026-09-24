import 'package:edusheet/features/smart_editor/application/smart_editor_docx_structure_editing.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_interop_embed_builders.dart';
import 'package:flutter/material.dart';

class SmartEditorDocxTableEditorSheet extends StatefulWidget {
  const SmartEditorDocxTableEditorSheet({super.key, required this.initial});

  final SmartEditorInteropTablePayload initial;

  static Future<SmartEditorInteropTablePayload?> show(
    BuildContext context,
    SmartEditorInteropTablePayload initial,
  ) {
    return showDialog<SmartEditorInteropTablePayload>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
          child: SmartEditorDocxTableEditorSheet(initial: initial),
        ),
      ),
    );
  }

  @override
  State<SmartEditorDocxTableEditorSheet> createState() =>
      _SmartEditorDocxTableEditorSheetState();
}

class _SmartEditorDocxTableEditorSheetState
    extends State<SmartEditorDocxTableEditorSheet> {
  late SmartEditorInteropTablePayload _working;

  @override
  void initState() {
    super.initState();
    _working = widget.initial;
  }

  bool get _merged =>
      SmartEditorDocxStructureEditing.hasMergedStructure(_working);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    final title = _working.sourceKind == 'textBox'
        ? 'Edit imported Word text box'
        : 'Edit imported Word table';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Edit text without flattening imported images, nested tables or Word layout metadata.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: const Text('Borders'),
                selected: _working.showBorders,
                onSelected: (value) {
                  setState(() {
                    _working = SmartEditorDocxStructureEditing.withPresentation(
                      _working,
                      showBorders: value,
                    );
                  });
                },
              ),
              DropdownButton<String>(
                value: _working.alignment,
                items: const [
                  DropdownMenuItem(value: 'left', child: Text('Align left')),
                  DropdownMenuItem(value: 'center', child: Text('Align center')),
                  DropdownMenuItem(value: 'right', child: Text('Align right')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _working = SmartEditorDocxStructureEditing.withPresentation(
                      _working,
                      alignment: value,
                    );
                  });
                },
              ),
              if (_working.sourceKind != 'textBox') ...[
                OutlinedButton.icon(
                  onPressed: _merged
                      ? null
                      : () => setState(() {
                            _working =
                                SmartEditorDocxStructureEditing.addColumn(_working);
                          }),
                  icon: const Icon(Icons.view_column_outlined),
                  label: const Text('Add column'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _working = SmartEditorDocxStructureEditing.addRow(_working);
                  }),
                  icon: const Icon(Icons.table_rows_outlined),
                  label: const Text('Add row'),
                ),
              ],
            ],
          ),
        ),
        if (_merged)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Merged Word cells detected. Cell text stays editable, but column add/remove is locked to protect the imported merge geometry.',
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _working.rows.length,
            itemBuilder: (context, rowIndex) {
              final row = _working.rows[rowIndex];
              return Card(
                key: ValueKey('smart-docx-edit-row-$rowIndex'),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.header
                                  ? 'Header row ${rowIndex + 1}'
                                  : 'Row ${rowIndex + 1}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (_working.sourceKind != 'textBox' &&
                              _working.rows.length > 1)
                            IconButton(
                              tooltip: 'Remove row',
                              onPressed: () => setState(() {
                                _working = SmartEditorDocxStructureEditing.removeRow(
                                  _working,
                                  rowIndex,
                                );
                              }),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (compact)
                        for (var cellIndex = 0;
                            cellIndex < row.cells.length;
                            cellIndex++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CellEditor(
                              rowIndex: rowIndex,
                              cellIndex: cellIndex,
                              cell: row.cells[cellIndex],
                              onChanged: (value) => _updateCell(
                                rowIndex,
                                cellIndex,
                                value,
                              ),
                              onRemoveColumn: _merged || row.cells.length <= 1
                                  ? null
                                  : () => _removeColumn(cellIndex),
                            ),
                          )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var cellIndex = 0;
                                  cellIndex < row.cells.length;
                                  cellIndex++)
                                SizedBox(
                                  width: 250,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: _CellEditor(
                                      rowIndex: rowIndex,
                                      cellIndex: cellIndex,
                                      cell: row.cells[cellIndex],
                                      onChanged: (value) => _updateCell(
                                        rowIndex,
                                        cellIndex,
                                        value,
                                      ),
                                      onRemoveColumn:
                                          _merged || row.cells.length <= 1
                                              ? null
                                              : () => _removeColumn(cellIndex),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const Key('smart-docx-structure-save'),
                onPressed: () => Navigator.pop(context, _working),
                icon: const Icon(Icons.check),
                label: const Text('Apply'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _updateCell(int rowIndex, int cellIndex, String value) {
    setState(() {
      _working = SmartEditorDocxStructureEditing.updateCellText(
        _working,
        rowIndex,
        cellIndex,
        value,
      );
    });
  }

  void _removeColumn(int cellIndex) {
    setState(() {
      _working = SmartEditorDocxStructureEditing.removeColumn(
        _working,
        cellIndex,
      );
    });
  }
}

class _CellEditor extends StatelessWidget {
  const _CellEditor({
    required this.rowIndex,
    required this.cellIndex,
    required this.cell,
    required this.onChanged,
    required this.onRemoveColumn,
  });

  final int rowIndex;
  final int cellIndex;
  final SmartEditorInteropTableCell cell;
  final ValueChanged<String> onChanged;
  final VoidCallback? onRemoveColumn;

  @override
  Widget build(BuildContext context) {
    final imageCount = cell.blocks.where((block) => block.kind == 'image').length;
    final nestedTableCount =
        cell.blocks.where((block) => block.kind == 'table').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Cell ${cellIndex + 1}${cell.gridSpan > 1 ? ' • spans ${cell.gridSpan}' : ''}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            if (onRemoveColumn != null && rowIndex == 0)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Remove this column',
                onPressed: onRemoveColumn,
                icon: const Icon(Icons.remove_circle_outline, size: 18),
              ),
          ],
        ),
        TextFormField(
          key: ValueKey('smart-docx-cell-$rowIndex-$cellIndex'),
          initialValue: cell.text,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: onChanged,
        ),
        if (imageCount > 0 || nestedTableCount > 0) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              if (imageCount > 0)
                Chip(
                  avatar: const Icon(Icons.image_outlined, size: 16),
                  label: Text(
                    '$imageCount preserved image${imageCount == 1 ? '' : 's'}',
                  ),
                ),
              if (nestedTableCount > 0)
                Chip(
                  avatar: const Icon(Icons.table_chart_outlined, size: 16),
                  label: Text(
                    '$nestedTableCount nested table${nestedTableCount == 1 ? '' : 's'}',
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class SmartEditorDocxImageEditorSheet extends StatefulWidget {
  const SmartEditorDocxImageEditorSheet({super.key, required this.initial});

  final SmartEditorInteropImagePayload initial;

  static Future<SmartEditorInteropImagePayload?> show(
    BuildContext context,
    SmartEditorInteropImagePayload initial,
  ) {
    return showDialog<SmartEditorInteropImagePayload>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SmartEditorDocxImageEditorSheet(initial: initial),
        ),
      ),
    );
  }

  @override
  State<SmartEditorDocxImageEditorSheet> createState() =>
      _SmartEditorDocxImageEditorSheetState();
}

class _SmartEditorDocxImageEditorSheetState
    extends State<SmartEditorDocxImageEditorSheet> {
  late double _width;
  late double _height;
  late final double _aspect;
  late final TextEditingController _altController;
  bool _lockAspect = true;

  @override
  void initState() {
    super.initState();
    _width = widget.initial.widthPoints <= 0 ? 160.0 : widget.initial.widthPoints;
    _height = widget.initial.heightPoints <= 0 ? 120.0 : widget.initial.heightPoints;
    _aspect = _width / _height;
    _altController = TextEditingController(text: widget.initial.altText ?? '');
  }

  @override
  void dispose() {
    _altController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit imported Word image',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          if (widget.initial.bytes.isNotEmpty)
            SizedBox(
              height: 180,
              child: Image.memory(widget.initial.bytes, fit: BoxFit.contain),
            ),
          const SizedBox(height: 14),
          Text('Width ${_width.round()} px'),
          Slider(
            key: const Key('smart-docx-image-width'),
            min: 48,
            max: 720,
            value: _width.clamp(48, 720).toDouble(),
            onChanged: (value) {
              setState(() {
                _width = value;
                if (_lockAspect && _aspect > 0) _height = value / _aspect;
              });
            },
          ),
          Text('Height ${_height.round()} px'),
          Slider(
            min: 36,
            max: 720,
            value: _height.clamp(36, 720).toDouble(),
            onChanged: (value) {
              setState(() {
                _height = value;
                if (_lockAspect && _aspect > 0) _width = value * _aspect;
              });
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Keep aspect ratio'),
            value: _lockAspect,
            onChanged: (value) => setState(() => _lockAspect = value),
          ),
          TextField(
            controller: _altController,
            decoration: const InputDecoration(
              labelText: 'Alt text',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    SmartEditorDocxStructureEditing.resizeImage(
                      widget.initial,
                      widthPoints: _width,
                      heightPoints: _height,
                      altText: _altController.text.trim().isEmpty
                          ? null
                          : _altController.text.trim(),
                    ),
                  );
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SmartEditorDocxShapeEditorDialog {
  const SmartEditorDocxShapeEditorDialog._();

  static Future<SmartEditorInteropShapePayload?> show(
    BuildContext context,
    SmartEditorInteropShapePayload initial,
  ) async {
    var width = initial.widthPoints.clamp(36.0, 720.0).toDouble();
    var height = initial.heightPoints.clamp(24.0, 720.0).toDouble();
    var rotation = initial.rotationDegrees.clamp(-180.0, 180.0).toDouble();
    var flipHorizontal = initial.flipHorizontal;
    var flipVertical = initial.flipVertical;
    final textController = TextEditingController(text: initial.text);
    final fillController = TextEditingController(text: initial.fillColorHex ?? '');
    final strokeController =
        TextEditingController(text: initial.strokeColorHex ?? '');

    String? normalizedColor(String value, String? fallback) {
      final raw = value.replaceAll('#', '').trim();
      return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(raw)
          ? raw.toUpperCase()
          : fallback;
    }

    final result = await showDialog<SmartEditorInteropShapePayload>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit imported Word shape'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: textController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Shape text',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Width ${width.round()} px'),
                  Slider(
                    min: 36,
                    max: 720,
                    value: width,
                    onChanged: (value) => setState(() => width = value),
                  ),
                  Text('Height ${height.round()} px'),
                  Slider(
                    min: 24,
                    max: 720,
                    value: height,
                    onChanged: (value) => setState(() => height = value),
                  ),
                  Text('Rotation ${rotation.round()}°'),
                  Slider(
                    min: -180,
                    max: 180,
                    value: rotation,
                    onChanged: (value) => setState(() => rotation = value),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fillController,
                          decoration: const InputDecoration(
                            labelText: 'Fill hex',
                            hintText: 'FFFFFF',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: strokeController,
                          decoration: const InputDecoration(
                            labelText: 'Stroke hex',
                            hintText: '000000',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Flip horizontal'),
                    value: flipHorizontal,
                    onChanged: (value) =>
                        setState(() => flipHorizontal = value),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Flip vertical'),
                    value: flipVertical,
                    onChanged: (value) => setState(() => flipVertical = value),
                  ),
                  if (initial.placement.floating)
                    const Text(
                      'Word anchor, wrap distances and z-order stay attached to this shape while you edit its visual properties.',
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                initial.copyWith(
                  widthPoints: width,
                  heightPoints: height,
                  text: textController.text,
                  fillColorHex:
                      normalizedColor(fillController.text, initial.fillColorHex),
                  strokeColorHex: normalizedColor(
                    strokeController.text,
                    initial.strokeColorHex,
                  ),
                  rotationDegrees: rotation,
                  flipHorizontal: flipHorizontal,
                  flipVertical: flipVertical,
                ),
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    textController.dispose();
    fillController.dispose();
    strokeController.dispose();
    return result;
  }
}
