import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/question_option_layout.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/geometry_builder/services/geometry_diagram_registry.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_builder_screen.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_embed_builder.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_expression_embed_builder.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/safe_math_expression.dart';
import 'package:edusheet/features/ocr/presentation/screens/ocr_screen.dart';
import 'package:edusheet/features/paper_composer/application/paper_composer_actions.dart';
import 'package:edusheet/features/paper_composer/application/question_advanced_structure_service.dart';
import 'package:edusheet/features/paper_composer/application/question_authoring_text_tools.dart';
import 'package:edusheet/features/paper_composer/application/question_insertion_anchor.dart';
import 'package:edusheet/features/paper_composer/application/question_rich_text_codec.dart';
import 'package:edusheet/features/paper_composer/application/universal_question_adapter.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_add_content_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_advanced_content_panel.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_answer_space_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_image_attachment_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_stimulus_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_table_editor_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_word_bank_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_composer_controls.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_more_details_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_type_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

typedef QuestionSaveCallback = Future<bool> Function(Question question);

class QuestionComposerPage extends ConsumerStatefulWidget {
  final String? sectionId;
  final Question? question;
  final QuestionType? initialType;
  final double? initialMarks;
  final int? insertAt;
  final QuestionSaveCallback? onSaveQuestion;
  final String? pageTitle;
  final bool allowSaveAndNext;
  final bool preserveDetailsOnSaveAndNext;

  const QuestionComposerPage({
    super.key,
    this.sectionId,
    this.question,
    this.initialType,
    this.initialMarks,
    this.insertAt,
    this.onSaveQuestion,
    this.pageTitle,
    this.allowSaveAndNext = true,
    this.preserveDetailsOnSaveAndNext = false,
  }) : assert(
         sectionId != null || onSaveQuestion != null,
         'A paper section or external question save callback is required.',
       );

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
  final GlobalKey _questionEditorKey = GlobalKey();
  late final Set<String> _legacyUnplacedMathIds;
  late final ValueNotifier<QuestionInsertionAnchor> _insertionAnchor;
  bool _bodyHasFocus = false;
  bool _showFormatting = false;
  String? _bodyError;
  String? _marksError;
  String? _optionsError;
  String? _structureError;

  @override
  void initState() {
    super.initState();
    final defaults = ref.read(questionEditorDefaultsProvider);
    _draft = widget.question == null
        ? QuestionDraft.create(
            type: widget.initialType ?? defaults.type,
            marks: widget.initialMarks ?? defaults.marks,
            isOptional: defaults.isOptional,
          )
        : QuestionDraft.fromQuestion(widget.question!);
    final bodyDocument = _codec.decodeQuestion(widget.question);
    _bodyController = _createBodyController(bodyDocument);
    _insertionAnchor = ValueNotifier(_anchorFromController());
    _bodyFocus.addListener(_handleBodyFocusChanged);
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
    _bodyController.removeListener(_handleBodyControllerChanged);
    _bodyController.dispose();
    _marksController.dispose();
    _bodyFocus.removeListener(_handleBodyFocusChanged);
    _bodyFocus.dispose();
    _insertionAnchor.dispose();
    _bodyScroll.dispose();
    _pageScroll.dispose();
    for (final controller in _optionControllers.values) {
      controller.dispose();
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
      _draft = _draft.applyQuickStart(selected);
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
    final controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    controller.addListener(_handleBodyControllerChanged);
    return controller;
  }

  QuestionInsertionAnchor _anchorFromController() {
    final selection = _bodyController.selection;
    final documentEnd = (_bodyController.document.length - 1)
        .clamp(0, 1 << 30)
        .toInt();
    return QuestionInsertionAnchor.fromDocument(
      plainText: _bodyController.document.toPlainText(),
      documentEnd: documentEnd,
      baseOffset: selection.baseOffset,
      extentOffset: selection.extentOffset,
    );
  }

  void _handleBodyControllerChanged() {
    if (!mounted || !_bodyFocus.hasFocus) return;
    _syncInsertionAnchorFromController();
  }

  void _syncInsertionAnchorFromController() {
    final next = _anchorFromController();
    if (_insertionAnchor.value != next) {
      _insertionAnchor.value = next;
    }
  }

  void _handleBodyFocusChanged() {
    if (!mounted) return;
    final focused = _bodyFocus.hasFocus;
    if (focused) {
      _rememberInsertionAnchor();
    }
    if (_bodyHasFocus != focused) {
      setState(() => _bodyHasFocus = focused);
    }
  }

  QuestionInsertionAnchor _rememberInsertionAnchor() {
    _syncInsertionAnchorFromController();
    return _insertionAnchor.value;
  }

  QuestionInsertionAnchor _toolInsertionAnchor() {
    return _bodyFocus.hasFocus
        ? _rememberInsertionAnchor()
        : _insertionAnchor.value;
  }

  void _returnToInsertion(
    QuestionInsertionAnchor anchor, {
    bool ensureEditorVisible = true,
  }) {
    final documentEnd = (_bodyController.document.length - 1)
        .clamp(0, 1 << 30)
        .toInt();
    final start = anchor.start.clamp(0, documentEnd).toInt();
    final end = (start + anchor.length).clamp(start, documentEnd).toInt();
    _bodyController.updateSelection(
      TextSelection(baseOffset: start, extentOffset: end),
      ChangeSource.local,
    );
    _insertionAnchor.value = _anchorFromController();
    _restoreBodyFocus(ensureEditorVisible: ensureEditorVisible);
  }

  void _returnToSavedInsertion() {
    _returnToInsertion(_insertionAnchor.value);
  }

  void _toggleFormatting() {
    final anchor = _toolInsertionAnchor();
    setState(() => _showFormatting = !_showFormatting);
    _returnToInsertion(anchor);
  }

  void _undoBody() {
    if (!_bodyController.hasUndo) return;
    _bodyController.undo();
    _rememberInsertionAnchor();
    _restoreBodyFocus(ensureEditorVisible: true);
  }

  void _redoBody() {
    if (!_bodyController.hasRedo) return;
    _bodyController.redo();
    _rememberInsertionAnchor();
    _restoreBodyFocus(ensureEditorVisible: true);
  }

  Future<void> _insertFormula({
    bool autoOpenMathKeyboard = true,
    QuestionInsertionAnchor? insertionAnchor,
  }) async {
    final targetAnchor = insertionAnchor ?? _toolInsertionAnchor();
    final insertion = _safeSelectionRange(anchor: targetAnchor);
    ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
    FocusManager.instance.primaryFocus?.unfocus();
    final expression = await FormulaEditorSheet.show(
      context,
      autoOpenMathKeyboard: autoOpenMathKeyboard,
    );
    if (expression == null || !mounted) {
      if (mounted) _returnToInsertion(targetAnchor);
      return;
    }

    _insertMathAt(expression, insertion);
    _syncInsertionAnchorFromController();
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

  bool get _hasAdvancedPaperBlocks =>
      _draft.advancedContent.hasAny ||
      _draft.tableData != null ||
      _draft.attachments.isNotEmpty ||
      _draft.subQuestions.isNotEmpty ||
      _draft.internalChoices.isNotEmpty;

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
    final anchor = _toolInsertionAnchor();
    final insertion = _safeSelectionRange(anchor: anchor);
    _insertMathAt(expression, insertion);
    _syncInsertionAnchorFromController();
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

  void _restoreBodyFocus({bool ensureEditorVisible = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bodyFocus.requestFocus();
      if (ensureEditorVisible) {
        final editorContext = _questionEditorKey.currentContext;
        if (editorContext != null) {
          Scrollable.ensureVisible(
            editorContext,
            alignment: 0.12,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
          );
        }
      }
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

  Future<void> _editStimulus() async {
    final stimulus = await QuestionStimulusSheet.show(
      context,
      initial: _draft.advancedContent.stimulus,
    );
    if (stimulus == null || !mounted) return;
    setState(() {
      _draft = _draft.copyWith(
        advancedContent: _draft.advancedContent.copyWith(stimulus: stimulus),
      );
    });
  }

  void _removeStimulus() {
    setState(() {
      _draft = _draft.copyWith(
        advancedContent: _draft.advancedContent.copyWith(clearStimulus: true),
      );
    });
  }

  Future<void> _editWordBank() async {
    final items = await QuestionWordBankSheet.show(
      context,
      initial: _draft.advancedContent.wordBank,
    );
    if (items == null || !mounted) return;
    setState(() {
      _draft = _draft.copyWith(
        advancedContent: _draft.advancedContent.copyWith(wordBank: items),
      );
    });
  }

  void _removeWordBank() {
    setState(() {
      _draft = _draft.copyWith(
        advancedContent: _draft.advancedContent.copyWith(wordBank: const []),
      );
    });
  }

  Future<void> _editTable() async {
    final table = await QuestionTableEditorSheet.show(
      context,
      initial: _draft.tableData,
    );
    if (table == null || !mounted) return;
    setState(() => _draft = _draft.copyWith(tableData: table));
  }

  void _removeTable() {
    setState(() => _draft = _draft.copyWith(clearTableData: true));
  }

  Future<void> _addImage() async {
    final attachment = await QuestionImageAttachmentSheet.show(context);
    if (attachment == null || !mounted) return;
    setState(() {
      _draft = _draft.copyWith(
        attachments: [..._draft.attachments, attachment],
      );
    });
  }

  Future<void> _editImage(QuestionAttachment current) async {
    final attachment = await QuestionImageAttachmentSheet.show(
      context,
      initial: current,
    );
    if (attachment == null || !mounted) return;
    setState(() {
      _draft = _draft.copyWith(
        attachments: _draft.attachments
            .map((item) => item.id == current.id ? attachment : item)
            .toList(),
      );
    });
  }

  void _removeImage(QuestionAttachment current) {
    setState(() {
      _draft = _draft.copyWith(
        attachments: _draft.attachments
            .where((item) => item.id != current.id)
            .toList(),
      );
    });
  }

  Future<void> _addSubQuestion() {
    return _openNestedQuestion(internalChoice: false);
  }

  Future<void> _editSubQuestion(int index) {
    if (index < 0 || index >= _draft.subQuestions.length) {
      return Future.value();
    }
    return _openNestedQuestion(
      internalChoice: false,
      index: index,
      initial: _draft.subQuestions[index],
    );
  }

  void _removeSubQuestion(int index) {
    if (index < 0 || index >= _draft.subQuestions.length) return;
    final next = [..._draft.subQuestions]..removeAt(index);
    setState(() => _draft = _draft.copyWith(subQuestions: next));
  }

  Future<void> _addInternalChoice() {
    return _openNestedQuestion(internalChoice: true);
  }

  Future<void> _editInternalChoice(int index) {
    if (index < 0 || index >= _draft.internalChoices.length) {
      return Future.value();
    }
    return _openNestedQuestion(
      internalChoice: true,
      index: index,
      initial: _draft.internalChoices[index],
    );
  }

  void _removeInternalChoice(int index) {
    if (index < 0 || index >= _draft.internalChoices.length) return;
    final next = [..._draft.internalChoices]..removeAt(index);
    setState(() => _draft = _draft.copyWith(internalChoices: next));
  }

  Future<void> _openNestedQuestion({
    required bool internalChoice,
    int? index,
    Question? initial,
  }) async {
    ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
    FocusManager.instance.primaryFocus?.unfocus();
    final currentList = internalChoice
        ? _draft.internalChoices
        : _draft.subQuestions;
    final nextIndex = index ?? currentList.length;
    final title = internalChoice
        ? 'OR alternative ${nextIndex + 1}'
        : 'Part ${QuestionAdvancedStructureService.partLabel(nextIndex)}';
    final suggestedMarks = internalChoice
        ? (_draft.internalChoices.isNotEmpty
              ? _draft.internalChoices.first.marks
              : _draft.marks)
        : 1.0;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => QuestionComposerPage(
          question: initial,
          initialType: QuestionType.descriptive,
          initialMarks: suggestedMarks,
          onSaveQuestion: (question) async {
            if (!mounted) return false;
            setState(() {
              final target = internalChoice
                  ? [..._draft.internalChoices]
                  : [..._draft.subQuestions];
              if (index == null) {
                target.add(question);
              } else if (index >= 0 && index < target.length) {
                target[index] = question;
              }
              _draft = internalChoice
                  ? _draft.copyWith(
                      type: QuestionType.internalChoice,
                      internalChoices: target,
                    )
                  : _draft.copyWith(subQuestions: target);
            });
            return true;
          },
          pageTitle: title,
          allowSaveAndNext: false,
        ),
      ),
    );
  }

  Future<void> _editAnswerSpace() async {
    final value = await QuestionAnswerSpaceSheet.show(
      context,
      initial: _draft.advancedContent.answerSpace,
    );
    if (value == null || !mounted) return;
    setState(() {
      _draft = _draft.copyWith(
        advancedContent: _draft.advancedContent.copyWith(answerSpace: value),
      );
    });
  }

  void _removeAnswerSpace() {
    setState(() {
      _draft = _draft.copyWith(
        advancedContent: _draft.advancedContent.copyWith(
          answerSpace: const QuestionAnswerSpace(),
        ),
      );
    });
  }

  Future<void> _insertGeometry({
    QuestionInsertionAnchor? insertionAnchor,
  }) async {
    // Preserve the exact caret/range before opening the full-screen geometry
    // builder. Route/focus changes must not decide where the diagram lands.
    final targetAnchor = insertionAnchor ?? _toolInsertionAnchor();
    final insertion = _safeSelectionRange(anchor: targetAnchor);
    ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
    FocusManager.instance.primaryFocus?.unfocus();
    final diagram = await GeometryBuilderScreen.show(context);
    if (diagram == null || !mounted) {
      if (mounted) _returnToInsertion(targetAnchor);
      return;
    }

    GeometryDiagramRegistry.instance.save(diagram);
    final data = jsonEncode({
      'id': diagram.id,
      'height': 200.0,
      'widthFactor': 1.0,
      'alignmentX': 0.0,
      'diagram': diagram.toJson(),
    });
    _insertGeometryAt(data, insertion);
    _syncInsertionAnchorFromController();
    setState(() => _bodyError = null);
    _restoreBodyFocus();
  }

  void _insertGeometryAt(String data, (int, int) selection) {
    var start = selection.$1;
    final length = selection.$2;

    if (length > 0) {
      _bodyController.replaceText(start, length, '', null);
    }

    // Geometry is a block embed. Keep it on its own line and always create a
    // real paragraph after it so the user can continue typing immediately.
    var text = _bodyController.document.toPlainText();
    if (start > 0 && start <= text.length && text[start - 1] != '\n') {
      _bodyController.replaceText(start, 0, '\n', null);
      start += 1;
    }

    _bodyController.replaceText(
      start,
      0,
      BlockEmbed.custom(CustomBlockEmbed('geometry', data)),
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

  Future<void> _scanQuestionText({
    QuestionInsertionAnchor? insertionAnchor,
  }) async {
    final targetAnchor = insertionAnchor ?? _toolInsertionAnchor();
    final insertion = _safeSelectionRange(anchor: targetAnchor);
    ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
    FocusManager.instance.primaryFocus?.unfocus();
    final scanned = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (context) => const OCRScreen()));
    if (scanned == null || scanned.trim().isEmpty || !mounted) {
      if (mounted) _returnToInsertion(targetAnchor);
      return;
    }
    final text = scanned.trim();
    _bodyController.replaceText(insertion.$1, insertion.$2, text, null);
    _bodyController.updateSelection(
      TextSelection.collapsed(offset: insertion.$1 + text.length),
      ChangeSource.local,
    );
    _syncInsertionAnchorFromController();
    setState(() => _bodyError = null);
    _restoreBodyFocus();
  }

  (int, int) _safeSelectionRange({QuestionInsertionAnchor? anchor}) {
    final target = anchor ?? _toolInsertionAnchor();
    final documentEnd = (_bodyController.document.length - 1)
        .clamp(0, 1 << 30)
        .toInt();
    final start = target.start.clamp(0, documentEnd).toInt();
    final length = target.length.clamp(0, documentEnd - start).toInt();
    return (start, length);
  }

  void _insertPrompt(String value) {
    final anchor = _toolInsertionAnchor();
    final selection = _safeSelectionRange(anchor: anchor);
    _bodyController.replaceText(selection.$1, selection.$2, value, null);
    _bodyController.updateSelection(
      TextSelection.collapsed(offset: selection.$1 + value.length),
      ChangeSource.local,
    );
    _syncInsertionAnchorFromController();
    _bodyFocus.requestFocus();
  }

  void _insertEditableText(
    String value, {
    QuestionInsertionAnchor? insertionAnchor,
  }) {
    final selection = _safeSelectionRange(anchor: insertionAnchor);
    _bodyController.replaceText(selection.$1, selection.$2, value, null);
    _bodyController.updateSelection(
      TextSelection.collapsed(offset: selection.$1 + value.length),
      ChangeSource.local,
    );
    _syncInsertionAnchorFromController();
    setState(() => _bodyError = null);
    _restoreBodyFocus();
  }

  void _insertBlank({QuestionInsertionAnchor? insertionAnchor}) {
    _insertEditableText(
      QuestionAuthoringTextTools.blank(),
      insertionAnchor: insertionAnchor,
    );
  }

  void _insertSubQuestion({QuestionInsertionAnchor? insertionAnchor}) {
    final target = insertionAnchor ?? _toolInsertionAnchor();
    final plainText = _bodyController.document.toPlainText();
    final before = plainText.substring(
      0,
      target.start.clamp(0, plainText.length).toInt(),
    );
    _insertEditableText(
      QuestionAuthoringTextTools.nextSubQuestionInsertion(
        plainText,
        textBeforeInsertion: before,
      ),
      insertionAnchor: target,
    );
  }

  void _insertOrDivider({QuestionInsertionAnchor? insertionAnchor}) {
    final target = insertionAnchor ?? _toolInsertionAnchor();
    final plainText = _bodyController.document.toPlainText();
    final before = plainText.substring(
      0,
      target.start.clamp(0, plainText.length).toInt(),
    );
    _insertEditableText(
      QuestionAuthoringTextTools.orDividerInsertion(
        plainText,
        textBeforeInsertion: before,
      ),
      insertionAnchor: target,
    );
  }

  void _insertInstruction({QuestionInsertionAnchor? insertionAnchor}) {
    final target = insertionAnchor ?? _toolInsertionAnchor();
    final plainText = _bodyController.document.toPlainText();
    final before = plainText.substring(
      0,
      target.start.clamp(0, plainText.length).toInt(),
    );
    _insertEditableText(
      QuestionAuthoringTextTools.instructionInsertion(
        plainText,
        textBeforeInsertion: before,
      ),
      insertionAnchor: target,
    );
  }

  void _ensureAnswerOptions() {
    setState(() {
      _draft = _draft.ensureAnswerOptions();
      _optionsError = null;
      _syncOptionControllers();
    });
  }

  Future<void> _showAddContent() async {
    // Capture before the sheet opens. Bottom sheets and routes can temporarily
    // move focus away from Quill; the teacher's chosen insertion point must
    // survive that transition unchanged.
    final insertionAnchor = _toolInsertionAnchor();
    final action = await QuestionAddContentSheet.show(
      context,
      insertionAnchor: insertionAnchor,
    );
    if (action == null || !mounted) {
      if (mounted) _returnToInsertion(insertionAnchor);
      return;
    }
    switch (action) {
      case QuestionAddContentAction.math:
        await _insertFormula(insertionAnchor: insertionAnchor);
        break;
      case QuestionAddContentAction.geometry:
        await _insertGeometry(insertionAnchor: insertionAnchor);
        break;
      case QuestionAddContentAction.blank:
        _insertBlank(insertionAnchor: insertionAnchor);
        break;
      case QuestionAddContentAction.subQuestion:
        _insertSubQuestion(insertionAnchor: insertionAnchor);
        break;
      case QuestionAddContentAction.orDivider:
        _insertOrDivider(insertionAnchor: insertionAnchor);
        break;
      case QuestionAddContentAction.answerOptions:
        _ensureAnswerOptions();
        break;
      case QuestionAddContentAction.stimulus:
        await _editStimulus();
        break;
      case QuestionAddContentAction.wordBank:
        await _editWordBank();
        break;
      case QuestionAddContentAction.table:
        await _editTable();
        break;
      case QuestionAddContentAction.image:
        await _addImage();
        break;
      case QuestionAddContentAction.structuredPart:
        await _addSubQuestion();
        break;
      case QuestionAddContentAction.internalChoice:
        await _addInternalChoice();
        break;
      case QuestionAddContentAction.answerSpace:
        await _editAnswerSpace();
        break;
      case QuestionAddContentAction.instruction:
        _insertInstruction(insertionAnchor: insertionAnchor);
        break;
      case QuestionAddContentAction.scanText:
        await _scanQuestionText(insertionAnchor: insertionAnchor);
        break;
      case QuestionAddContentAction.quickStart:
        await _chooseType();
        if (mounted) _returnToInsertion(insertionAnchor);
        break;
    }
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
      return option.copyWith(
        text: _optionControllers[option.id]?.text ?? option.text,
      );
    }).toList();
  }

  bool _validate() {
    final accessibility = _codec.accessibleText(_bodyController.document);
    final hasStructuredContent =
        _draft.advancedContent.hasStimulus ||
        _draft.tableData != null ||
        _draft.attachments.isNotEmpty ||
        _draft.subQuestions.isNotEmpty ||
        _draft.internalChoices.isNotEmpty;
    final hasContent =
        accessibility.isNotEmpty ||
        _unplacedMathExpressions.isNotEmpty ||
        hasStructuredContent;
    final marks = double.tryParse(_marksController.text.trim());
    final options = _materializedOptions();
    final nonEmptyOptions = options
        .where((item) => item.text.trim().isNotEmpty)
        .length;
    final validMarks = marks != null && marks.isFinite && marks > 0;

    setState(() {
      _bodyError = hasContent
          ? null
          : 'Write the question or add a formula/diagram';
      _marksError = validMarks ? null : 'Enter marks above 0';
      _optionsError = _draft.options.isNotEmpty && nonEmptyOptions < 2
          ? 'Add at least two answer options'
          : null;
      _structureError =
          _draft.internalChoices.isNotEmpty && _draft.internalChoices.length < 2
          ? 'Add at least two alternatives for an internal OR choice.'
          : null;
    });
    return _bodyError == null &&
        _marksError == null &&
        _optionsError == null &&
        _structureError == null;
  }

  Future<void> _save({bool addAnother = false}) async {
    _setMarksFromText(_marksController.text);
    if (!_validate()) {
      return;
    }

    final encoded = _codec.encode(_bodyController.document);
    final bodyAccessibility = _codec.accessibleText(_bodyController.document);
    final embeddedMath = _codec.embeddedMathExpressions(
      _bodyController.document,
    );
    final embeddedIds = embeddedMath.map((expression) => expression.id).toSet();
    final unplacedMath = _unplacedMathExpressions
        .where((expression) => !embeddedIds.contains(expression.id))
        .toList();
    final savedMathExpressions = [...embeddedMath, ...unplacedMath];
    final accessibility = [
      bodyAccessibility,
      ...QuestionAdvancedStructureService.accessibilityFragments(_draft),
      ...unplacedMath.map((expression) {
        final plain = expression.plainText.trim();
        return plain.isEmpty ? expression.latex : plain;
      }),
    ].where((item) => item.trim().isNotEmpty).join(' ');
    final options = _draft.options.isNotEmpty
        ? _materializedOptions()
              .where((item) => item.text.trim().isNotEmpty)
              .map((item) => item.copyWith(text: item.text.trim()))
              .toList()
        : <QuestionOption>[];
    final draft = _draft.copyWith(
      text: encoded,
      options: options,
      mathExpressions: savedMathExpressions,
      marks: double.parse(
        _marksController.text.trim(),
      ).clamp(0.5, 100).toDouble(),
    );

    final materialized = draft.toQuestion(
      plainTextAccessibility: accessibility,
    );
    final bool saved;
    if (widget.onSaveQuestion != null) {
      saved = await widget.onSaveQuestion!(materialized);
    } else {
      final paper = ref.read(editorStateProvider);
      final actions = PaperComposerActions(
        ref.read(editorStateProvider.notifier),
      );
      saved = actions.saveQuestion(
        paper: paper,
        sectionId: widget.sectionId!,
        draft: draft,
        plainTextAccessibility: accessibility,
        insertAt: widget.insertAt,
      );
    }
    if (!saved) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.onSaveQuestion != null
                ? 'The question was not saved.'
                : 'This section no longer exists. The question was not saved.',
          ),
        ),
      );
      return;
    }
    ref
        .read(questionEditorDefaultsProvider.notifier)
        .state = QuestionEditorDefaults(
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
    oldBody.removeListener(_handleBodyControllerChanged);
    final oldOptionControllers = Map<String, TextEditingController>.from(
      _optionControllers,
    );
    setState(() {
      final nextDraft = QuestionDraft.create(
        type: previous.type,
        marks: previous.marks,
        isOptional: previous.isOptional,
      );
      _draft = widget.preserveDetailsOnSaveAndNext
          ? nextDraft.copyWith(details: previous.details)
          : nextDraft;
      _bodyController = _createBodyController(Document());
      _legacyUnplacedMathIds.clear();
      _marksController.text = _formatMarks(previous.marks);
      _optionControllers.clear();
      _syncOptionControllers();
      _bodyError = null;
      _marksError = null;
      _optionsError = null;
      _structureError = null;
      _insertionAnchor.value = _anchorFromController();
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
            Text(
              widget.pageTitle ??
                  (widget.question == null ? 'New question' : 'Edit question'),
            ),
            Text(
              '${UniversalQuestionAdapter.authoringSummary(_draft)} · ${_formatMarks(_draft.marks)} marks',
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
                        if (compact)
                          _buildMobileWritingShortcuts(context)
                        else
                          _buildInsertBar(context),
                        if (_unplacedMathExpressions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildLegacyFormulaTray(context),
                        ],
                        if (_draft.options.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildOptions(context),
                        ],
                        if (_hasAdvancedPaperBlocks) ...[
                          const SizedBox(height: 20),
                          QuestionAdvancedContentPanel(
                            draft: _draft,
                            onEditStimulus: _editStimulus,
                            onRemoveStimulus: _removeStimulus,
                            onEditWordBank: _editWordBank,
                            onRemoveWordBank: _removeWordBank,
                            onEditTable: _editTable,
                            onRemoveTable: _removeTable,
                            onAddImage: _addImage,
                            onEditImage: _editImage,
                            onRemoveImage: _removeImage,
                            onAddSubQuestion: _addSubQuestion,
                            onEditSubQuestion: _editSubQuestion,
                            onRemoveSubQuestion: _removeSubQuestion,
                            onAddInternalChoice: _addInternalChoice,
                            onEditInternalChoice: _editInternalChoice,
                            onRemoveInternalChoice: _removeInternalChoice,
                            onEditAnswerSpace: _editAnswerSpace,
                            onRemoveAnswerSpace: _removeAnswerSpace,
                          ),
                          if (_structureError != null) ...[
                            const SizedBox(height: 4),
                            ComposerErrorText(_structureError!),
                          ],
                        ],
                        const SizedBox(height: 16),
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Write freely',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _chooseType,
                        icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                        label: const Text('Quick start'),
                      ),
                    ],
                  ),
                  Text(
                    'Quick start is optional. It adds helpers but never locks your paper format.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  _buildCurrentQuickStart(context),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Write freely',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: _chooseType,
                              icon: const Icon(
                                Icons.auto_awesome_outlined,
                                size: 18,
                              ),
                              label: const Text('Quick start'),
                            ),
                          ],
                        ),
                        Text(
                          'Type the paper exactly as you want. Add helpers only when useful.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        _buildCurrentQuickStart(context),
                      ],
                    ),
                  ),
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

  Widget _buildCurrentQuickStart(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Text(
          'Current helper:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: _chooseType,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          child: Text(_draft.type.label),
        ),
      ],
    );
  }

  Widget _buildQuestionEditor(BuildContext context, bool compact) {
    final theme = Theme.of(context);
    return Container(
      key: _questionEditorKey,
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
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Question',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (!compact)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: _showFormatting
                            ? 'Hide formatting'
                            : 'Text formatting',
                        onPressed: _toggleFormatting,
                        icon: Icon(
                          _showFormatting
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.format_bold_rounded,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder<QuestionInsertionAnchor>(
                  valueListenable: _insertionAnchor,
                  builder: (context, anchor, _) => Align(
                    alignment: Alignment.centerLeft,
                    child: QuestionInsertionStatus(
                      anchor: anchor,
                      isFocused: _bodyHasFocus,
                      compact: compact,
                      onTap: _returnToSavedInsertion,
                    ),
                  ),
                ),
                if (compact) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Tap in the question to move the cursor. Add, Math and Geometry below will use that exact position.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 220 : 260),
            child: QuillEditor(
              controller: _bodyController,
              focusNode: _bodyFocus,
              scrollController: _bodyScroll,
              config: QuillEditorConfig(
                placeholder:
                    'Type the question exactly as students should read it…',
                padding: const EdgeInsets.all(14),
                // The page already owns vertical scrolling. Let the editor grow
                // with text/graphs instead of creating a second tiny scroll
                // viewport inside the question card. This keeps the caret and
                // the content being typed visually together after a diagram.
                scrollable: false,
                embedBuilders: [
                  GeometryEmbedBuilder(),
                  MathExpressionEmbedBuilder(onEdit: _editEmbeddedFormula),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileWritingShortcuts(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInsertionGuidance(context),
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

  Widget _buildInsertionGuidance(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.touch_app_outlined,
          size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Math and diagrams are inserted exactly at the question cursor. Tap where they should appear first.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'The cursor position is saved while Add, Math, Scan or Geometry opens, so a helper cannot jump to the end by accident.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
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
              icon: Icons.add_rounded,
              label: 'Add',
              onTap: _showAddContent,
            ),
            QuestionInsertAction(
              icon: Icons.functions_rounded,
              label: 'Math',
              onTap: () => _insertFormula(),
            ),
            QuestionInsertAction(
              icon: Icons.category_outlined,
              label: 'Geometry',
              onTap: () => _insertGeometry(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildInsertionGuidance(context),
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
        color: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Math from an older question',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
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

  void _setOptionLayout(QuestionOptionLayout layout) {
    if (_draft.optionLayout == layout) return;
    setState(() => _draft = _draft.copyWith(optionLayout: layout));
  }

  Widget _buildOptions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'Answer options',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
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
        const SizedBox(height: 10),
        Text(
          'Paper layout',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: QuestionOptionLayout.values
              .map(
                (layout) => ChoiceChip(
                  key: ValueKey('question-option-layout-${layout.name}'),
                  label: Text(layout.label),
                  selected: _draft.optionLayout == layout,
                  onSelected: (_) => _setOptionLayout(layout),
                  tooltip: layout.shortDescription,
                ),
              )
              .toList(),
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
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (compact && !mathVisible)
                  AnimatedBuilder(
                    animation: _bodyController,
                    builder: (context, _) =>
                        ValueListenableBuilder<QuestionInsertionAnchor>(
                          valueListenable: _insertionAnchor,
                          builder: (context, anchor, _) =>
                              QuestionMobileAuthoringToolbar(
                                anchor: anchor,
                                formattingActive: _showFormatting,
                                canUndo: _bodyController.hasUndo,
                                canRedo: _bodyController.hasRedo,
                                onReturnToCursor: _returnToSavedInsertion,
                                onAdd: _showAddContent,
                                onMath: () => _insertFormula(
                                  insertionAnchor: _toolInsertionAnchor(),
                                ),
                                onGeometry: () => _insertGeometry(
                                  insertionAnchor: _toolInsertionAnchor(),
                                ),
                                onFormat: _toggleFormatting,
                                onUndo: _undoBody,
                                onRedo: _redoBody,
                              ),
                        ),
                  ),
                if (compact && !mathVisible) ...[
                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  const SizedBox(height: 7),
                ],
                Row(
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
                    if (widget.question == null && widget.allowSaveAndNext)
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
                    if (widget.question == null && widget.allowSaveAndNext)
                      const SizedBox(width: 8),
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
