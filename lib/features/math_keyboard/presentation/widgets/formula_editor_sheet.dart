import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_keyboard/math_keyboard.dart';
import 'package:math_expressions/math_expressions.dart' show Expression;
import 'package:uuid/uuid.dart';

import '../../../editor/domain/models/math_expression.dart';
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
    try {
      ref
          .read(mathKeyboardControllerProvider.notifier)
          .unregisterController(_visualController);
    } catch (_) {
      // Provider scope can already be tearing down in widget tests.
    }
    _visualFocusNode.dispose();
    _visualController.dispose();
    _sourceController.dispose();
    _fallbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardState = ref.watch(mathKeyboardControllerProvider);
    final mathKeyboardVisible =
        keyboardState.isVisible &&
        keyboardState.type == KeyboardType.math &&
        identical(keyboardState.activeController, _visualController);
    _scheduleStructuredMathSessionRecovery(keyboardState);
    final mathKeyboardInset = mathKeyboardVisible ? keyboardState.height : 0.0;
    final screen = MediaQuery.sizeOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.viewInsetsOf(context).bottom + 8,
      ),
      child: SizedBox(
        height: screen.height * 0.9,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: mathKeyboardInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _visualReady
                            ? 'Edit the formula exactly as it should appear in the question.'
                            : 'This formula uses source syntax the visual editor cannot load yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_visualReady) _buildVisualEditor(context),
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
                        children: [
                          OutlinedButton.icon(
                            onPressed: _visualReady
                                ? _openStructuredMathKeyboard
                                : _tryOpenVisualFromSource,
                            icon: Icon(
                              _visualReady
                                  ? Icons.keyboard_alt_outlined
                                  : Icons.auto_fix_high_outlined,
                            ),
                            label: Text(
                              mathKeyboardVisible
                                  ? 'Math keyboard open'
                                  : _visualReady
                                  ? 'Open math keyboard'
                                  : 'Try visual editor',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => setState(
                              () => _advancedExpanded = !_advancedExpanded,
                            ),
                            icon: Icon(
                              _advancedExpanded
                                  ? Icons.expand_less_rounded
                                  : Icons.tune_rounded,
                            ),
                            label: Text(
                              _advancedExpanded ? 'Hide advanced' : 'Advanced',
                            ),
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
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      _structuredMathSessionRequested = false;
                      ref
                          .read(mathKeyboardControllerProvider.notifier)
                          .hideKeyboard();
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        _editingExisting ? 'Save formula' : 'Add formula',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
          label: Text('Inline'),
        ),
        ButtonSegment(
          value: MathExpressionDisplay.block,
          label: Text('New line'),
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

  Widget _buildVisualEditor(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: MathKeyboardField(
          controller: _visualController,
          focusNode: _visualFocusNode,
          retainMathSessionOnFocusLoss: true,
          builder: (context, focusNode, isMathActive) => MathField(
            controller: _visualController,
            focusNode: focusNode,
            opensKeyboard: !isMathActive,
            decoration: const InputDecoration(
              labelText: 'Formula',
              hintText: 'Tap here and build the formula',
              helperText:
                  'Use the math keyboard below; the formula renders as you type.',
              border: OutlineInputBorder(),
            ),
            onChanged: _onVisualChanged,
          ),
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
