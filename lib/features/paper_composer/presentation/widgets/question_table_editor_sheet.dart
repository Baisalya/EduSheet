import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_math_text_field.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';

class QuestionTableEditorSheet extends StatefulWidget {
  final QuestionTable? initial;

  const QuestionTableEditorSheet({super.key, this.initial});

  static Future<QuestionTable?> show(
    BuildContext context, {
    QuestionTable? initial,
  }) {
    return showAdaptiveModalBottomSheet<QuestionTable>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => QuestionTableEditorSheet(initial: initial),
    );
  }

  @override
  State<QuestionTableEditorSheet> createState() =>
      _QuestionTableEditorSheetState();
}

class _QuestionTableEditorSheetState extends State<QuestionTableEditorSheet> {
  late bool _useHeader;
  late List<TextEditingController> _headers;
  late List<List<TextEditingController>> _rows;
  late final TextEditingController _caption;
  late final TextEditingController _summary;

  int get _columnCount {
    if (_headers.isNotEmpty) return _headers.length;
    if (_rows.isNotEmpty && _rows.first.isNotEmpty) return _rows.first.length;
    return 2;
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _useHeader = initial?.headers.isNotEmpty == true;
    final initialColumns = _resolveInitialColumnCount(initial);
    _headers = List.generate(
      initialColumns,
      (index) => TextEditingController(
        text: index < (initial?.headers.length ?? 0)
            ? initial!.headers[index]
            : '',
      ),
    );
    final sourceRows = initial?.rows ?? const <List<String>>[];
    _rows = sourceRows.isEmpty
        ? List.generate(
            2,
            (_) =>
                List.generate(initialColumns, (_) => TextEditingController()),
          )
        : sourceRows
              .map(
                (row) => List.generate(
                  initialColumns,
                  (index) => TextEditingController(
                    text: index < row.length ? row[index] : '',
                  ),
                ),
              )
              .toList();
    _caption = TextEditingController(text: initial?.caption ?? '');
    _summary = TextEditingController(text: initial?.accessibilitySummary ?? '');
  }

  int _resolveInitialColumnCount(QuestionTable? table) {
    var columns = table?.headers.length ?? 0;
    for (final row in table?.rows ?? const <List<String>>[]) {
      if (row.length > columns) columns = row.length;
    }
    return columns.clamp(2, 6).toInt();
  }

  @override
  void dispose() {
    for (final controller in _headers) {
      controller.dispose();
    }
    for (final row in _rows) {
      for (final controller in row) {
        controller.dispose();
      }
    }
    _caption.dispose();
    _summary.dispose();
    super.dispose();
  }

  void _addRow() {
    if (_rows.length >= 12) return;
    setState(() {
      _rows.add(List.generate(_columnCount, (_) => TextEditingController()));
    });
  }

  void _removeRow() {
    if (_rows.length <= 1) return;
    setState(() {
      final removed = _rows.removeLast();
      for (final controller in removed) {
        controller.dispose();
      }
    });
  }

  void _addColumn() {
    if (_columnCount >= 6) return;
    setState(() {
      _headers.add(TextEditingController());
      for (final row in _rows) {
        row.add(TextEditingController());
      }
    });
  }

  void _removeColumn() {
    if (_columnCount <= 2) return;
    setState(() {
      _headers.removeLast().dispose();
      for (final row in _rows) {
        row.removeLast().dispose();
      }
    });
  }

  void _save() {
    final headers = _useHeader
        ? _headers.map((controller) => controller.text.trim()).toList()
        : <String>[];
    final rows = _rows
        .map((row) => row.map((controller) => controller.text.trim()).toList())
        .toList();

    Navigator.pop(
      context,
      QuestionTable(
        headers: headers,
        rows: rows,
        caption: _caption.text.trim(),
        accessibilitySummary: _summary.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.initial == null
                        ? 'Add table / data'
                        : 'Edit table / data',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Build the data visually instead of spacing text by hand. Swipe sideways when the table is wider than the phone.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Header row'),
                    subtitle: const Text(
                      'Use the first row as column headings.',
                    ),
                    value: _useHeader,
                    onChanged: (value) => setState(() => _useHeader = value),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _rows.length < 12 ? _addRow : null,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Row'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _rows.length > 1 ? _removeRow : null,
                        icon: const Icon(Icons.remove_rounded),
                        label: const Text('Row'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _columnCount < 6 ? _addColumn : null,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Column'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _columnCount > 2 ? _removeColumn : null,
                        icon: const Icon(Icons.remove_rounded),
                        label: const Text('Column'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_useHeader)
                            _TableEditorRow(
                              controllers: _headers,
                              header: true,
                            ),
                          for (
                            var rowIndex = 0;
                            rowIndex < _rows.length;
                            rowIndex++
                          )
                            _TableEditorRow(
                              controllers: _rows[rowIndex],
                              rowLabel: '${rowIndex + 1}',
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  QuestionMathTextField(
                    controller: _caption,
                    decoration: const InputDecoration(
                      labelText: 'Caption (optional)',
                      hintText: 'Table 1: Observations',
                    ),
                  ),
                  const SizedBox(height: 10),
                  QuestionMathTextField(
                    controller: _summary,
                    minLines: 2,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      alignLabelWithHint: true,
                      labelText: 'Accessibility summary (optional)',
                      hintText: 'Briefly describe what the table shows.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Use table'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableEditorRow extends StatelessWidget {
  final List<TextEditingController> controllers;
  final bool header;
  final String? rowLabel;

  const _TableEditorRow({
    required this.controllers,
    this.header = false,
    this.rowLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              header ? 'H' : (rowLabel ?? ''),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (var index = 0; index < controllers.length; index++) ...[
            SizedBox(
              width: 145,
              child: QuestionMathTextField(
                controller: controllers[index],
                minLines: 1,
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: header ? 'Heading ${index + 1}' : 'Cell',
                ),
              ),
            ),
            if (index + 1 < controllers.length) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
