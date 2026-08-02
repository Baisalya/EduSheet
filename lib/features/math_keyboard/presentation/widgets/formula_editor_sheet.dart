import 'package:flutter/material.dart';
import 'package:math_keyboard/math_keyboard.dart';
import 'package:uuid/uuid.dart';

import '../../../editor/domain/models/math_expression.dart';
import '../../domain/services/math_expression_validator.dart';
import 'math_keyboard_field.dart';
import 'safe_math_expression.dart';

class FormulaEditorSheet extends StatefulWidget {
  final MathExpression? initial;

  const FormulaEditorSheet({super.key, this.initial});

  static Future<MathExpression?> show(
    BuildContext context, {
    MathExpression? initial,
  }) {
    return showModalBottomSheet<MathExpression>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => FormulaEditorSheet(initial: initial),
    );
  }

  @override
  State<FormulaEditorSheet> createState() => _FormulaEditorSheetState();
}

class _FormulaEditorSheetState extends State<FormulaEditorSheet> {
  final MathFieldEditingController _visualController =
      MathFieldEditingController();
  late final TextEditingController _sourceController;
  late final TextEditingController _fallbackController;
  late bool _rawMode;
  late MathExpressionDisplay _display;
  String _latex = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _latex = widget.initial?.latex ?? '';
    _rawMode = widget.initial != null;
    _display = widget.initial?.display ?? MathExpressionDisplay.inline;
    _sourceController = TextEditingController(text: _latex);
    _fallbackController = TextEditingController(
      text: widget.initial?.plainText ?? '',
    );
  }

  @override
  void dispose() {
    _visualController.dispose();
    _sourceController.dispose();
    _fallbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = MathExpression(
      id: widget.initial?.id ?? 'preview',
      latex: _latex,
      plainText: _fallbackController.text,
      display: _display,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Formula block',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                SegmentedButton<MathExpressionDisplay>(
                  segments: const [
                    ButtonSegment(
                      value: MathExpressionDisplay.inline,
                      label: Text('Inline'),
                    ),
                    ButtonSegment(
                      value: MathExpressionDisplay.block,
                      label: Text('Display'),
                    ),
                  ],
                  selected: {_display},
                  onSelectionChanged: (value) =>
                      setState(() => _display = value.single),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: _latex.trim().isEmpty
                  ? const Text('Your live formula preview appears here')
                  : SafeMathExpression(expression: preview),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_rawMode)
                      TextField(
                        controller: _sourceController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Formula source',
                          helperText:
                              'Advanced editing; existing formula remains safe if invalid.',
                        ),
                        onChanged: (value) => setState(() {
                          _latex = value;
                          _error = null;
                        }),
                      )
                    else
                      MathKeyboardField(
                        controller: _visualController,
                        builder: (context, focusNode, isMathActive) => MathField(
                          controller: _visualController,
                          focusNode: focusNode,
                          opensKeyboard: !isMathActive,
                          decoration: const InputDecoration(
                            labelText: 'Build formula visually',
                            helperText:
                                'Tap ƒx to use the complete mathematics keyboard.',
                          ),
                          onChanged: (value) => setState(() {
                            _latex = value;
                            _sourceController.text = value;
                            _error = null;
                          }),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _fallbackController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Readable description *',
                        hintText: 'Example: x squared divided by two equals 8',
                        helperText:
                            'Used by screen readers and if a renderer cannot display the formula.',
                      ),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Insert formula'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final expression = MathExpression(
      id: widget.initial?.id ?? const Uuid().v4(),
      latex: _latex.trim(),
      plainText: _fallbackController.text.trim(),
      display: _display,
      metadata: widget.initial?.metadata ?? const {},
    );
    final validation = const MathExpressionValidator().validate(expression);
    if (expression.plainText.isEmpty) {
      setState(() => _error = 'Add a readable description.');
      return;
    }
    if (!validation.isValid) {
      setState(() => _error = validation.message);
      return;
    }
    Navigator.pop(context, expression);
  }
}
