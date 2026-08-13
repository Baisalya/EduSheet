import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/safe_math_expression.dart';
import 'package:edusheet/features/paper_composer/application/question_rich_text_codec.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_rich_text_preview.dart';
import 'package:flutter/material.dart';

class PaperPreviewPage extends StatelessWidget {
  final Paper paper;

  const PaperPreviewPage({super.key, required this.paper});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paper preview')),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 820, minHeight: 900),
            padding: const EdgeInsets.fromLTRB(34, 38, 34, 48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Theme(
              data: ThemeData.light(useMaterial3: true),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.black, fontSize: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  if (paper.schoolName.trim().isNotEmpty)
                    Text(
                      paper.schoolName.trim(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    paper.title.trim().isEmpty ? 'New Paper' : paper.title.trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Total: ${_marks(paper.totalMarks)} marks'),
                      const Spacer(),
                      if (paper.maximumMarks != null)
                        Text('Maximum: ${_marks(paper.maximumMarks!)}'),
                    ],
                  ),
                  if (paper.instruction.trim().isNotEmpty) ...[
                    const Divider(height: 28),
                    Text(
                      paper.instruction.trim(),
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                  const Divider(height: 30),
                  for (final sectionEntry in paper.sections.asMap().entries) ...[
                    Text(
                      sectionEntry.value.title.trim().isEmpty
                          ? 'Section ${sectionEntry.key + 1}'
                          : sectionEntry.value.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (sectionEntry.value.instruction?.trim().isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          sectionEntry.value.instruction!.trim(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(height: 12),
                    for (final questionEntry
                        in sectionEntry.value.questions.asMap().entries)
                      _PreviewQuestion(
                        question: questionEntry.value,
                        number: questionEntry.key + 1,
                      ),
                    const SizedBox(height: 20),
                  ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _marks(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
}

class _PreviewQuestion extends StatelessWidget {
  static const _codec = QuestionRichTextCodec();
  final Question question;
  final int number;

  const _PreviewQuestion({required this.question, required this.number});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$number.',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                QuestionRichTextPreview(question: question, maxHeight: 220),
                for (final expression in _codec.unplacedMathExpressions(question))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: SafeMathExpression(expression: expression),
                  ),
                if (question.type.usesOptions) ...[
                  const SizedBox(height: 5),
                  for (final optionEntry in question.options.asMap().entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '${String.fromCharCode(65 + optionEntry.key)}) ${optionEntry.value.text}',
                      ),
                    ),
                ],
                if (question.isOptional)
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Text(
                      '(Optional / OR choice)',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '[${PaperPreviewPage._marks(question.marks)}]',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
