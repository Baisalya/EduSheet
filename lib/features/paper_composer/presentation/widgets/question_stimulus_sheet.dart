import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_math_text_field.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';

class QuestionStimulusSheet extends StatefulWidget {
  final QuestionStimulus? initial;

  const QuestionStimulusSheet({super.key, this.initial});

  static Future<QuestionStimulus?> show(
    BuildContext context, {
    QuestionStimulus? initial,
  }) {
    return showAdaptiveModalBottomSheet<QuestionStimulus>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => QuestionStimulusSheet(initial: initial),
    );
  }

  @override
  State<QuestionStimulusSheet> createState() => _QuestionStimulusSheetState();
}

class _QuestionStimulusSheetState extends State<QuestionStimulusSheet> {
  late QuestionStimulusKind _kind;
  late final TextEditingController _title;
  late final TextEditingController _text;
  String? _error;

  @override
  void initState() {
    super.initState();
    _kind = widget.initial?.kind ?? QuestionStimulusKind.passage;
    _title = TextEditingController(text: widget.initial?.title ?? '');
    _text = TextEditingController(text: widget.initial?.text ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(
        () => _error = 'Add the passage, poem, case study or source text.',
      );
      return;
    }
    Navigator.pop(
      context,
      QuestionStimulus(kind: _kind, title: _title.text.trim(), text: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.initial == null
                        ? 'Add reading / source block'
                        : 'Edit reading / source block',
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
                    'Use this for a passage, poem, case study or source material that belongs with the question. The question prompt stays independently editable.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<QuestionStimulusKind>(
                    initialValue: _kind,
                    decoration: const InputDecoration(labelText: 'Block type'),
                    items: QuestionStimulusKind.values
                        .map(
                          (kind) => DropdownMenuItem(
                            value: kind,
                            child: Text(kind.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _kind = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  QuestionMathTextField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Heading (optional)',
                      hintText: 'Read the passage and answer the questions',
                    ),
                  ),
                  const SizedBox(height: 12),
                  QuestionMathTextField(
                    controller: _text,
                    minLines: 9,
                    maxLines: 18,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      alignLabelWithHint: true,
                      labelText: '${_kind.label} text',
                      hintText: 'Type or paste the source text here…',
                      errorText: _error,
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
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
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Use this block'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
