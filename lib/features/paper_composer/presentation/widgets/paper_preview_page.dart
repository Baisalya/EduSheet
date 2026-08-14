import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/safe_math_expression.dart';
import 'package:edusheet/features/paper_composer/application/question_rich_text_codec.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_style_preview.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_rich_text_preview.dart';
import 'package:edusheet/features/pdf/application/paper_marks_resolver.dart';
import 'package:edusheet/features/pdf/application/paper_template_resolver.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Read-only paper preview driven by the same resolved template used by export.
///
/// It deliberately follows template page width, border, header geometry and
/// single/two-column question flow so changing Appearance has an immediate,
/// trustworthy preview before PDF export.
class PaperPreviewPage extends ConsumerWidget {
  final Paper paper;

  const PaperPreviewPage({super.key, required this.paper});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = PaperTemplateResolver.resolve(
      paper.templateId,
      ref.watch(templateProvider).all,
    );
    final marksSummary = PaperMarksResolver.summarize(paper);
    final pageWidth = _previewPageWidth(template.paperSize);

    return Scaffold(
      appBar: AppBar(title: const Text('Paper preview')),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: pageWidth, minHeight: 900),
            child: Container(
              padding: const EdgeInsets.fromLTRB(34, 38, 34, 48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: template.hasBorder
                    ? Border.all(
                        color: Color(template.primaryColor.toInt()),
                        width: 1.5,
                      )
                    : null,
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
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: template.questionFontSize,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PaperHeaderLayoutPreview(
                        template: template,
                        paper: paper,
                        height: 220,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'Assigned: ${PaperMarksResolver.format(marksSummary.assignedMarks)} marks',
                          ),
                          const Spacer(),
                          Text(
                            'Maximum: ${PaperMarksResolver.format(marksSummary.effectiveMaximumMarks)}',
                          ),
                        ],
                      ),
                      if (marksSummary.teacherMessage != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          marksSummary.teacherMessage!,
                          style: const TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (paper.instruction.trim().isNotEmpty) ...[
                        const Divider(height: 28),
                        Text(
                          paper.instruction.trim(),
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                      const Divider(height: 30),
                      for (final section in paper.sections)
                        _PreviewSection(
                          section: section,
                          template: template,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static double _previewPageWidth(PaperSize size) {
    switch (size) {
      case PaperSize.a5:
        return 650;
      case PaperSize.a4:
      case PaperSize.letter:
        return 820;
      case PaperSize.a3:
        return 980;
      case PaperSize.legal:
        return 780;
    }
  }
}

class _PreviewSection extends StatelessWidget {
  final PaperSection section;
  final PaperTemplate template;

  const _PreviewSection({required this.section, required this.template});

  @override
  Widget build(BuildContext context) {
    final questions = section.questions;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (section.showTitle || section.prefix.trim().isNotEmpty)
            Text(
              '${section.prefix} ${section.showTitle ? section.title : ''}'.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (section.instruction?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                section.instruction!.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 12),
          if (template.paperLayout == PaperLayout.twoColumn)
            for (var index = 0; index < questions.length; index += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PreviewQuestion(
                        question: questions[index],
                        number: index + 1,
                      ),
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      child: index + 1 < questions.length
                          ? _PreviewQuestion(
                              question: questions[index + 1],
                              number: index + 2,
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
              )
          else
            for (final questionEntry in questions.asMap().entries)
              _PreviewQuestion(
                question: questionEntry.value,
                number: questionEntry.key + 1,
              ),
        ],
      ),
    );
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
            '[${PaperMarksResolver.format(question.marks)}]',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
