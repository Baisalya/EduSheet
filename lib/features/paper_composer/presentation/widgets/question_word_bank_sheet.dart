import 'package:edusheet/features/paper_composer/presentation/widgets/question_math_text_field.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';

class QuestionWordBankSheet extends StatefulWidget {
  final List<String> initial;

  const QuestionWordBankSheet({super.key, this.initial = const []});

  static Future<List<String>?> show(
    BuildContext context, {
    List<String> initial = const [],
  }) {
    return showAdaptiveModalBottomSheet<List<String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => QuestionWordBankSheet(initial: initial),
    );
  }

  @override
  State<QuestionWordBankSheet> createState() => _QuestionWordBankSheetState();
}

class _QuestionWordBankSheetState extends State<QuestionWordBankSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial.join('\n'));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> _items() {
    return _controller.text
        .split(RegExp(r'[\n,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewItems = _items();
    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Word bank',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter one word or phrase per line. Commas also work. EduSheet prints the bank as a compact box, while every item stays editable.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  QuestionMathTextField(
                    controller: _controller,
                    minLines: 7,
                    maxLines: 12,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      alignLabelWithHint: true,
                      labelText: 'Words / phrases',
                      hintText: 'is\nare\nhas\nhad',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (previewItems.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Preview',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: previewItems
                          .map((item) => Chip(label: Text(item)))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _items()),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Use word bank'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
