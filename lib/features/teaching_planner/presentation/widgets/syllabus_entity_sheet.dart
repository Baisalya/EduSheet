import 'package:flutter/material.dart';

import '../../domain/models/planner_class.dart';
import '../../domain/models/planner_priority.dart';
import '../../domain/models/planner_subject.dart';
import '../../domain/models/planner_topic.dart';
import '../../domain/models/planner_unit.dart';
import '../../domain/models/planner_chapter.dart';

class SyllabusEntitySheet extends StatefulWidget {
  const SyllabusEntitySheet({
    super.key,
    this.requestedKind,
    this.classValue,
    this.subjectValue,
    this.unitValue,
    this.chapterValue,
    this.topicValue,
    this.subjectId,
    this.unitId,
    this.units = const [],
  });

  final SyllabusEntityKind? requestedKind;
  final PlannerClass? classValue;
  final PlannerSubject? subjectValue;
  final PlannerUnit? unitValue;
  final PlannerChapter? chapterValue;
  final PlannerTopic? topicValue;
  final String? subjectId;
  final String? unitId;
  final List<PlannerUnit> units;

  SyllabusEntityKind get kind {
    final requested = requestedKind;
    if (requested != null) {
      return requested;
    }
    if (classValue != null) {
      return SyllabusEntityKind.classValue;
    }
    if (subjectValue != null) {
      return SyllabusEntityKind.subject;
    }
    if (unitValue != null) {
      return SyllabusEntityKind.unit;
    }
    if (chapterValue != null) {
      return SyllabusEntityKind.chapter;
    }
    return SyllabusEntityKind.topic;
  }

  bool get isEditing => switch (kind) {
    SyllabusEntityKind.classValue => classValue != null,
    SyllabusEntityKind.subject => subjectValue != null,
    SyllabusEntityKind.unit => unitValue != null,
    SyllabusEntityKind.chapter => chapterValue != null,
    SyllabusEntityKind.topic => topicValue != null,
  };

  @override
  State<SyllabusEntitySheet> createState() => _SyllabusEntitySheetState();
}

enum SyllabusEntityKind { classValue, subject, unit, chapter, topic }

class _SyllabusEntitySheetState extends State<SyllabusEntitySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _secondaryController;
  late final TextEditingController _periodController;
  late PlannerPriority _priority;
  String _unitSelection = _rootUnit;

  static const String _rootUnit = '__root__';

  @override
  void initState() {
    super.initState();
    final kind = widget.kind;
    final initialName = switch (kind) {
      SyllabusEntityKind.classValue => widget.classValue?.name,
      SyllabusEntityKind.subject => widget.subjectValue?.name,
      SyllabusEntityKind.unit => widget.unitValue?.title,
      SyllabusEntityKind.chapter => widget.chapterValue?.title,
      SyllabusEntityKind.topic => widget.topicValue?.title,
    };
    final secondary = switch (kind) {
      SyllabusEntityKind.classValue => widget.classValue?.academicYear,
      SyllabusEntityKind.subject => widget.subjectValue?.code,
      _ => null,
    };
    final periods = switch (kind) {
      SyllabusEntityKind.unit => widget.unitValue?.plannedPeriods,
      SyllabusEntityKind.chapter => widget.chapterValue?.plannedPeriods,
      SyllabusEntityKind.topic => widget.topicValue?.plannedPeriods,
      _ => null,
    };
    _nameController = TextEditingController(text: initialName ?? '');
    _secondaryController = TextEditingController(text: secondary ?? '');
    _periodController = TextEditingController(text: periods?.toString() ?? '0');
    _priority = switch (kind) {
      SyllabusEntityKind.unit =>
        widget.unitValue?.priority ?? PlannerPriority.normal,
      SyllabusEntityKind.chapter =>
        widget.chapterValue?.priority ?? PlannerPriority.normal,
      SyllabusEntityKind.topic =>
        widget.topicValue?.priority ?? PlannerPriority.normal,
      _ => PlannerPriority.normal,
    };
    if (widget.unitId != null) {
      _unitSelection = widget.unitId!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _secondaryController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final title = switch (kind) {
      SyllabusEntityKind.classValue =>
        widget.classValue == null ? 'Create class' : 'Edit class',
      SyllabusEntityKind.subject =>
        widget.subjectValue == null ? 'Add subject' : 'Edit subject',
      SyllabusEntityKind.unit =>
        widget.unitValue == null ? 'Add unit' : 'Edit unit',
      SyllabusEntityKind.chapter =>
        widget.chapterValue == null ? 'Add chapter' : 'Edit chapter',
      SyllabusEntityKind.topic =>
        widget.topicValue == null ? 'Add topic' : 'Edit topic',
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: _nameLabel(kind)),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name.'
                    : null,
              ),
              if (kind == SyllabusEntityKind.classValue ||
                  kind == SyllabusEntityKind.subject) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _secondaryController,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: kind == SyllabusEntityKind.classValue
                        ? 'Academic year (optional)'
                        : 'Subject code (optional)',
                  ),
                ),
              ],
              if (kind == SyllabusEntityKind.unit ||
                  kind == SyllabusEntityKind.chapter ||
                  kind == SyllabusEntityKind.topic) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _periodController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Planned periods',
                    helperText: 'Use 0 when the duration is not known yet.',
                  ),
                  validator: (value) {
                    final periods = int.tryParse(value?.trim() ?? '');
                    if (periods == null || periods < 0) {
                      return 'Enter a whole number 0 or greater.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PlannerPriority>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(
                      value: PlannerPriority.low,
                      child: Text('Low'),
                    ),
                    DropdownMenuItem(
                      value: PlannerPriority.normal,
                      child: Text('Normal'),
                    ),
                    DropdownMenuItem(
                      value: PlannerPriority.high,
                      child: Text('High'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _priority = value);
                    }
                  },
                ),
              ],
              if (kind == SyllabusEntityKind.chapter) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _unitSelection,
                  decoration: const InputDecoration(
                    labelText: 'Unit (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: _rootUnit,
                      child: Text('No unit / subject-level chapter'),
                    ),
                    ...widget.units.map(
                      (unit) => DropdownMenuItem(
                        value: unit.id,
                        child: Text(
                          unit.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _unitSelection = value ?? _rootUnit),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  widget.isEditing
                      ? 'Save changes'
                      : kind == SyllabusEntityKind.classValue
                      ? 'Create'
                      : 'Add',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final periods = int.tryParse(_periodController.text.trim()) ?? 0;
    Navigator.of(context).pop(
      SyllabusEntityDraft(
        name: _nameController.text.trim(),
        academicYear: widget.kind == SyllabusEntityKind.classValue
            ? _optional(_secondaryController.text)
            : null,
        code: widget.kind == SyllabusEntityKind.subject
            ? _optional(_secondaryController.text)
            : null,
        plannedPeriods: periods,
        priority: _priority,
        unitId: widget.kind == SyllabusEntityKind.chapter
            ? (_unitSelection == _rootUnit ? null : _unitSelection)
            : null,
      ),
    );
  }

  static String? _optional(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static String _nameLabel(SyllabusEntityKind kind) {
    return switch (kind) {
      SyllabusEntityKind.classValue => 'Class name',
      SyllabusEntityKind.subject => 'Subject name',
      SyllabusEntityKind.unit => 'Unit title',
      SyllabusEntityKind.chapter => 'Chapter title',
      SyllabusEntityKind.topic => 'Topic title',
    };
  }
}

class SyllabusEntityDraft {
  final String name;
  final String? academicYear;
  final String? code;
  final int plannedPeriods;
  final PlannerPriority priority;
  final String? unitId;

  const SyllabusEntityDraft({
    required this.name,
    this.academicYear,
    this.code,
    this.plannedPeriods = 0,
    this.priority = PlannerPriority.normal,
    this.unitId,
  });
}
