import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:edusheet/features/geometry_builder/widgets/geometry_attachment_preview.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_embed_builder.dart';
import 'package:edusheet/features/geometry_builder/services/geometry_diagram_registry.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_builder_screen.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_field.dart';

import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/ocr/presentation/screens/ocr_screen.dart';
import 'package:edusheet/features/templates/domain/models/content_template.dart';
import 'package:edusheet/features/templates/presentation/providers/content_template_provider.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/safe_math_expression.dart';

// Note: I'll need to check if vsc_quill_delta_to_html is available,
// if not I might need another way to convert delta to html for storage.
// For now let's assume I can use Delta directly as a JSON string.

class QuestionEditorSheet extends ConsumerStatefulWidget {
  final String sectionId;
  final Question? question;
  final QuestionType? initialType;
  final int? insertAt;

  const QuestionEditorSheet({
    super.key,
    required this.sectionId,
    this.question,
    this.initialType,
    this.insertAt,
  });

  @override
  ConsumerState<QuestionEditorSheet> createState() =>
      _QuestionEditorSheetState();
}

class _QuestionEditorSheetState extends ConsumerState<QuestionEditorSheet> {
  late QuillController _controller;
  final ScrollController _sheetScrollController = ScrollController();
  final ScrollController _questionScrollController = ScrollController();
  final FocusNode _questionFocusNode = FocusNode();
  late final TextEditingController _marksController;
  late QuestionType _type;
  late double _marks;
  late bool _isOptional;
  late List<QuestionOption> _options;
  late List<MathExpression> _mathExpressions;
  final Map<String, TextEditingController> _optionControllers = {};
  String? _questionError;
  String? _marksError;
  String? _optionsError;
  int? _nextInsertAt;

  @override
  void initState() {
    super.initState();
    final defaults = ref.read(questionEditorDefaultsProvider);
    _type = widget.question?.type ?? widget.initialType ?? defaults.type;
    _nextInsertAt = widget.insertAt;
    _marks = widget.question?.marks ?? defaults.marks;
    _isOptional = widget.question?.isOptional ?? defaults.isOptional;
    _marksController = TextEditingController(text: _formatMarks(_marks));
    _options = widget.question?.options.map((o) => o.copyWith()).toList() ?? [];
    _mathExpressions =
        widget.question?.mathExpressions.map((item) => item.copyWith()).toList() ??
        [];

    if (widget.question != null) {
      // For now, let's assume 'text' is a Delta JSON string
      try {
        // Simple heuristic: if it looks like JSON, parse as Delta
        if (widget.question!.text.startsWith('[') ||
            widget.question!.text.startsWith('{')) {
          final List<dynamic> json = jsonDecode(widget.question!.text);
          _controller = QuillController(
            document: Document.fromJson(json.cast<Map<String, dynamic>>()),
            selection: const TextSelection.collapsed(offset: 0),
          );
        } else {
          // fallback to plain text if it's not JSON
          _controller = QuillController.basic();
          _controller.document.insert(0, widget.question!.text);
        }
      } catch (e) {
        _controller = QuillController.basic();
        _controller.document.insert(0, widget.question!.text);
      }
    } else {
      _controller = QuillController.basic();
    }

    if (_type.usesOptions && _options.isEmpty) {
      _options = _emptyOptionsForType(_type);
    }
    _syncOptionControllers();

    if (widget.question == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusQuestionEditor();
      });
    }
  }

  void _save({bool addAnother = false}) {
    if (!_validate()) return;

    final text = jsonEncode(_controller.document.toDelta().toJson());
    final options = _type.usesOptions
        ? _options
              .where((option) => _optionText(option).trim().isNotEmpty)
              .map(
                (option) => option.copyWith(text: _optionText(option).trim()),
              )
              .toList()
        : <QuestionOption>[];
    ref
        .read(questionEditorDefaultsProvider.notifier)
        .state = QuestionEditorDefaults(
      type: _type,
      marks: _marks,
      isOptional: _isOptional,
    );

    if (widget.question == null) {
      ref
          .read(editorStateProvider.notifier)
          .addQuestion(
            widget.sectionId,
            text,
            type: _type,
            marks: _marks,
            options: options,
            isOptional: _isOptional,
            insertAt: _nextInsertAt,
            mathExpressions: _mathExpressions,
          );
      if (addAnother) {
        if (_nextInsertAt != null) _nextInsertAt = _nextInsertAt! + 1;
        _resetForNextQuestion();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question saved. Ready for the next one.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 900),
          ),
        );
        return;
      }
    } else {
      ref
          .read(editorStateProvider.notifier)
          .updateQuestion(
            widget.sectionId,
            widget.question!.id,
            text: text,
            type: _type,
            marks: _marks,
            options: options,
            isOptional: _isOptional,
            mathExpressions: _mathExpressions,
          );
    }
    Navigator.pop(context);
  }

  Future<void> _saveAsTemplate() async {
    if (!_validate()) return;
    final details = await _askTemplateDetails();
    if (details == null || !mounted) return;
    final text = jsonEncode(_controller.document.toDelta().toJson());
    final options = _type.usesOptions
        ? _options
              .where((option) => _optionText(option).trim().isNotEmpty)
              .map(
                (option) => option.copyWith(text: _optionText(option).trim()),
              )
              .toList()
        : <QuestionOption>[];
    final now = DateTime.now();
    final question = Question(
      id: const Uuid().v4(),
      text: text,
      type: _type,
      marks: _marks,
      options: options,
      isOptional: _isOptional,
      subject: details.subject,
      chapter: details.chapter,
      topic: details.topic,
      grade: details.grade,
      mathExpressions: _mathExpressions,
      createdAt: now,
      modifiedAt: now,
    );
    await ref.read(contentTemplateRepositoryProvider).saveQuestionTemplate(
      QuestionTemplate(
        id: const Uuid().v4(),
        name: details.name,
        description: question.plainTextAccessibility,
        question: question,
        createdAt: now,
        modifiedAt: now,
      ),
    );
    ref.invalidate(questionTemplatesProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Question template saved.')),
    );
  }

  Future<_QuestionTemplateDetails?> _askTemplateDetails() async {
    final name = TextEditingController();
    final grade = TextEditingController();
    final subject = TextEditingController();
    final chapter = TextEditingController();
    final topic = TextEditingController();
    final result = await showDialog<_QuestionTemplateDetails>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save question as template'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Template name *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: grade,
                decoration: const InputDecoration(labelText: 'Class / grade'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: subject,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: chapter,
                decoration: const InputDecoration(labelText: 'Chapter'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: topic,
                decoration: const InputDecoration(labelText: 'Topic'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(
                context,
                _QuestionTemplateDetails(
                  name: name.text.trim(),
                  grade: grade.text.trim(),
                  subject: subject.text.trim(),
                  chapter: chapter.text.trim(),
                  topic: topic.text.trim(),
                ),
              );
            },
            child: const Text('Save template'),
          ),
        ],
      ),
    );
    for (final controller in [name, grade, subject, chapter, topic]) {
      controller.dispose();
    }
    return result;
  }

  Future<void> _addFormula() async {
    final expression = await FormulaEditorSheet.show(context);
    if (expression == null || !mounted) return;
    setState(() => _mathExpressions.add(expression));
  }

  Future<void> _editFormula(int index) async {
    final expression = await FormulaEditorSheet.show(
      context,
      initial: _mathExpressions[index],
    );
    if (expression == null || !mounted) return;
    setState(() => _mathExpressions[index] = expression);
  }

  void _resetForNextQuestion() {
    final previousController = _controller;
    final previousOptionControllers = Map<String, TextEditingController>.from(
      _optionControllers,
    );

    setState(() {
      _controller = QuillController.basic();
      _options = _type.usesOptions ? _emptyOptionsForType(_type) : [];
      _mathExpressions = [];
      _optionControllers
        ..clear()
        ..addEntries(
          _options.map((option) {
            final controller = TextEditingController(text: option.text);
            controller.addListener(
              () => _setOptionText(option.id, controller.text),
            );
            return MapEntry(option.id, controller);
          }),
        );
      _questionError = null;
      _optionsError = null;
    });

    previousController.dispose();
    for (final controller in previousOptionControllers.values) {
      controller.dispose();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusQuestionEditor();
    });
  }

  void _focusQuestionEditor() {
    _questionFocusNode.requestFocus();
    if (!_sheetScrollController.hasClients) return;
    _sheetScrollController.animateTo(
      _sheetScrollController.position.minScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  bool _validate() {
    final questionText = _controller.document.toPlainText().trim();
    final mcqOptionCount = _options
        .where((option) => _optionText(option).trim().isNotEmpty)
        .length;

    setState(() {
      _questionError = questionText.isEmpty ? 'Write the question first' : null;
      _marksError = _marks <= 0 ? 'Marks must be more than 0' : null;
      _optionsError = _type.usesOptions && mcqOptionCount < 2
          ? 'Add at least two options'
          : null;
    });

    return _questionError == null &&
        _marksError == null &&
        _optionsError == null;
  }

  void _setType(QuestionType type) {
    setState(() {
      _type = type;
      if (_type.usesOptions && _options.isEmpty) {
        _options = _emptyOptionsForType(_type);
      }
      _syncOptionControllers();
      _optionsError = null;
    });
  }

  List<QuestionOption> _emptyOptionsForType(QuestionType type) {
    if (type == QuestionType.trueFalse) {
      return [
        QuestionOption(id: const Uuid().v4(), text: 'True'),
        QuestionOption(id: const Uuid().v4(), text: 'False'),
      ];
    }
    return List.generate(
      4,
      (_) => QuestionOption(id: const Uuid().v4(), text: ''),
    );
  }

  Future<void> _showTypePicker() async {
    var query = '';
    final selected = await showModalBottomSheet<QuestionType>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final types = QuestionType.values
              .where(
                (type) => type.label.toLowerCase().contains(
                  query.trim().toLowerCase(),
                ),
              )
              .toList();
          return FractionallySizedBox(
            heightFactor: 0.82,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose question type',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search question types',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setSheetState(() => query = value),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: types.length,
                    itemBuilder: (context, index) {
                      final type = types[index];
                      return ListTile(
                        minTileHeight: 52,
                        leading: Icon(
                          type == _type
                              ? Icons.check_circle_rounded
                              : Icons.quiz_outlined,
                          color: type == _type ? Colors.blue : null,
                        ),
                        title: Text(type.label),
                        subtitle: type.usesOptions
                            ? Text(
                                type.allowsMultipleCorrect
                                    ? 'Supports multiple correct answers'
                                    : 'Supports answer options',
                              )
                            : null,
                        onTap: () => Navigator.pop(context, type),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (selected != null && mounted) _setType(selected);
  }

  void _syncOptionControllers() {
    final activeIds = _options.map((option) => option.id).toSet();
    for (final entry in _optionControllers.entries.toList()) {
      if (!activeIds.contains(entry.key)) {
        entry.value.dispose();
        _optionControllers.remove(entry.key);
      }
    }

    for (final option in _options) {
      if (_optionControllers.containsKey(option.id)) continue;

      final controller = TextEditingController(text: option.text);
      controller.addListener(() => _setOptionText(option.id, controller.text));
      _optionControllers[option.id] = controller;
    }
  }

  TextEditingController _optionController(QuestionOption option) {
    _syncOptionControllers();
    return _optionControllers[option.id]!;
  }

  String _optionText(QuestionOption option) {
    return _optionControllers[option.id]?.text ?? option.text;
  }

  void _setOptionText(String optionId, String text) {
    final index = _options.indexWhere((option) => option.id == optionId);
    if (index == -1 || _options[index].text == text) return;

    _options[index] = _options[index].copyWith(text: text);
  }

  void _addOption() {
    setState(() {
      _options.add(QuestionOption(id: const Uuid().v4(), text: ''));
      _syncOptionControllers();
    });
  }

  void _removeOptionAt(int index) {
    final removed = _options[index];
    setState(() {
      _options.removeAt(index);
      _optionControllers.remove(removed.id)?.dispose();
    });
  }

  void _setMarks(double value) {
    final safeValue = value.clamp(0.5, 100.0).toDouble();
    setState(() {
      _marks = safeValue;
      _marksController.text = _formatMarks(safeValue);
      _marksController.selection = TextSelection.collapsed(
        offset: _marksController.text.length,
      );
      _marksError = null;
    });
  }

  void _insertQuestionText(String text) {
    final range = _safeSelectionRange();
    _controller.replaceText(range.$1, range.$2, text, null);
    _controller.updateSelection(
      TextSelection.collapsed(offset: range.$1 + text.length),
      ChangeSource.local,
    );
    _focusQuestionEditor();
  }

  Future<void> _insertGeometryDiagram() async {
    ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
    final diagram = await GeometryBuilderScreen.show(context);
    if (diagram == null || !mounted) return;

    GeometryDiagramRegistry.instance.save(diagram);
    final range = _safeSelectionRange();
    final data = jsonEncode({
      'id': diagram.id,
      'height': 200.0,
      'widthFactor': 1.0,
      'alignmentX': 0.0,
      'diagram': diagram.toJson(),
    });
    _controller.replaceText(
      range.$1,
      range.$2,
      BlockEmbed.custom(CustomBlockEmbed('geometry', data)),
      null,
    );
    _controller.updateSelection(
      TextSelection.collapsed(offset: range.$1 + 1),
      ChangeSource.local,
    );
  }

  (int, int) _safeSelectionRange() {
    final selection = _controller.selection;
    final documentEnd = (_controller.document.length - 1)
        .clamp(0, 1 << 30)
        .toInt();
    final rawBase = selection.baseOffset < 0
        ? documentEnd
        : selection.baseOffset.clamp(0, documentEnd).toInt();
    final rawExtent = selection.extentOffset < 0
        ? rawBase
        : selection.extentOffset.clamp(0, documentEnd).toInt();
    final start = rawBase <= rawExtent ? rawBase : rawExtent;
    return (start, (rawExtent - rawBase).abs());
  }

  Future<void> _pasteOptions() async {
    final pasteController = TextEditingController();
    final pasted = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paste option list'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: pasteController,
            autofocus: true,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Paste one option per line\nA. First option\nB. Second option',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, pasteController.text),
            child: const Text('Use options'),
          ),
        ],
      ),
    );
    pasteController.dispose();
    if (pasted == null || !mounted) return;

    final lines = pasted
        .split(RegExp(r'[\r\n]+'))
        .map(
          (line) => line
              .replaceFirst(
                RegExp(r'^\s*(?:[A-Ha-h]|\d{1,2})\s*[\.\)\:\-]\s*'),
                '',
              )
              .replaceFirst(RegExp(r'^\s*[•●▪◦]\s*'), '')
              .trim(),
        )
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste at least two non-empty lines.')),
      );
      return;
    }

    final oldControllers = _optionControllers.values.toList();
    setState(() {
      _options = lines
          .map((line) => QuestionOption(id: const Uuid().v4(), text: line))
          .toList();
      _optionControllers.clear();
      _syncOptionControllers();
      _optionsError = null;
    });
    for (final controller in oldControllers) {
      controller.dispose();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _sheetScrollController.dispose();
    _questionScrollController.dispose();
    _questionFocusNode.dispose();
    _marksController.dispose();
    for (final controller in _optionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatMarks(double value) {
    return value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardState = ref.watch(mathKeyboardControllerProvider);
    final isMathActive =
        keyboardState.isVisible && keyboardState.type == KeyboardType.math;
    final maxKeyboardInset = MediaQuery.sizeOf(context).height * 0.62;
    final mathKeyboardInset = isMathActive
        ? keyboardState.height.clamp(0.0, maxKeyboardInset).toDouble()
        : 0.0;
    _controller.readOnly = isMathActive;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetHeightFactor = MediaQuery.sizeOf(context).width < 700 ? 0.98 : 0.9;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            _save(),
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
            _save(addAnother: widget.question == null),
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * sheetHeightFactor,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + mathKeyboardInset,
          left: MediaQuery.sizeOf(context).width < 360 ? 12 : 20,
          right: MediaQuery.sizeOf(context).width < 360 ? 12 : 20,
          top: 20,
        ),
        child: SingleChildScrollView(
          controller: _sheetScrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.question == null ? 'Add Question' : 'Edit Question',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Question type',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuestionTypeChip(
                    label: _type.label,
                    icon: Icons.check_circle_outline_rounded,
                    selected: true,
                    onTap: _showTypePicker,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Change type'),
                    onPressed: _showTypePicker,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Reduce marks',
                    onPressed: () => _setMarks(_marks - 0.5),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _marksController,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'Marks',
                        hintText: 'Example: 2',
                        errorText: _marksError,
                        prefixIcon: const Icon(Icons.score_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (val) {
                        _marks = double.tryParse(val) ?? 0;
                        if (_marksError != null && _marks > 0) {
                          setState(() => _marksError = null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Increase marks',
                    onPressed: () => _setMarks(_marks + 0.5),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final value in const [1.0, 2.0, 3.0, 5.0, 10.0])
                    ChoiceChip(
                      label: Text(_formatMarks(value)),
                      selected: _marks == value,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => _setMarks(value),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: isDark ? 0.1 : 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Optional Question',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Does not count towards total marks',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: _isOptional,
                  onChanged: (val) => setState(() => _isOptional = val),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'Question Content',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addFormula,
                    icon: const Icon(Icons.functions_rounded, size: 18),
                    label: const Text(
                      'Formula',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _insertGeometryDiagram,
                    icon: const Icon(Icons.architecture_outlined, size: 18),
                    label: const Text(
                      'Diagram',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saveAsTemplate,
                    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: const Text(
                      'Template',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final text = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OCRScreen(),
                        ),
                      );
                      if (text != null && mounted) {
                        _insertQuestionText(text);
                      }
                    },
                    icon: const Icon(
                      Icons.document_scanner_outlined,
                      size: 18,
                    ),
                    label: const Text(
                      'Scan',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ],
              ),
              Text(
                'Quick wording',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 7),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final prompt in const [
                      ('Solve', 'Solve: '),
                      ('Find', 'Find the value of '),
                      ('Calculate', 'Calculate '),
                      ('Prove', 'Prove that '),
                      ('Given', 'Given that '),
                      ('Draw', 'Draw a neat labelled diagram of '),
                      ('Reason', 'Give a reason for your answer. '),
                      ('Blank', '__________'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ActionChip(
                          avatar: const Icon(Icons.add_rounded, size: 15),
                          label: Text(prompt.$1),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _insertQuestionText(prompt.$2),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _questionError == null
                        ? (isDark ? Colors.grey[800]! : Colors.grey[200]!)
                        : Colors.redAccent,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  color: isDark ? Colors.grey[900] : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.02,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    QuillSimpleToolbar(
                      controller: _controller,
                      config: const QuillSimpleToolbarConfig(
                        showFontFamily: false,
                        showFontSize: false,
                        showBoldButton: true,
                        showItalicButton: true,
                        showUnderLineButton: true,
                        showListNumbers: true,
                        showListBullets: true,
                        showColorButton: true,
                        showAlignmentButtons: true,
                      ),
                    ),
                    const Divider(height: 1),
                    MathKeyboardField(
                      controller: _controller,
                      focusNode: _questionFocusNode,
                      builder: (context, fieldFocusNode, isMathActive) =>
                          Container(
                            height: 180,
                            padding: const EdgeInsets.all(12),
                            child: QuillEditor(
                              controller: _controller,
                              focusNode: fieldFocusNode,
                              scrollController: _questionScrollController,
                              config: QuillEditorConfig(
                                placeholder: 'Start typing the question...',
                                embedBuilders: [GeometryEmbedBuilder()],
                              ),
                            ),
                          ),
                    ),
                    GeometryAttachmentPreview(
                      listenable: _controller,
                      textProvider: () => _controller.document.toPlainText(),
                    ),
                  ],
                ),
              ),
              if (_questionError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _questionError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
              if (_mathExpressions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Formula blocks',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                for (final entry in _mathExpressions.asMap().entries)
                  Card(
                    child: ListTile(
                      minTileHeight: 64,
                      title: SafeMathExpression(expression: entry.value),
                      subtitle: Text(entry.value.plainText),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit formula',
                            onPressed: () => _editFormula(entry.key),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete formula',
                            onPressed: () => setState(
                              () => _mathExpressions.removeAt(entry.key),
                            ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (_type.usesOptions) ...[
                const SizedBox(height: 24),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        'Options',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pasteOptions,
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                      label: const Text('Paste list'),
                    ),
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text(
                        'Add',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_optionsError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _optionsError!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                RadioGroup<int>(
                  groupValue: _options.indexWhere((option) => option.isCorrect),
                  onChanged: (idx) {
                    if (idx == null) return;
                    setState(() {
                      _options = _options.asMap().entries.map((entry) {
                        return entry.value.copyWith(
                          isCorrect: entry.key == idx,
                        );
                      }).toList();
                    });
                  },
                  child: Column(
                    children: _options.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final opt = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            if (_type.allowsMultipleCorrect)
                              Checkbox(
                                value: opt.isCorrect,
                                activeColor: Colors.green,
                                semanticLabel:
                                    'Mark option ${String.fromCharCode(65 + idx)} correct',
                                onChanged: (value) {
                                  setState(() {
                                    _options[idx] = opt.copyWith(
                                      isCorrect: value == true,
                                    );
                                  });
                                },
                              )
                            else
                              Radio<int>(
                                value: idx,
                                activeColor: Colors.green,
                              ),
                            Expanded(
                              child: Column(
                                children: [
                                  MathKeyboardField(
                                    controller: _optionController(opt),
                                    builder:
                                        (
                                          context,
                                          fieldFocusNode,
                                          isMathActive,
                                        ) {
                                          final controller = _optionController(
                                            opt,
                                          );
                                          return TextField(
                                            controller: controller,
                                            focusNode: fieldFocusNode,
                                            keyboardType: isMathActive
                                                ? TextInputType.none
                                                : TextInputType.text,
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Option ${String.fromCharCode(65 + idx)}',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                              fillColor: opt.isCorrect
                                                  ? Colors.green.withValues(
                                                      alpha: isDark
                                                          ? 0.1
                                                          : 0.05,
                                                    )
                                                  : null,
                                            ),
                                            onChanged: (val) {
                                              _setOptionText(opt.id, val);
                                              if (_optionsError != null) {
                                                setState(
                                                  () => _optionsError = null,
                                                );
                                              }
                                            },
                                          );
                                        },
                                  ),
                                  GeometryAttachmentPreview.textController(
                                    controller: _optionController(opt),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.redAccent,
                                size: 22,
                              ),
                              onPressed: () => _removeOptionAt(idx),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              if (widget.question == null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _save(addAnother: true),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Save & Next'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _save(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                ElevatedButton(
                  onPressed: () => _save(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Question',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionTemplateDetails {
  final String name;
  final String grade;
  final String subject;
  final String chapter;
  final String topic;

  const _QuestionTemplateDetails({
    required this.name,
    required this.grade,
    required this.subject,
    required this.chapter,
    required this.topic,
  });
}

class _QuestionTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _QuestionTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? Colors.white : Colors.blueGrey,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : null,
      ),
      selectedColor: Colors.blue,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
