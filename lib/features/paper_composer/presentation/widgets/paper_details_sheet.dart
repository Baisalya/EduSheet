import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaperDetailsSheet extends ConsumerStatefulWidget {
  final Paper paper;

  const PaperDetailsSheet({super.key, required this.paper});

  static Future<void> show(BuildContext context, Paper paper) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => PaperDetailsSheet(paper: paper),
    );
  }

  @override
  ConsumerState<PaperDetailsSheet> createState() => _PaperDetailsSheetState();
}

class _PaperDetailsSheetState extends ConsumerState<PaperDetailsSheet> {
  late final TextEditingController _title;
  late final TextEditingController _school;
  late final TextEditingController _instruction;
  late final TextEditingController _maximumMarks;
  late final TextEditingController _subject;
  late final TextEditingController _className;
  late final TextEditingController _duration;
  String? _maximumMarksError;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.paper.title);
    _school = TextEditingController(text: widget.paper.schoolName);
    _instruction = TextEditingController(text: widget.paper.instruction);
    _maximumMarks = TextEditingController(
      text: widget.paper.maximumMarks == null
          ? ''
          : _formatNumber(widget.paper.maximumMarks!),
    );
    _subject = TextEditingController(text: _headerValue('Subject'));
    _className = TextEditingController(text: _headerValue('Class'));
    _duration = TextEditingController(text: _headerValue('Time'));
  }

  @override
  void dispose() {
    _title.dispose();
    _school.dispose();
    _instruction.dispose();
    _maximumMarks.dispose();
    _subject.dispose();
    _className.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _save() {
    final rawMaximum = _maximumMarks.text.trim();
    final parsed = rawMaximum.isEmpty ? null : double.tryParse(rawMaximum);
    if (rawMaximum.isNotEmpty &&
        (parsed == null || !parsed.isFinite || parsed <= 0)) {
      setState(() => _maximumMarksError = 'Enter marks above 0 or leave it empty');
      return;
    }
    setState(() => _maximumMarksError = null);

    final editor = ref.read(editorStateProvider.notifier);
    editor.updateTitle(_title.text.trim().isEmpty ? 'New Paper' : _title.text.trim());
    editor.updateBranding(schoolName: _school.text.trim());
    editor.updateInstruction(_instruction.text.trim());
    editor.updatePaperSettings(
      maximumMarks: parsed,
      clearMaximumMarks: _maximumMarks.text.trim().isEmpty,
    );
    _updateHeader(editor, 'Subject', _subject.text.trim());
    _updateHeader(editor, 'Class', _className.text.trim());
    _updateHeader(editor, 'Time', _duration.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              'Paper details',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Paper title',
                hintText: 'Mathematics Unit Test',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _school,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'School / institute'),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final fields = [
                  TextField(
                    controller: _subject,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Subject'),
                  ),
                  TextField(
                    controller: _className,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Class / grade'),
                  ),
                ];
                if (constraints.maxWidth < 520) {
                  return Column(
                    children: [fields.first, const SizedBox(height: 12), fields.last],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: fields.first),
                    const SizedBox(width: 12),
                    Expanded(child: fields.last),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _duration,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Duration',
                hintText: '3 Hours',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maximumMarks,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Maximum marks (optional)',
                errorText: _maximumMarksError,
              ),
              onChanged: (_) {
                if (_maximumMarksError != null) {
                  setState(() => _maximumMarksError = null);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instruction,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'General instructions',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save details'),
            ),
          ],
        ),
      ),
    );
  }

  String _headerValue(String label) {
    for (final field in widget.paper.headerFields) {
      if (field.label.trim().toLowerCase() == label.toLowerCase()) {
        return field.value;
      }
    }
    return '';
  }

  void _updateHeader(EditorState editor, String label, String value) {
    PaperHeaderField? existing;
    for (final field in widget.paper.headerFields) {
      if (field.label.trim().toLowerCase() == label.toLowerCase()) {
        existing = field;
        break;
      }
    }
    if (existing == null) {
      if (value.isNotEmpty) {
        editor.addHeaderField(label: label, value: value);
      }
    } else {
      editor.updateHeaderField(existing.id, value: value);
    }
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
}
