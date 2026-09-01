import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';

class QuestionAnswerSpaceSheet extends StatefulWidget {
  final QuestionAnswerSpace initial;

  const QuestionAnswerSpaceSheet({
    super.key,
    this.initial = const QuestionAnswerSpace(),
  });

  static Future<QuestionAnswerSpace?> show(
    BuildContext context, {
    QuestionAnswerSpace initial = const QuestionAnswerSpace(),
  }) {
    return showAdaptiveModalBottomSheet<QuestionAnswerSpace>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => QuestionAnswerSpaceSheet(initial: initial),
    );
  }

  @override
  State<QuestionAnswerSpaceSheet> createState() =>
      _QuestionAnswerSpaceSheetState();
}

class _QuestionAnswerSpaceSheetState extends State<QuestionAnswerSpaceSheet> {
  late QuestionAnswerSpaceStyle _style;
  late double _lines;

  @override
  void initState() {
    super.initState();
    _style = widget.initial.style == QuestionAnswerSpaceStyle.none
        ? QuestionAnswerSpaceStyle.ruled
        : widget.initial.style;
    _lines = (widget.initial.lines <= 0 ? 4 : widget.initial.lines).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FractionallySizedBox(
      heightFactor: 0.66,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Answer space for this question',
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
                    'This overrides the section answer-area setting only for this question. Remove it later to fall back to the section rule.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: QuestionAnswerSpaceStyle.values
                        .where(
                          (style) => style != QuestionAnswerSpaceStyle.none,
                        )
                        .map(
                          (style) => ChoiceChip(
                            label: Text(style.label),
                            selected: _style == style,
                            onSelected: (_) => setState(() => _style = style),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Space size',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text('${_lines.round()} lines'),
                    ],
                  ),
                  Slider(
                    value: _lines,
                    min: 1,
                    max: 16,
                    divisions: 15,
                    label: _lines.round().toString(),
                    onChanged: (value) => setState(() => _lines = value),
                  ),
                  const SizedBox(height: 8),
                  _AnswerSpaceMiniPreview(style: _style, lines: _lines.round()),
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
                  onPressed: () => Navigator.pop(
                    context,
                    QuestionAnswerSpace(style: _style, lines: _lines.round()),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Use answer space'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerSpaceMiniPreview extends StatelessWidget {
  final QuestionAnswerSpaceStyle style;
  final int lines;

  const _AnswerSpaceMiniPreview({required this.style, required this.lines});

  @override
  Widget build(BuildContext context) {
    final shown = lines.clamp(1, 5).toInt();
    if (style == QuestionAnswerSpaceStyle.box) {
      return Container(
        height: shown * 18.0,
        decoration: BoxDecoration(border: Border.all(color: Colors.black26)),
      );
    }
    if (style == QuestionAnswerSpaceStyle.graph) {
      return Container(
        height: shown * 18.0,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        child: CustomPaint(painter: _MiniGridPainter()),
      );
    }
    if (style == QuestionAnswerSpaceStyle.ruled) {
      return Column(
        children: [
          for (var index = 0; index < shown; index++)
            Container(
              height: 18,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black26)),
              ),
            ),
        ],
      );
    }
    return SizedBox(height: shown * 18);
  }
}

class _MiniGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 0.5;
    const step = 12.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
