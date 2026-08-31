import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_keyboard/math_keyboard.dart';
import 'package:math_expressions/math_expressions.dart' show Expression;
import 'package:uuid/uuid.dart';

import '../../../editor/domain/models/math_expression.dart';
import '../../domain/catalog/math_symbol_catalog.dart';
import '../../domain/models/math_symbol.dart';
import '../../domain/services/math_accessible_text_service.dart';
import '../../domain/services/math_expression_validator.dart';
import '../providers/math_keyboard_controller.dart';
import 'math_keyboard_field.dart';
import 'safe_math_expression.dart';

/// Teacher-first visual formula composer.
///
/// Normal editing happens in [MathField]. TeX source and accessibility text are
/// intentionally hidden behind Advanced so teachers never need to understand
/// source syntax to create or edit textbook mathematics.
class FormulaEditorSheet extends ConsumerStatefulWidget {
  final MathExpression? initial;
  final bool autoOpenMathKeyboard;

  const FormulaEditorSheet({
    super.key,
    this.initial,
    this.autoOpenMathKeyboard = true,
  });

  static Future<MathExpression?> show(
    BuildContext context, {
    MathExpression? initial,
    bool autoOpenMathKeyboard = true,
  }) {
    return showAdaptiveModalBottomSheet<MathExpression>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      // The formula editor owns its focus explicitly when it opens the custom
      // math keyboard. Letting the modal route request focus can race that
      // ownership hand-off and slide the custom keyboard back off-screen just
      // after auto-open (especially in widget tests and desktop focus flows).
      requestFocus: false,
      builder: (context) => FormulaEditorSheet(
        initial: initial,
        autoOpenMathKeyboard: autoOpenMathKeyboard,
      ),
    );
  }

  @override
  ConsumerState<FormulaEditorSheet> createState() => _FormulaEditorSheetState();
}

class _FormulaEditorSheetState extends ConsumerState<FormulaEditorSheet> {
  static const MathAccessibleTextService _accessibleText =
      MathAccessibleTextService();

  final MathFieldEditingController _visualController =
      MathFieldEditingController();
  final FocusNode _visualFocusNode = FocusNode(debugLabel: 'formula-editor');

  late final TextEditingController _sourceController;
  late final TextEditingController _fallbackController;
  late MathExpressionDisplay _display;

  String _latex = '';
  String? _error;
  String? _sourceParseMessage;
  bool _advancedExpanded = false;
  bool _visualReady = true;
  bool _syncingVisual = false;
  bool _descriptionWasEdited = false;
  bool _structuredMathSessionRequested = false;
  bool _mathSessionRecoveryScheduled = false;

  bool get _editingExisting => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _latex = widget.initial?.latex ?? '';
    _display = widget.initial?.display ?? MathExpressionDisplay.inline;
    _sourceController = TextEditingController(text: _latex);

    final initialDescription = widget.initial?.plainText.trim() ?? '';
    _descriptionWasEdited = initialDescription.isNotEmpty;
    _fallbackController = TextEditingController(
      text: initialDescription.isEmpty
          ? _accessibleText.describe(_latex)
          : initialDescription,
    );

    _visualReady = _loadVisualSource(_latex);
    _advancedExpanded = !_visualReady;
    _structuredMathSessionRequested =
        widget.autoOpenMathKeyboard && _visualReady;

    if (_structuredMathSessionRequested) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openStructuredMathKeyboard();
      });
    }
  }

  @override
  void dispose() {
    _visualFocusNode.dispose();
    _visualController.dispose();
    _sourceController.dispose();
    _fallbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardState = ref.watch(mathKeyboardControllerProvider);
    final mathKeyboardVisible =
        keyboardState.isVisible &&
        keyboardState.type == KeyboardType.math &&
        identical(keyboardState.activeController, _visualController);
    _scheduleStructuredMathSessionRecovery(keyboardState);
    final screen = MediaQuery.sizeOf(context);
    final mathKeyboardInset = mathKeyboardVisible
        ? effectiveMathKeyboardHeight(screen, keyboardState.height)
        : 0.0;
    // The native IME can take a few frames to animate away after the custom
    // keyboard takes ownership. Reserving both insets during that overlap
    // moves a windowed editor up and then back down. Once math owns input, its
    // stable effective height is the only bottom inset that matters.
    final systemKeyboardInset = mathKeyboardVisible
        ? 0.0
        : MediaQuery.viewInsetsOf(context).bottom;
    final settledEditorHeight =
        (screen.height * 0.9) - mathKeyboardInset - systemKeyboardInset;

    return Padding(
      key: const ValueKey('formula-editor-system-inset'),
      padding: EdgeInsets.fromLTRB(12, 8, 12, systemKeyboardInset + 8),
      child: SizedBox(
        height: screen.height * 0.9,
        child: AnimatedPadding(
          key: const ValueKey('formula-editor-math-inset'),
          duration: mathKeyboardTransitionDuration,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: mathKeyboardInset),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final useScrollableLayout =
                  constraints.maxHeight < 360 ||
                  settledEditorHeight < 360 ||
                  textScale >= 1.5;
              final editorBody = _buildEditorBody(
                context,
                mathKeyboardVisible: mathKeyboardVisible,
              );

              if (useScrollableLayout) {
                return SingleChildScrollView(
                  key: const ValueKey('formula-editor-scrollable-layout'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 6),
                      _buildPlacementHelp(context),
                      const SizedBox(height: 10),
                      editorBody,
                      const SizedBox(height: 8),
                      _buildFooter(context),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 6),
                  _buildPlacementHelp(context),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: editorBody,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildFooter(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEditorBody(
    BuildContext context, {
    required bool mathKeyboardVisible,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _visualReady
              ? 'Build the formula visually. Tap a structure, fill its boxes, then use “Next box” to move forward.'
              : 'This formula uses source syntax the visual editor cannot load yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        if (_visualReady)
          _buildVisualEditor(context, mathKeyboardVisible: mathKeyboardVisible),
        if (!_visualReady) ...[
          _buildRenderedFallback(context),
          const SizedBox(height: 8),
          _buildSourceFallbackNotice(context),
        ],
        if (_sourceParseMessage != null) ...[
          const SizedBox(height: 8),
          _InlineNotice(
            icon: Icons.info_outline_rounded,
            text: _sourceParseMessage!,
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_visualReady && !mathKeyboardVisible)
              FilledButton.tonalIcon(
                onPressed: _openStructuredMathKeyboard,
                icon: const Icon(Icons.keyboard_alt_outlined),
                label: const Text('Open math keyboard'),
              ),
            if (!_visualReady)
              OutlinedButton.icon(
                onPressed: _tryOpenVisualFromSource,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('Try visual editor'),
              ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _advancedExpanded = !_advancedExpanded),
              icon: Icon(
                _advancedExpanded
                    ? Icons.expand_less_rounded
                    : Icons.tune_rounded,
              ),
              label: Text(_advancedExpanded ? 'Hide advanced' : 'Advanced'),
            ),
          ],
        ),
        if (_advancedExpanded || !_visualReady) ...[
          const SizedBox(height: 10),
          _buildAdvancedEditor(context),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          _InlineNotice(
            icon: Icons.error_outline_rounded,
            text: _error!,
            isError: true,
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        TextButton(
          onPressed: () {
            _structuredMathSessionRequested = false;
            ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(_editingExisting ? 'Save formula' : 'Add formula'),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final title = _editingExisting ? 'Edit math formula' : 'Add math formula';
    final titleWidget = Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    );
    final displaySelector = SegmentedButton<MathExpressionDisplay>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: MathExpressionDisplay.inline,
          icon: Icon(Icons.short_text_rounded),
          label: Text('In sentence'),
        ),
        ButtonSegment(
          value: MathExpressionDisplay.block,
          icon: Icon(Icons.notes_rounded),
          label: Text('Own line'),
        ),
      ],
      selected: {_display},
      onSelectionChanged: (value) => setState(() {
        _display = value.single;
        _error = null;
      }),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleWidget,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: displaySelector),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: titleWidget),
            const SizedBox(width: 8),
            displaySelector,
          ],
        );
      },
    );
  }

  Widget _buildPlacementHelp(BuildContext context) {
    final theme = Theme.of(context);
    final inline = _display == MathExpressionDisplay.inline;

    return Semantics(
      container: true,
      label: inline
          ? 'Formula placement: in sentence. The formula stays with the question text.'
          : 'Formula placement: own line. The formula is shown as a standalone equation.',
      child: DecoratedBox(
        key: const ValueKey('formula-placement-help'),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                inline ? Icons.short_text_rounded : Icons.notes_rounded,
                size: 17,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  inline
                      ? 'In sentence keeps the formula exactly where the question cursor was placed.'
                      : 'Own line is best for a standalone equation or derivation step.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualEditor(
    BuildContext context, {
    required bool mathKeyboardVisible,
  }) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: mathKeyboardVisible
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: mathKeyboardVisible ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FormulaTypingStatus(active: mathKeyboardVisible),
            const SizedBox(height: 8),
            MathKeyboardField(
              controller: _visualController,
              focusNode: _visualFocusNode,
              retainMathSessionOnFocusLoss: true,
              builder: (context, focusNode, isMathActive) => MathField(
                controller: _visualController,
                focusNode: focusNode,
                opensKeyboard: !isMathActive,
                decoration: InputDecoration(
                  labelText: 'Formula',
                  hintText: 'Tap here and build the formula',
                  helperText: isMathActive
                      ? 'The typing position stays in this formula. Use “Next box” for fractions, roots, powers and subscripts.'
                      : 'Tap the formula, then open the math keyboard.',
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: _onVisualChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRenderedFallback(BuildContext context) {
    final source = _sourceController.text.trim();
    if (source.isEmpty) return const SizedBox.shrink();
    final expression = MathExpression(
      id: widget.initial?.id ?? 'preview',
      latex: source,
      plainText: _fallbackController.text.trim().isEmpty
          ? _accessibleText.describe(source)
          : _fallbackController.text.trim(),
      display: _display,
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: SafeMathExpression(expression: expression),
    );
  }

  Widget _buildSourceFallbackNotice(BuildContext context) {
    return _InlineNotice(
      icon: Icons.code_rounded,
      text:
          'Nothing is lost. Edit the source under Advanced, or make it valid and tap “Try visual editor”.',
    );
  }

  Widget _buildAdvancedEditor(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Advanced',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sourceController,
              onTap: _releaseStructuredMathKeyboardForExternalEditor,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Formula source',
                helperText:
                    'Optional. Most teachers never need this; use it for advanced TeX syntax.',
                border: OutlineInputBorder(),
              ),
              onChanged: _onSourceChanged,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _fallbackController,
              onTap: _releaseStructuredMathKeyboardForExternalEditor,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Accessibility description (optional)',
                helperText:
                    'Generated automatically when left blank. Edit only if you want different wording.',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() {
                _descriptionWasEdited = value.trim().isNotEmpty;
                _error = null;
              }),
            ),
            if (_descriptionWasEdited) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _descriptionWasEdited = false;
                      _fallbackController.text = _accessibleText.describe(
                        _latex,
                      );
                    });
                  },
                  child: const Text('Use automatic description'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onVisualChanged(String value) {
    if (_syncingVisual) return;
    setState(() {
      _latex = value;
      _error = null;
      _sourceParseMessage = null;
    });
    _syncSourceText(value);
    _refreshAutomaticDescription();
  }

  void _onSourceChanged(String value) {
    _latex = value;
    _error = null;

    final loaded = _loadVisualSource(value);
    setState(() {
      if (loaded) {
        _visualReady = true;
        _sourceParseMessage = null;
      } else {
        _sourceParseMessage =
            'The source is not currently valid for visual editing. The last valid visual formula is kept safe.';
      }
    });
    _refreshAutomaticDescription();
  }

  bool _loadVisualSource(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      _syncingVisual = true;
      try {
        _visualController.clear();
      } finally {
        _syncingVisual = false;
      }
      return true;
    }

    try {
      final expression = _parseVisualExpression(trimmed);
      _syncingVisual = true;
      try {
        _visualController.updateValue(expression);
      } finally {
        _syncingVisual = false;
      }
      return true;
    } catch (_) {
      // The upstream TeX parser does not support every valid expression that
      // EduSheet's own catalog inserts (notably relational templates such as
      // Pythagoras). Restore those known-safe sources as the same editable leaf
      // used at insertion time instead of forcing teachers into source mode.
      final catalogTemplate = MathSymbolCatalog.findByTex(
        trimmed,
        category: MathCategory.templates,
      );
      if (catalogTemplate != null) {
        _syncingVisual = true;
        try {
          _visualController.clear();
          _visualController.addLeaf(trimmed);
        } finally {
          _syncingVisual = false;
        }
        return true;
      }
      return false;
    }
  }

  Expression _parseVisualExpression(String source) {
    try {
      return TeXParser(source).parse();
    } catch (_) {
      // math_keyboard serializes variables as `{x}`, while older/imported
      // EduSheet formulas can contain ordinary TeX variables such as `x+1`.
      // Retry with only bare ASCII variable runs wrapped; commands (for
      // example `\sqrt`) and already-braced variables remain untouched.
      final normalized = source.replaceAllMapped(
        RegExp(r'(?<![\\A-Za-z{])[A-Za-z]+(?![A-Za-z}])'),
        (match) => '{${match.group(0)}}',
      );
      if (normalized == source) rethrow;
      return TeXParser(normalized).parse();
    }
  }

  void _tryOpenVisualFromSource() {
    final source = _sourceController.text.trim();
    final loaded = _loadVisualSource(source);
    if (!loaded) {
      setState(() {
        _error =
            'This source still cannot be opened by the visual editor. You can keep editing the source without losing the existing formula.';
      });
      return;
    }

    setState(() {
      _visualReady = true;
      _sourceParseMessage = null;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openStructuredMathKeyboard();
    });
  }

  void _syncSourceText(String value) {
    if (_sourceController.text == value) return;
    _sourceController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _refreshAutomaticDescription() {
    if (_descriptionWasEdited) return;
    final generated = _accessibleText.describe(_latex);
    if (_fallbackController.text == generated) return;
    _fallbackController.value = TextEditingValue(
      text: generated,
      selection: TextSelection.collapsed(offset: generated.length),
    );
  }

  void _releaseStructuredMathKeyboardForExternalEditor() {
    _structuredMathSessionRequested = false;
    final keyboard = ref.read(mathKeyboardControllerProvider.notifier);
    keyboard.unregisterController(
      _visualController,
      focusNode: _visualFocusNode,
    );
  }

  void _openStructuredMathKeyboard() {
    if (!_visualReady) return;

    _structuredMathSessionRequested = true;
    // Establish ownership before requesting focus. On Windows, requesting focus
    // first can briefly attach the system IME before the custom keyboard state
    // reaches MathField, which produces the native-keyboard flash/hand-off seen
    // when reopening the formula editor.
    final keyboard = ref.read(mathKeyboardControllerProvider.notifier);
    keyboard.showMathKeyboardFor(_visualController, _visualFocusNode);
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    if (!_visualFocusNode.hasFocus) {
      _visualFocusNode.requestFocus();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final state = ref.read(mathKeyboardControllerProvider);
      final stillOwnedByVisualEditor =
          state.isVisible &&
          state.type == KeyboardType.math &&
          identical(state.activeController, _visualController);

      // MathField can perform an internal focus hand-off while switching from
      // its system-keyboard mode to the custom keyboard. Reassert this one
      // requested session after that hand-off so the initial auto-open cannot
      // collapse during the first frame on Windows.
      if (!stillOwnedByVisualEditor) {
        keyboard.showMathKeyboardFor(_visualController, _visualFocusNode);
      }
      if (!_visualFocusNode.hasFocus && _visualFocusNode.canRequestFocus) {
        _visualFocusNode.requestFocus();
      }
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    });
  }

  void _scheduleStructuredMathSessionRecovery(
    MathKeyboardStateData keyboardState,
  ) {
    if (!_structuredMathSessionRequested ||
        !_visualReady ||
        _mathSessionRecoveryScheduled) {
      return;
    }

    // `showSystemKeyboard` / `hideKeyboard` deliberately switch the type back
    // to system. Never fight an explicit user choice. Recovery is only for a
    // math session that was unintentionally detached while it was still meant
    // to be active (for example a transient MathField focus hand-off).
    final needsRecovery =
        keyboardState.type == KeyboardType.math &&
        (!keyboardState.isVisible ||
            !identical(keyboardState.activeController, _visualController));
    if (!needsRecovery) return;

    _mathSessionRecoveryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mathSessionRecoveryScheduled = false;
      if (!mounted || !_structuredMathSessionRequested || !_visualReady) {
        return;
      }

      final current = ref.read(mathKeyboardControllerProvider);
      if (current.type != KeyboardType.math) return;
      if (current.isVisible &&
          identical(current.activeController, _visualController)) {
        return;
      }

      final keyboard = ref.read(mathKeyboardControllerProvider.notifier);
      keyboard.showMathKeyboardFor(_visualController, _visualFocusNode);
      if (!_visualFocusNode.hasFocus && _visualFocusNode.canRequestFocus) {
        _visualFocusNode.requestFocus();
      }
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    });
  }

  void _save() {
    final source = _sourceController.text.trim();
    _latex = source;

    if (source.isEmpty) {
      setState(() => _error = 'Add some mathematics before saving.');
      return;
    }

    final fallback = _fallbackController.text.trim().isEmpty
        ? _accessibleText.describe(source)
        : _fallbackController.text.trim();
    final expression = MathExpression(
      id: widget.initial?.id ?? const Uuid().v4(),
      latex: source,
      plainText: fallback,
      display: _display,
      metadata: widget.initial?.metadata ?? const {},
    );
    final validation = const MathExpressionValidator().validate(expression);
    if (!validation.isValid) {
      setState(() {
        _error = validation.message;
        _advancedExpanded = true;
      });
      return;
    }

    _structuredMathSessionRequested = false;
    ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
    Navigator.pop(context, expression);
  }
}

class _FormulaTypingStatus extends StatelessWidget {
  const _FormulaTypingStatus({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = active ? colors.primary : colors.onSurfaceVariant;

    final status = active
        ? 'Typing here — the next math key goes at the visible formula cursor.'
        : 'Tap the formula to choose where math should be typed.';

    return Semantics(
      container: true,
      liveRegion: true,
      label: active
          ? 'Math typing active. The next math key goes at the visible formula cursor. Use Next box to move through a structure.'
          : 'Math typing inactive. Tap the formula to choose where math should be typed.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: active ? colors.primary : colors.outlineVariant,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: foreground,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (active) ...[
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  'Structure → type the first box → Next box → continue',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.text,
    this.isError = false,
  });

  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = isError ? colors.error : colors.onSurfaceVariant;
    final background = isError
        ? colors.errorContainer.withValues(alpha: 0.55)
        : colors.surfaceContainerHigh;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}
