import 'dart:io';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/application/paper_marks_teacher_diagnostics.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/pdf/application/paper_header_profile.dart';
import 'package:edusheet/features/pdf/application/paper_marks_resolver.dart';
import 'package:edusheet/features/pdf/application/paper_template_resolver.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaperDetailsSheet extends ConsumerStatefulWidget {
  final Paper paper;

  const PaperDetailsSheet({super.key, required this.paper});

  static Future<void> show(BuildContext context, Paper paper) async {
    await showAdaptiveModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.94,
        child: PaperDetailsSheet(paper: paper),
      ),
    );
  }

  @override
  ConsumerState<PaperDetailsSheet> createState() => _PaperDetailsSheetState();
}

class _PaperDetailsSheetState extends ConsumerState<PaperDetailsSheet> {
  static const _standardLabels = {
    'subject',
    'class',
    'time',
    'date',
    'student name',
    'roll no',
  };

  late final TextEditingController _title;
  late final TextEditingController _school;
  late final TextEditingController _instruction;
  late final TextEditingController _maximumMarks;
  late final TextEditingController _subject;
  late final TextEditingController _className;
  late final TextEditingController _duration;
  late final TextEditingController _date;
  late bool _showDate;
  late bool _showStudentName;
  late bool _showRollNo;
  late PaperTextAlignment _instructionAlignment;
  late String _logoPath;
  late List<_CustomFieldDraft> _customFields;
  String? _maximumMarksError;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: widget.paper.title == 'New Paper' ? '' : widget.paper.title,
    );
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
    _date = TextEditingController(text: _headerValue('Date'));
    _showDate = _hasHeader('Date');
    _showStudentName = _hasHeader('Student Name');
    _showRollNo = _hasHeader('Roll No');
    _instructionAlignment = widget.paper.instructionAlignment;
    _logoPath = widget.paper.logos.isEmpty ? '' : widget.paper.logos.first;
    _customFields = widget.paper.headerFields
        .where(
          (field) =>
              !_standardLabels.contains(field.label.trim().toLowerCase()),
        )
        .map(_CustomFieldDraft.fromField)
        .toList(growable: true);
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
    _date.dispose();
    for (final field in _customFields) {
      field.dispose();
    }
    super.dispose();
  }

  void _save() {
    final rawMaximum = _maximumMarks.text.trim();
    final parsed = rawMaximum.isEmpty ? null : double.tryParse(rawMaximum);
    if (rawMaximum.isNotEmpty &&
        (parsed == null || !parsed.isFinite || parsed <= 0)) {
      setState(
        () => _maximumMarksError = 'Enter marks above 0 or leave it empty',
      );
      return;
    }

    final duplicateLabels = <String>{};
    final seen = <String>{};
    for (final draft in _customFields) {
      final label = draft.label.text.trim().toLowerCase();
      if (label.isEmpty) continue;
      if (!seen.add(label) || _standardLabels.contains(label)) {
        duplicateLabels.add(label);
      }
    }
    if (duplicateLabels.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Additional field names must be unique.')),
      );
      return;
    }

    setState(() => _maximumMarksError = null);
    ref
        .read(editorStateProvider.notifier)
        .applyPaperSetup(
          title: _title.text.trim().isEmpty ? 'New Paper' : _title.text.trim(),
          schoolName: _school.text.trim(),
          instruction: _instruction.text.trim(),
          instructionAlignment: _instructionAlignment,
          logos: _resolvedLogos(),
          headerFields: _resolvedHeaderFields(),
          maximumMarks: parsed,
          clearMaximumMarks: rawMaximum.isEmpty,
        );
    Navigator.pop(context);
  }

  List<String> _resolvedLogos() {
    final logos = List<String>.from(widget.paper.logos);
    if (_logoPath.isNotEmpty) {
      if (logos.isEmpty) {
        logos.add(_logoPath);
      } else {
        logos[0] = _logoPath;
      }
      return logos;
    }

    if (logos.isNotEmpty) logos[0] = '';
    while (logos.isNotEmpty && logos.last.trim().isEmpty) {
      logos.removeLast();
    }
    return logos;
  }

  List<PaperHeaderField> _resolvedHeaderFields() {
    final fields = <PaperHeaderField>[];

    void addStandard(
      String label,
      String value, {
      required bool keepBlankLine,
    }) {
      final shouldKeep = value.isNotEmpty || keepBlankLine;
      if (!shouldKeep) return;
      final existing = _findHeader(label);
      fields.add(
        PaperHeaderField(
          id: existing?.id ?? '',
          label: label,
          value: value,
          isPlaceholder: value.isEmpty,
        ),
      );
    }

    addStandard('Subject', _subject.text.trim(), keepBlankLine: true);
    addStandard('Class', _className.text.trim(), keepBlankLine: true);
    addStandard('Time', _duration.text.trim(), keepBlankLine: true);
    addStandard('Date', _date.text.trim(), keepBlankLine: _showDate);
    addStandard('Student Name', '', keepBlankLine: _showStudentName);
    addStandard('Roll No', '', keepBlankLine: _showRollNo);

    for (final draft in _customFields) {
      final label = draft.label.text.trim();
      if (label.isEmpty) continue;
      final value = draft.value.text.trim();
      fields.add(
        PaperHeaderField(
          id: draft.id ?? '',
          label: label,
          value: value,
          isPlaceholder: draft.blankLine || value.isEmpty,
        ),
      );
    }
    return fields;
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _logoPath = path);
  }

  void _addSuggestedField(PaperHeaderSuggestion suggestion) {
    final normalized = suggestion.label.trim().toLowerCase();
    if (normalized == 'date') {
      setState(() => _showDate = true);
      return;
    }
    if (normalized == 'student name') {
      setState(() => _showStudentName = true);
      return;
    }
    if (normalized == 'roll no') {
      setState(() => _showRollNo = true);
      return;
    }
    if (_customFields.any(
      (field) => field.label.text.trim().toLowerCase() == normalized,
    )) {
      return;
    }
    setState(() {
      _customFields.add(
        _CustomFieldDraft.suggested(
          suggestion.label,
          blankLine: suggestion.blankLine,
        ),
      );
    });
  }

  void _appendInstruction(String instruction) {
    final current = _instruction.text.trim();
    if (current.toLowerCase().contains(instruction.toLowerCase())) return;
    _instruction.text = current.isEmpty
        ? instruction
        : '$current\n$instruction';
    _instruction.selection = TextSelection.collapsed(
      offset: _instruction.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marks = _draftMarksSummary();
    final selectedTemplate = PaperTemplateResolver.resolve(
      widget.paper.templateId,
      ref.watch(templateProvider).all,
    );
    final headerProfile = PaperHeaderProfile.forTemplate(selectedTemplate);
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
                      'Paper setup',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Enter the information teachers and students need. Appearance is configured separately.',
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
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 28,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Essentials',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _school,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'School / institution',
                        hintText: 'Green Valley Public School',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _title,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Exam / paper title',
                        hintText: 'Half-Yearly Examination 2026',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ResponsivePair(
                      first: TextField(
                        controller: _subject,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Subject'),
                      ),
                      second: TextField(
                        controller: _className,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Class / grade',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ResponsivePair(
                      first: TextField(
                        controller: _duration,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Duration',
                          hintText: '2 Hours',
                        ),
                      ),
                      second: TextField(
                        controller: _maximumMarks,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Maximum marks',
                          hintText: 'Auto from questions',
                          errorText: _maximumMarksError,
                        ),
                        onChanged: (_) {
                          setState(() => _maximumMarksError = null);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    _MarksStatus(summary: marks),
                    const SizedBox(height: 14),
                    _LogoControl(
                      path: _logoPath,
                      onPick: _pickLogo,
                      onClear: _logoPath.isEmpty
                          ? null
                          : () => setState(() => _logoPath = ''),
                    ),
                    const SizedBox(height: 10),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('More details'),
                      subtitle: const Text(
                        'Date, student lines and additional paper fields',
                      ),
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Show date'),
                          value: _showDate,
                          onChanged: (value) =>
                              setState(() => _showDate = value),
                        ),
                        if (_showDate)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller: _date,
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                hintText: 'Leave empty for a blank date line',
                              ),
                            ),
                          ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Student name line'),
                          value: _showStudentName,
                          onChanged: (value) =>
                              setState(() => _showStudentName = value),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Roll number line'),
                          value: _showRollNo,
                          onChanged: (value) =>
                              setState(() => _showRollNo = value),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Additional fields',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(
                                  () => _customFields.add(
                                    _CustomFieldDraft.newField(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add field'),
                            ),
                          ],
                        ),
                        if (headerProfile.optionalFields.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Useful for ${selectedTemplate.name}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              for (final suggestion
                                  in headerProfile.optionalFields)
                                ActionChip(
                                  label: Text('+ ${suggestion.label}'),
                                  onPressed: () =>
                                      _addSuggestedField(suggestion),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        for (
                          var index = 0;
                          index < _customFields.length;
                          index++
                        )
                          _CustomFieldEditor(
                            key: ValueKey(_customFields[index].key),
                            draft: _customFields[index],
                            onDelete: () {
                              setState(() {
                                final removed = _customFields.removeAt(index);
                                removed.dispose();
                              });
                            },
                            onChanged: () => setState(() {}),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'General instructions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final suggestion in const [
                          'Attempt all questions.',
                          'Show all necessary working.',
                          'Draw neat labelled diagrams where required.',
                          'Figures in the margin indicate marks.',
                        ])
                          ActionChip(
                            label: Text(suggestion),
                            onPressed: () => _appendInstruction(suggestion),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _instruction,
                      minLines: 3,
                      maxLines: 8,
                      textAlign: _instructionAlignment.textAlign,
                      decoration: const InputDecoration(
                        labelText: 'Instructions',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Instruction alignment',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 7),
                    SegmentedButton<PaperTextAlignment>(
                      segments: const [
                        ButtonSegment(
                          value: PaperTextAlignment.left,
                          icon: Icon(Icons.format_align_left_rounded),
                          label: Text('Left'),
                        ),
                        ButtonSegment(
                          value: PaperTextAlignment.center,
                          icon: Icon(Icons.format_align_center_rounded),
                          label: Text('Center'),
                        ),
                        ButtonSegment(
                          value: PaperTextAlignment.right,
                          icon: Icon(Icons.format_align_right_rounded),
                          label: Text('Right'),
                        ),
                      ],
                      selected: {_instructionAlignment},
                      onSelectionChanged: (selection) => setState(
                        () => _instructionAlignment = selection.first,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save paper setup'),
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

  PaperMarksSummary _draftMarksSummary() {
    final raw = _maximumMarks.text.trim();
    final parsed = raw.isEmpty ? null : double.tryParse(raw);
    final draft = raw.isEmpty
        ? widget.paper.copyWith(clearMaximumMarks: true)
        : parsed != null && parsed.isFinite && parsed > 0
        ? widget.paper.copyWith(maximumMarks: parsed)
        : widget.paper;
    return PaperMarksResolver.summarize(draft);
  }

  bool _hasHeader(String label) => _findHeader(label) != null;

  String _headerValue(String label) => _findHeader(label)?.value ?? '';

  PaperHeaderField? _findHeader(String label) {
    final key = label.trim().toLowerCase();
    for (final field in widget.paper.headerFields) {
      if (field.label.trim().toLowerCase() == key) return field;
    }
    return null;
  }

  static String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

class _ResponsivePair extends StatelessWidget {
  final Widget first;
  final Widget second;

  const _ResponsivePair({required this.first, required this.second});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 540) {
          return Column(children: [first, const SizedBox(height: 12), second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _MarksStatus extends StatelessWidget {
  final PaperMarksSummary summary;

  const _MarksStatus({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diagnostics = PaperMarksTeacherDiagnostics(summary);
    final message = diagnostics.mismatchMessage;
    if (message == null) {
      return Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              diagnostics.setupStatus,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _LogoControl extends StatelessWidget {
  final String path;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  const _LogoControl({
    required this.path,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = path.trim();
    final file = normalized.isEmpty ? null : File(normalized);
    final canPreview = file != null && file.existsSync();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 48,
        height: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: canPreview
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.file(file, fit: BoxFit.contain),
                )
              : const Icon(Icons.image_outlined),
        ),
      ),
      title: const Text('School logo'),
      subtitle: Text(
        normalized.isEmpty
            ? 'Optional. Choose a PNG or JPG.'
            : normalized.split(RegExp(r'[\\/]')).last,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          TextButton.icon(
            onPressed: onPick,
            icon: Icon(
              normalized.isEmpty
                  ? Icons.add_photo_alternate_outlined
                  : Icons.swap_horiz_rounded,
              size: 17,
            ),
            label: Text(normalized.isEmpty ? 'Choose' : 'Replace'),
          ),
          if (onClear != null)
            IconButton(
              tooltip: 'Remove logo',
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }
}

class _CustomFieldDraft {
  final String key;
  final String? id;
  final TextEditingController label;
  final TextEditingController value;
  bool blankLine;

  _CustomFieldDraft({
    required this.key,
    required this.id,
    required this.label,
    required this.value,
    required this.blankLine,
  });

  factory _CustomFieldDraft.fromField(PaperHeaderField field) {
    return _CustomFieldDraft(
      key: field.id,
      id: field.id,
      label: TextEditingController(text: field.label),
      value: TextEditingController(text: field.value),
      blankLine: field.isPlaceholder,
    );
  }

  factory _CustomFieldDraft.newField() {
    final key = DateTime.now().microsecondsSinceEpoch.toString();
    return _CustomFieldDraft(
      key: key,
      id: null,
      label: TextEditingController(),
      value: TextEditingController(),
      blankLine: false,
    );
  }

  factory _CustomFieldDraft.suggested(String label, {bool blankLine = false}) {
    final key = '${DateTime.now().microsecondsSinceEpoch}-$label';
    return _CustomFieldDraft(
      key: key,
      id: null,
      label: TextEditingController(text: label),
      value: TextEditingController(),
      blankLine: blankLine,
    );
  }

  void dispose() {
    label.dispose();
    value.dispose();
  }
}

class _CustomFieldEditor extends StatelessWidget {
  final _CustomFieldDraft draft;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _CustomFieldEditor({
    super.key,
    required this.draft,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.label,
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Field name',
                      hintText: 'Paper Code',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: draft.value,
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      hintText: 'Optional',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete field',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Print as blank line for students to fill'),
              value: draft.blankLine,
              onChanged: (value) {
                draft.blankLine = value ?? false;
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}
