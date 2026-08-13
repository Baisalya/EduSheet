import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/geometry_builder/services/geometry_diagram_registry.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_builder_screen.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_quick_picker_sheet.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_embed_builder.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_expression_embed_builder.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/safe_math_expression.dart';
import 'package:edusheet/features/paper_composer/application/paper_composer_actions.dart';
import 'package:edusheet/features/paper_composer/application/question_rich_text_codec.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_type_picker.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_more_details_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_composer_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class QuestionComposerPage extends ConsumerStatefulWidget {
  final String sectionId;
  final Question? question;
  final QuestionType? initialType;
  final int? insertAt;

  const QuestionComposerPage({
    super.key,
    required this.sectionId,
    this.question,
    this.initialType,
    this.insertAt,
  });

  @override
  ConsumerState<QuestionComposerPage> createState() =>
      _QuestionComposerPageState();
}

class _QuestionComposerPageState extends ConsumerState<QuestionComposerPage> {
  static const _codec = QuestionRichTextCodec();

  late QuestionDraft _draft;
  late QuillController _bodyController;
  late final TextEditingController _marksController;
  final FocusNode _bodyFocus = FocusNode();
  final ScrollController _bodyScroll = ScrollController();
  final ScrollController _pageScroll = ScrollController();
  final Map<String, TextEditingController> _optionControllers = {};
  late final Set<String> _legacyUnplacedMathIds;
  bool _showFormatting = false;
  String? _bodyError;
  String? _marksError;
  String? _optionsError;

  @override
  void initState() {
    super.initState();
    final defaults = ref.read(questionEditorDefaultsProvider);
    _draft = widget.question == null
        ? QuestionDraft.create(
            type: widget.initialType ?? defaults.type,
            marks: defaults.marks,
            isOptional: defaults.isOptional,
          )
        : QuestionDraft.fromQuestion(widget.question!);
    final bodyDocument = _codec.decodeQuestion(widget.question);
    _bodyController = _createBodyController(bodyDocument);
    final embeddedIds = _codec.embeddedMathExpressionIds(bodyDocument);
    _legacyUnplacedMathIds = _draft.mathExpressions
        .map((expression) => expression.id)
        .where((id) => id.isNotEmpty && !embeddedIds.contains(id))
        .toSet();
    _marksController = TextEditingController(text: _formatMarks(_draft.marks));
    _syncOptionControllers();

    if (widget.question == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bodyFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _marksController.dispose();
    _bodyFocus.dispose();
    _bodyScroll.dispose();
    _pageScroll.dispose();
    for (final controller in _optionControllers.values) {
      controller.dispose();
    }
    try {
      ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
    } catch (_) {
      // Provider scope may already be disposing during teardown.
    }
    super.dispose();
  }

  void _syncOptionControllers() {
    final active = _draft.options.map((item) => item.id).toSet();
    for (final entry in _optionControllers.entries.toList()) {
      if (!active.contains(entry.key)) {
        entry.value.dispose();
        _optionControllers.remove(entry.key);
      }
    }
    for (final option in _draft.options) {
      _optionControllers.putIfAbsent(
        option.id,
        () => TextEditingController(text: option.text),
      );
    }
  }

  Future<void> _chooseType() async {
    final selected = await QuestionTypePicker.show(
      context,
      selected: _draft.type,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _draft = _draft.copyWith(type: selected);
      _optionsError = null;
      _syncOptionControllers();
    });
  }

  void _setMarksFromText(String value) {
    final parsed = double.tryParse(value.trim());
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      setState(() => _marksError = 'Enter marks above 0');
      return;
    }
    setState(() {
      _draft = _draft.copyWith(marks: parsed.clamp(0.5, 100).toDouble());
      _marksError = null;
    });
  }

  void _nudgeMarks(double delta) {
    final next = (_draft.marks + delta).clamp(0.5, 100).toDouble();
    setState(() {
      _draft = _draft.copyWith(marks: next);
      _marksController.text = _formatMarks(next);
      _marksController.selection = TextSelection.collapsed(
        offset: _marksController.text.length,
      );
      _marksError = null;
    });
  }

  QuillController _createBodyController(Document document) {
    return QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  Future<void> _insertFormula({bool autoOpenMathKeyboard = true}) async {
    final insertion = _safeSelectionRange();
    ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
    FocusManager.instance.primaryFocus?.unfocus();
    final expression = await FormulaEditorSheet.show(
      context,
      autoOpenMathKeyboard: autoOpenMathKeyboard,
    );
    if (expression == null || !mounted) return;

    _insertMathAt(expression, insertion);
    setState(() => _bodyError = null);
    _restoreBodyFocus();
  }

  Future<MathExpression?> _editEmbeddedFormula(
    BuildContext formulaContext,
    MathExpression expression,
  ) {
    return FormulaEditorSheet.show(
      formulaContext,
      initial: expression,
      autoOpenMathKeyboard: true,
    );
  }

  List<MathExpression> get _unplacedMathExpressions {
    return _draft.mathExpressions
        .where((expression) => _legacyUnplacedMathIds.contains(expression.id))
        .toList();
  }

  Future<void> _editUnplacedFormula(String expressionId) async {
    final index = _draft.mathExpressions.indexWhere(
      (expression) => expression.id == expressionId,
    );
    if (index < 0) return;
    final expression = await FormulaEditorSheet.show(
      context,
      initial: _draft.mathExpressions[index],
      autoOpenMathKeyboard: true,
    );
    if (expression == null || !mounted) return;
    final formulas = [..._draft.mathExpressions]..[index] = expression;
    setState(() => _draft = _draft.copyWith(mathExpressions: formulas));
  }

  void _removeUnplacedFormula(String expressionId) {
    final formulas = _draft.mathExpressions
        .where((expression) => expression.id != expressionId)
        .toList();
    setState(() {
      _legacyUnplacedMathIds.remove(expressionId);
      _draft = _draft.copyWith(mathExpressions: formulas);
    });
  }

  void _placeUnplacedFormula(MathExpression expression) {
    final insertion = _safeSelectionRange();
    _insertMathAt(expression, insertion);
    setState(() {
      _legacyUnplacedMathIds.remove(expression.id);
      _bodyError = null;
    });
    _restoreBodyFocus();
  }

  void _insertMathAt(MathExpression expression, (int, int) selection) {
    var start = selection.$1;
    final length = selection.$2;

    if (expression.display == MathExpressionDisplay.inline) {
      _bodyController.replaceText(
        start,
        length,
        MathExpressionEmbed(expression),
        null,
      );
      _bodyController.updateSelection(
        TextSelection.collapsed(offset: start + 1),
        ChangeSource.local,
      );
      return;
    }

    if (length > 0) {
      _bodyController.replaceText(start, length, '', null);
    }
    var text = _bodyController.document.toPlainText();
    if (start > 0 && start <= text.length && text[start - 1] != '\n') {
      _bodyController.replaceText(start, 0, '\n', null);
      start += 1;
    }
    _bodyController.replaceText(
      start,
      0,
      MathExpressionEmbed(expression),
      null,
    );
    text = _bodyController.document.toPlainText();
    final after = start + 1;
    if (after >= text.length || text[after] != '\n') {
      _bodyController.replaceText(after, 0, '\n', null);
    }
    _bodyController.updateSelection(
      TextSelection.collapsed(offset: start + 2),
      ChangeSource.local,
    );
  }

  void _restoreBodyFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bodyFocus.requestFocus();
    });
  }

  Future<void> _editMoreDetails() async {
    final details = await QuestionMoreDetailsSheet.show(
      context,
      initial: _draft.details,
    );
    if (details == null || !mounted) return;
    setState(() => _draft = _draft.copyWith(details: details));
  }

  Future<void> _insertGeometry() async {
    ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
    FocusManager.instance.primaryFocus?.unfocus();
    final shape = await GeometryQuickPickerSheet.show(context);
    if (shape == null || !mounted) return;
    final diagram = await GeometryBuilderScreen.show(
      context,
      initialShape: shape,
    );
    if (diagram == null || !mounted) return;

    GeometryDiagramRegistry.instance.save(diagram);
    final selection = _safeSelectionRange();
    final data = jsonEncode({
      'id': diagram.id,
      'height': 200.0,
      'widthFactor': 1.0,
      'alignmentX': 0.0,
      'diagram': diagram.toJson(),
    });
    _bodyController.replaceText(
      selection.$1,
      selection.$2,
      BlockEmbed.custom(CustomBlockEmbed('geometry', data)),
      null,
    );
    _bodyController.updateSelection(
      TextSelection.collapsed(offset: selection.$1 + 1),
      ChangeSource.local,
    );
    setState(() => _bodyError = null);
  }

  (int, int) _safeSelectionRange() {
    final selection = _bodyController.selection;
    final documentEnd = (_bodyController.document.length - 1)
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

  void _insertPrompt(String value) {
    final selection = _safeSelectionRange();
    _bodyController.replaceText(selection.$1, selection.$2, value, null);
    _bodyController.updateSelection(
      TextSelection.collapsed(offset: selection.$1 + value.length),
      ChangeSource.local,
    );
    _bodyFocus.requestFocus();
  }

  void _addOption() {
    final option = QuestionOption(id: const Uuid().v4(), text: '');
    setState(() {
      _draft = _draft.copyWith(options: [..._draft.options, option]);
      _syncOptionControllers();
    });
  }

  void _removeOption(String optionId) {
    if (_draft.options.length <= 2) return;
    setState(() {
      _draft = _draft.copyWith(
        options: _draft.options.where((item) => item.id != optionId).toList(),
      );
      _syncOptionControllers();
    });
  }

  void _toggleCorrect(String optionId) {
    final multiple = _draft.type.allowsMultipleCorrect;
    final options = _draft.options.map((option) {
      if (option.id == optionId) {
        return option.copyWith(isCorrect: !option.isCorrect);
      }
      return multiple ? option : option.copyWith(isCorrect: false);
    }).toList();
    setState(() => _draft = _draft.copyWith(options: options));
  }

  List<QuestionOption> _materializedOptions() {
    return _draft.options.map((option) {
      return option.copyWith(text: _optionControllers[option.id]?.text ?? option.text);
    }).toList();
  }

  bool _validate() {
    final accessibility = _codec.accessibleText(_bodyController.document);
    final hasContent = accessibility.isNotEmpty || _unplacedMathExpressions.isNotEmpty;
    final marks = double.tryParse(_marksController.text.trim());
    final options = _materializedOptions();
    final nonEmptyOptions = options.where((item) => item.text.trim().isNotEmpty).length;
    final validMarks = marks != null && marks.isFinite && marks > 0;

    setState(() {
      _bodyError = hasContent ? null : 'Write the question or add a formula/diagram';
      _marksError = validMarks ? null : 'Enter marks above 0';
      _optionsError = _draft.type.usesOptions && nonEmptyOptions < 2
          ? 'Add at least two answer options'
          : null;
    });
    return _bodyError == null && _marksError == null && _optionsError == null;
  }

  Future<void> _save({bool addAnother = false}) async {
    _setMarksFromText(_marksController.text);
    if (!_validate()) return;

    final encoded = _codec.encode(_bodyController.document);
    final bodyAccessibility = _codec.accessibleText(_bodyController.document);
    final embeddedMath = _codec.embeddedMathExpressions(_bodyController.document);
    final embeddedIds = embeddedMath.map((expression) => expression.id).toSet();
    final unplacedMath = _unplacedMathExpressions
        .where((expression) => !embeddedIds.contains(expression.id))
        .toList();
    final savedMathExpressions = [...embeddedMath, ...unplacedMath];
    final accessibility = [
      bodyAccessibility,
      ...unplacedMath.map((expression) {
        final plain = expression.plainText.trim();
        return plain.isEmpty ? expression.latex : plain;
      }),
    ].where((item) => item.trim().isNotEmpty).join(' ');
    final options = _draft.type.usesOptions
        ? _materializedOptions()
            .where((item) => item.text.trim().isNotEmpty)
            .map((item) => item.copyWith(text: item.text.trim()))
            .toList()
        : <QuestionOption>[];
    final draft = _draft.copyWith(
      text: encoded,
      options: options,
      mathExpressions: savedMathExpressions,
      marks: double.parse(_marksController.text.trim()).clamp(0.5, 100).toDouble(),
    );

    final paper = ref.read(editorStateProvider);
    final actions = PaperComposerActions(ref.read(editorStateProvider.notifier));
    final saved = actions.saveQuestion(
      paper: paper,
      sectionId: widget.sectionId,
      draft: draft,
      plainTextAccessibility: accessibility,
      insertAt: widget.insertAt,
    );
    if (!saved) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This section no longer exists. The question was not saved.'),
        ),
      );
      return;
    }
    ref.read(questionEditorDefaultsProvider.notifier).state =
        QuestionEditorDefaults(
          type: draft.type,
          marks: draft.marks,
          isOptional: draft.isOptional,
        );

    if (!addAnother || widget.question != null) {
      if (mounted) Navigator.pop(context, true);
      return;
    }

    _resetForNext(draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Question saved. Ready for the next one.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 850),
      ),
    );
  }

  void _resetForNext(QuestionDraft previous) {
    ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
    final oldBody = _bodyController;
    final oldOptionControllers = Map<String, TextEditingController>.from(
      _optionControllers,
    );
    setState(() {
      _draft = QuestionDraft.create(
        type: previous.type,
        marks: previous.marks,
        isOptional: previous.isOptional,
      );
      _bodyController = _createBodyController(Document());
      _legacyUnplacedMathIds.clear();
      _marksController.text = _formatMarks(previous.marks);
      _optionControllers.clear();
      _syncOptionControllers();
      _bodyError = null;
      _marksError = null;
      _optionsError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Dispose only after QuillEditor has rebuilt around
      // the new controllers. This avoids a mounted widget briefly observing a
      // controller that was already disposed.
      oldBody.dispose();
      for (final controller in oldOptionControllers.values) {
        controller.dispose();
      }
      if (mounted) _bodyFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = ref.watch(mathKeyboardControllerProvider);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final adaptiveMax = (screenHeight * 0.62).clamp(240.0, 500.0).toDouble();
    final adaptiveMin = adaptiveMax < 280 ? adaptiveMax : 280.0;
    final mathInset = keyboard.isVisible && keyboard.type == KeyboardType.math
        ? keyboard.height.clamp(adaptiveMin, adaptiveMax).toDouble()
        : 0.0;
    final compact = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: compact ? 4 : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.question == null ? 'New question' : 'Edit question'),
            Text(
              '${_draft.type.label} · ${_formatMarks(_draft.marks)} marks',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          if (!compact)
            TextButton.icon(
              onPressed: () => _save(),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save'),
            ),
          if (compact)
            IconButton(
              tooltip: 'Save question',
              onPressed: () => _save(),
              icon: const Icon(Icons.check_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _pageScroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 24,
                  12,
                  compact ? 12 : 24,
                  20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPrimaryControls(context, compact),
                        const SizedBox(height: 14),
                        _buildQuestionEditor(context, compact),
                        if (_bodyError != null) ...[
                          const SizedBox(height: 6),
                          ComposerErrorText(_bodyError!),
                        ],
                        const SizedBox(height: 12),
                        _buildInsertBar(context),
                        if (_unplacedMathExpressions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildLegacyFormulaTray(context),
                        ],
                        if (_draft.type.usesOptions) ...[
                          const SizedBox(height: 20),
                          _buildOptions(context),
                        ],
                        const SizedBox(height: 16),
                        SwitchListTile.adaptive(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          title: const Text('Optional / OR choice'),
                          subtitle: const Text(
                            'This question does not count toward compulsory marks.',
                          ),
                          value: _draft.isOptional,
                          onChanged: (value) => setState(
                            () => _draft = _draft.copyWith(isOptional: value),
                          ),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: _editMoreDetails,
                          icon: Icon(
                            _draft.details.hasTeacherDetails
                                ? Icons.fact_check_rounded
                                : Icons.tune_rounded,
                          ),
                          label: Text(
                            _draft.details.hasTeacherDetails
                                ? 'Answer & details added'
                                : 'Answer & more details',
                          ),
                        ),
                        const SizedBox(height: 88),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildBottomBar(context, compact, mathInset),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryControls(BuildContext context, bool compact) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: compact
            ? Column(
                children: [
                  QuestionTypeControl(type: _draft.type, onTap: _chooseType),
                  const SizedBox(height: 10),
                  QuestionMarksControl(
                    controller: _marksController,
                    errorText: _marksError,
                    onChanged: _setMarksFromText,
                    onDecrease: () => _nudgeMarks(-0.5),
                    onIncrease: () => _nudgeMarks(0.5),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: QuestionTypeControl(type: _draft.type, onTap: _chooseType)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 280,
                    child: QuestionMarksControl(
                      controller: _marksController,
                      errorText: _marksError,
                      onChanged: _setMarksFromText,
                      onDecrease: () => _nudgeMarks(-0.5),
                      onIncrease: () => _nudgeMarks(0.5),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildQuestionEditor(BuildContext context, bool compact) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _bodyError == null
              ? theme.colorScheme.outlineVariant
              : theme.colorScheme.error,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            child: Row(
              children: [
                const Icon(Icons.edit_note_rounded, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Question',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: _showFormatting ? 'Hide formatting' : 'Text formatting',
                  onPressed: () => setState(() => _showFormatting = !_showFormatting),
                  icon: Icon(
                    _showFormatting
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.format_bold_rounded,
                  ),
                ),
                ],
            ),
          ),
          if (_showFormatting) ...[
            const Divider(height: 1),
            QuillSimpleToolbar(
              controller: _bodyController,
              config: const QuillSimpleToolbarConfig(
                showFontFamily: false,
                showFontSize: false,
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showStrikeThrough: false,
                showInlineCode: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                showClearFormat: true,
                showHeaderStyle: false,
                showListNumbers: true,
                showListBullets: true,
                showListCheck: false,
                showCodeBlock: false,
                showQuote: false,
                showIndent: false,
                showLink: false,
                showUndo: false,
                showRedo: false,
                showDirection: false,
                showAlignmentButtons: false,
                showSubscript: false,
                showSuperscript: false,
                showSearchButton: false,
                multiRowsDisplay: false,
              ),
            ),
          ],
          const Divider(height: 1),
          SizedBox(
            height: compact ? 220 : 260,
            child: QuillEditor(
              controller: _bodyController,
              focusNode: _bodyFocus,
              scrollController: _bodyScroll,
              config: QuillEditorConfig(
                placeholder: 'Type the question exactly as students should read it…',
                padding: const EdgeInsets.all(14),
                embedBuilders: [
                  GeometryEmbedBuilder(),
                  MathExpressionEmbedBuilder(
                    onEdit: _editEmbeddedFormula,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsertBar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            QuestionInsertAction(
              icon: Icons.functions_rounded,
              label: 'Math',
              onTap: _insertFormula,
            ),
            QuestionInsertAction(
              icon: Icons.category_outlined,
              label: 'Geometry',
              onTap: _insertGeometry,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
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
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(prompt.$1),
                    onPressed: () => _insertPrompt(prompt.$2),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegacyFormulaTray(BuildContext context) {
    final formulas = _unplacedMathExpressions;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Math from an older question',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'These formulas were saved before inline math was available. Put the cursor where each formula belongs and choose Insert here.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final expression in formulas)
              Card(
                elevation: 0,
                child: ListTile(
                  minTileHeight: 64,
                  onTap: () => _editUnplacedFormula(expression.id),
                  title: SafeMathExpression(expression: expression),
                  subtitle: const Text('Tap formula to edit'),
                  trailing: Wrap(
                    spacing: 2,
                    children: [
                      IconButton(
                        tooltip: 'Insert at cursor',
                        onPressed: () => _placeUnplacedFormula(expression),
                        icon: const Icon(Icons.subdirectory_arrow_left_rounded),
                      ),
                      IconButton(
                        tooltip: 'Remove formula',
                        onPressed: () => _removeUnplacedFormula(expression.id),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Answer options',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addOption,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add option'),
            ),
          ],
        ),
        Text(
          _draft.type.allowsMultipleCorrect
              ? 'Tap the check circles to mark every correct answer.'
              : 'Tap one circle to mark the correct answer.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        for (final entry in _draft.options.asMap().entries)
          QuestionOptionEditor(
            key: ValueKey(entry.value.id),
            index: entry.key,
            option: entry.value,
            controller: _optionControllers[entry.value.id]!,
            canRemove: _draft.options.length > 2,
            onToggleCorrect: () => _toggleCorrect(entry.value.id),
            onRemove: () => _removeOption(entry.value.id),
          ),
        if (_optionsError != null) ComposerErrorText(_optionsError!),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, bool compact, double mathInset) {
    final mathVisible = mathInset > 0;
    final theme = Theme.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 280),
      curve: Curves.fastOutSlowIn,
      padding: EdgeInsets.only(bottom: mathInset),
      child: Material(
        elevation: 12,
        color: theme.colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                if (mathVisible)
                  IconButton.filledTonal(
                    tooltip: 'Close math keyboard',
                    onPressed: () => ref
                        .read(mathKeyboardControllerProvider.notifier)
                        .hideKeyboard(),
                    icon: const Icon(Icons.keyboard_hide_rounded),
                  ),
                if (mathVisible) const SizedBox(width: 8),
                if (widget.question == null)
                  Expanded(
                    child: compact
                        ? OutlinedButton(
                            onPressed: () => _save(addAnother: true),
                            child: const Text('Save & next'),
                          )
                        : OutlinedButton.icon(
                            onPressed: () => _save(addAnother: true),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Save and add next'),
                          ),
                  ),
                if (widget.question == null) const SizedBox(width: 8),
                Expanded(
                  child: compact
                      ? FilledButton(
                          onPressed: () => _save(),
                          child: const Text('Save'),
                        )
                      : FilledButton.icon(
                          onPressed: () => _save(),
                          icon: const Icon(Icons.check_rounded),
                          label: Text(
                            widget.question == null
                                ? 'Save question'
                                : 'Save changes',
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatMarks(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
}
