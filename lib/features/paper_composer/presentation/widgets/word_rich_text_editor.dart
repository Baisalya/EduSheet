import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/geometry_builder/application/geometry_embed_layout.dart';
import 'package:edusheet/features/geometry_builder/services/geometry_diagram_registry.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_builder_screen.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_embed_builder.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_expression_embed_builder.dart';
import 'package:edusheet/features/paper_composer/application/question_rich_text_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared command surface between the Word Mode ribbon and whichever rich
/// block currently owns the caret.
class WordRichTextSession extends ChangeNotifier {
  QuillController? _controller;
  Future<void> Function()? _insertMath;
  Future<void> Function()? _insertGeometry;
  VoidCallback? _requestFocus;
  String? _questionId;

  QuillController? get activeController => _controller;
  bool get hasActiveEditor => _controller != null;
  String? get activeQuestionId => _questionId;

  void attach({
    required String questionId,
    required QuillController controller,
    required Future<void> Function() insertMath,
    required Future<void> Function() insertGeometry,
    required VoidCallback requestFocus,
  }) {
    if (identical(_controller, controller) && _questionId == questionId) return;
    _controller = controller;
    _questionId = questionId;
    _insertMath = insertMath;
    _insertGeometry = insertGeometry;
    _requestFocus = requestFocus;
    notifyListeners();
  }

  void detach(QuillController controller) {
    if (!identical(_controller, controller)) return;
    _controller = null;
    _questionId = null;
    _insertMath = null;
    _insertGeometry = null;
    _requestFocus = null;
    notifyListeners();
  }

  void undo() {
    final controller = _controller;
    if (controller?.hasUndo == true) controller!.undo();
  }

  void redo() {
    final controller = _controller;
    if (controller?.hasRedo == true) controller!.redo();
  }

  Future<void> insertMath() async {
    final callback = _insertMath;
    if (callback != null) await callback();
  }

  Future<void> insertGeometry() async {
    final callback = _insertGeometry;
    if (callback != null) await callback();
  }

  void restoreFocus() {
    _requestFocus?.call();
  }
}

/// Inline rich-text editor used by Word Mode.
///
/// It persists directly back into the same [Question] object used by Smart
/// Mode. There is no intermediate Word document copy, so switching modes is a
/// view change rather than a conversion step.
class WordRichTextEditor extends ConsumerStatefulWidget {
  final Question question;
  final bool compact;
  final bool autofocus;
  final WordRichTextSession session;
  final ValueChanged<Question> onChanged;
  final VoidCallback onActivated;

  const WordRichTextEditor({
    super.key,
    required this.question,
    required this.compact,
    required this.autofocus,
    required this.session,
    required this.onChanged,
    required this.onActivated,
  });

  @override
  ConsumerState<WordRichTextEditor> createState() => _WordRichTextEditorState();
}

class _WordRichTextEditorState extends ConsumerState<WordRichTextEditor> {
  static const _codec = QuestionRichTextCodec();

  late QuillController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;
  late Set<String> _legacyUnplacedMathIds;
  bool _syncingExternal = false;
  String? _lastEmittedText;

  @override
  void initState() {
    super.initState();
    _controller = _createController(widget.question);
    _focusNode = FocusNode()..addListener(_handleFocus);
    _scrollController = ScrollController();
    _legacyUnplacedMathIds = _codec
        .unplacedMathExpressions(widget.question)
        .map((item) => item.id)
        .where((id) => id.isNotEmpty)
        .toSet();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  QuillController _createController(Question question) {
    final document = _codec.decodeQuestion(question);
    final controller = QuillController(
      document: document,
      selection: TextSelection.collapsed(
        offset: (document.length - 1).clamp(0, 1 << 30).toInt(),
      ),
    );
    controller.addListener(_handleDocumentChanged);
    return controller;
  }

  @override
  void didUpdateWidget(covariant WordRichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incomingText = widget.question.text;
    if (incomingText == oldWidget.question.text ||
        incomingText == _lastEmittedText ||
        _focusNode.hasFocus) {
      return;
    }
    final previous = _controller;
    final previousWasSessionActive = identical(
      widget.session.activeController,
      previous,
    );
    _syncingExternal = true;
    _controller = _createController(widget.question);
    _legacyUnplacedMathIds = _codec
        .unplacedMathExpressions(widget.question)
        .map((item) => item.id)
        .where((id) => id.isNotEmpty)
        .toSet();
    _syncingExternal = false;
    previous.removeListener(_handleDocumentChanged);
    previous.dispose();
    if (previousWasSessionActive) {
      // Avoid notifying the ribbon from didUpdateWidget while the widget tree
      // is rebuilding. The old controller is unreachable by the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.session.detach(previous);
      });
    }
  }

  @override
  void dispose() {
    widget.session.detach(_controller);
    _controller.removeListener(_handleDocumentChanged);
    _controller.dispose();
    _focusNode.removeListener(_handleFocus);
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleFocus() {
    if (_focusNode.hasFocus) {
      widget.onActivated();
      widget.session.attach(
        questionId: widget.question.id,
        controller: _controller,
        insertMath: _insertFormula,
        insertGeometry: _insertGeometry,
        requestFocus: () {
          if (mounted) _focusNode.requestFocus();
        },
      );
    }
    if (mounted) setState(() {});
  }

  void _handleDocumentChanged() {
    if (_syncingExternal) return;
    final encoded = _codec.encode(_controller.document);
    if (encoded == _lastEmittedText) return;
    _lastEmittedText = encoded;

    final embedded = _codec.embeddedMathExpressions(_controller.document);
    final legacyUnplaced = widget.question.mathExpressions
        .where((item) => _legacyUnplacedMathIds.contains(item.id))
        .toList();
    final updated = widget.question.copyWith(
      text: encoded,
      plainTextAccessibility: _codec.accessibleText(_controller.document),
      mathExpressions: [...embedded, ...legacyUnplaced],
    );
    widget.onChanged(updated);
  }

  (int, int) _selectionRange() {
    final end = (_controller.document.length - 1).clamp(0, 1 << 30).toInt();
    final selection = _controller.selection;
    final start = selection.start.clamp(0, end).toInt();
    final finish = selection.end.clamp(start, end).toInt();
    return (start, finish - start);
  }

  void _restoreSelection(TextSelection selection) {
    final end = (_controller.document.length - 1).clamp(0, 1 << 30).toInt();
    _controller.updateSelection(
      TextSelection(
        baseOffset: selection.baseOffset.clamp(0, end).toInt(),
        extentOffset: selection.extentOffset.clamp(0, end).toInt(),
      ),
      ChangeSource.local,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _insertFormula() async {
    final selection = _controller.selection;
    final range = _selectionRange();
    ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
    FocusManager.instance.primaryFocus?.unfocus();
    final expression = await FormulaEditorSheet.show(
      context,
      autoOpenMathKeyboard: true,
    );
    if (expression == null || !mounted) {
      if (mounted) _restoreSelection(selection);
      return;
    }
    _insertMathAt(expression, range);
    _focusNode.requestFocus();
  }

  Future<MathExpression?> _editEmbeddedFormula(
    BuildContext context,
    MathExpression expression,
  ) {
    return FormulaEditorSheet.show(
      context,
      initial: expression,
      autoOpenMathKeyboard: true,
    );
  }

  void _insertMathAt(MathExpression expression, (int, int) range) {
    var start = range.$1;
    final length = range.$2;
    if (expression.display == MathExpressionDisplay.inline) {
      _controller.replaceText(
        start,
        length,
        MathExpressionEmbed(expression),
        null,
      );
      _controller.updateSelection(
        TextSelection.collapsed(offset: start + 1),
        ChangeSource.local,
      );
      return;
    }

    if (length > 0) _controller.replaceText(start, length, '', null);
    var text = _controller.document.toPlainText();
    if (start > 0 && start <= text.length && text[start - 1] != '\n') {
      _controller.replaceText(start, 0, '\n', null);
      start += 1;
    }
    _controller.replaceText(start, 0, MathExpressionEmbed(expression), null);
    text = _controller.document.toPlainText();
    final after = start + 1;
    if (after >= text.length || text[after] != '\n') {
      _controller.replaceText(after, 0, '\n', null);
    }
    _controller.updateSelection(
      TextSelection.collapsed(offset: start + 2),
      ChangeSource.local,
    );
  }

  Future<void> _insertGeometry() async {
    final selection = _controller.selection;
    final range = _selectionRange();
    ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
    FocusManager.instance.primaryFocus?.unfocus();
    final diagram = await GeometryBuilderScreen.show(context);
    if (diagram == null || !mounted) {
      if (mounted) _restoreSelection(selection);
      return;
    }
    GeometryDiagramRegistry.instance.save(diagram);
    final data = GeometryEmbedLayout.forDiagram(diagram).encode();
    _insertGeometryAt(data, range);
    _focusNode.requestFocus();
  }

  void _insertGeometryAt(String data, (int, int) range) {
    var start = range.$1;
    final length = range.$2;
    if (length > 0) _controller.replaceText(start, length, '', null);
    var text = _controller.document.toPlainText();
    if (start > 0 && start <= text.length && text[start - 1] != '\n') {
      _controller.replaceText(start, 0, '\n', null);
      start += 1;
    }
    _controller.replaceText(
      start,
      0,
      BlockEmbed.custom(CustomBlockEmbed('geometry', data)),
      null,
    );
    text = _controller.document.toPlainText();
    final after = start + 1;
    if (after >= text.length || text[after] != '\n') {
      _controller.replaceText(after, 0, '\n', null);
    }
    _controller.updateSelection(
      TextSelection.collapsed(offset: start + 2),
      ChangeSource.local,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _focusNode.hasFocus
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _focusNode.hasFocus
              ? theme.colorScheme.primary.withValues(alpha: 0.28)
              : Colors.transparent,
        ),
      ),
      child: QuillEditor(
        controller: _controller,
        focusNode: _focusNode,
        scrollController: _scrollController,
        config: QuillEditorConfig(
          placeholder: widget.question.isWordContentBlock
              ? 'Type freely…'
              : 'Type question text…',
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          scrollable: false,
          embedBuilders: [
            GeometryEmbedBuilder(),
            MathExpressionEmbedBuilder(onEdit: _editEmbeddedFormula),
          ],
        ),
      ),
    );
  }
}
