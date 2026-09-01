import 'dart:io';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/safe_math_expression.dart';
import 'package:edusheet/features/paper_composer/application/paper_marks_teacher_diagnostics.dart';
import 'package:edusheet/features/paper_composer/application/question_advanced_structure_service.dart';
import 'package:edusheet/features/paper_composer/application/word_content_block_service.dart';
import 'package:edusheet/features/editor/services/paper_structure_service.dart';
import 'package:edusheet/features/paper_composer/application/question_rich_text_codec.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/editor/domain/models/question_option_layout.dart';
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
    final pagePoints = _resolvedPagePoints(
      paper.pageLayout,
      template.paperSize,
    );
    final pageWidth = _previewPageWidth(pagePoints.width);
    final pageScale = pageWidth / pagePoints.width;
    final previewPadding = EdgeInsets.fromLTRB(
      (paper.pageLayout.margins.leftPoints * pageScale)
          .clamp(18, 120)
          .toDouble(),
      (paper.pageLayout.margins.topPoints * pageScale)
          .clamp(20, 140)
          .toDouble(),
      (paper.pageLayout.margins.rightPoints * pageScale)
          .clamp(18, 120)
          .toDouble(),
      (paper.pageLayout.margins.bottomPoints * pageScale)
          .clamp(24, 160)
          .toDouble(),
    );
    final pageMinHeight = (pagePoints.height * pageScale)
        .clamp(700, 1500)
        .toDouble();
    final marksDiagnostics = PaperMarksTeacherDiagnostics.fromPaper(paper);

    return Scaffold(
      appBar: AppBar(title: const Text('Paper preview')),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (marksDiagnostics.hasMismatch) ...[
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: pageWidth),
                  child: _TeacherMarksNotice(
                    message: marksDiagnostics.mismatchMessage!,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ConstrainedBox(
                key: const Key('paper-preview-document'),
                constraints: BoxConstraints(
                  maxWidth: pageWidth,
                  minHeight: pageMinHeight,
                ),
                child: Container(
                  padding: previewPadding,
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
                        height: paper.pageLayout.lineSpacing,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (paper.headerText.trim().isNotEmpty ||
                              (paper.showPageNumbers &&
                                  paper.pageLayout.pageNumberPosition ==
                                      PaperPageNumberPosition.headerRight)) ...[
                            _PreviewRunningHeader(paper: paper),
                            const Divider(height: 18),
                          ],
                          PaperHeaderLayoutPreview(
                            template: template,
                            paper: paper,
                            height: 220,
                          ),
                          const SizedBox(height: 10),
                          if (paper.instruction.trim().isNotEmpty) ...[
                            const Divider(height: 28),
                            Text(
                              paper.instruction.trim(),
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const Divider(height: 30),
                          for (final section in paper.sections)
                            _PreviewSection(
                              paper: paper,
                              section: section,
                              template: template,
                            ),
                          if (paper.footerText.trim().isNotEmpty ||
                              (paper.showPageNumbers &&
                                  paper.pageLayout.pageNumberPosition !=
                                      PaperPageNumberPosition.headerRight)) ...[
                            const SizedBox(height: 18),
                            const Divider(height: 18),
                            _PreviewFooter(paper: paper),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static ({double width, double height}) _resolvedPagePoints(
    PaperPageLayout layout,
    PaperSize templateSize,
  ) {
    final explicit = layout.explicitPageSizePoints;
    if (explicit != null) return explicit;
    final portrait = switch (templateSize) {
      PaperSize.a4 => (width: 595.28, height: 841.89),
      PaperSize.a5 => (width: 419.53, height: 595.28),
      PaperSize.a3 => (width: 841.89, height: 1190.55),
      PaperSize.letter => (width: 612.0, height: 792.0),
      PaperSize.legal => (width: 612.0, height: 1008.0),
    };
    if (layout.orientation == PaperPageOrientation.landscape) {
      return (width: portrait.height, height: portrait.width);
    }
    return portrait;
  }

  static double _previewPageWidth(double widthPoints) {
    return (820 * widthPoints / 595.28).clamp(620, 980).toDouble();
  }
}

class _PreviewRunningHeader extends StatelessWidget {
  final Paper paper;

  const _PreviewRunningHeader({required this.paper});

  @override
  Widget build(BuildContext context) {
    final showNumber =
        paper.showPageNumbers &&
        paper.pageLayout.pageNumberPosition ==
            PaperPageNumberPosition.headerRight;
    return Row(
      children: [
        if (paper.headerText.trim().isNotEmpty)
          Expanded(
            child: Text(
              paper.headerText.trim(),
              style: const TextStyle(fontSize: 9),
            ),
          )
        else
          const Spacer(),
        if (showNumber)
          const Text(
            'Page 1',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 9),
          ),
      ],
    );
  }
}

class _PreviewFooter extends StatelessWidget {
  final Paper paper;

  const _PreviewFooter({required this.paper});

  @override
  Widget build(BuildContext context) {
    final position = paper.pageLayout.pageNumberPosition;
    final parts = <String>[
      if (paper.footerText.trim().isNotEmpty) paper.footerText.trim(),
      if (paper.showPageNumbers &&
          position != PaperPageNumberPosition.headerRight)
        'Page 1',
    ];
    return Text(
      parts.join('  •  '),
      textAlign: position == PaperPageNumberPosition.footerRight
          ? TextAlign.right
          : TextAlign.center,
      style: const TextStyle(fontSize: 9),
    );
  }
}

class _TeacherMarksNotice extends StatelessWidget {
  final String message;

  const _TeacherMarksNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const Key('paper-preview-teacher-diagnostics'),
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 19,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teacher check • Not printed',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  final Paper paper;
  final PaperSection section;
  final PaperTemplate template;

  const _PreviewSection({
    required this.paper,
    required this.section,
    required this.template,
  });

  @override
  Widget build(BuildContext context) {
    final questions = section.questions;
    final hasManualPageBreak = questions.any(
      (question) =>
          question.isWordContentBlock &&
          WordContentBlockService.kindOf(question) ==
              WordContentBlockKind.pageBreak,
    );
    final answerRule = PaperStructureService.answerRuleText(section);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (section.pageBreakBefore)
            const _PreviewPageBreak(label: 'Section starts on a new page'),
          if (section.showTitle || section.prefix.trim().isNotEmpty)
            Text(
              '${section.prefix} ${section.showTitle ? section.title : ''}'
                  .trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
          if (answerRule != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                answerRule,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          if (section.showDivider) const Divider(height: 22),
          const SizedBox(height: 4),
          if (template.paperLayout == PaperLayout.twoColumn &&
              !hasManualPageBreak)
            for (var index = 0; index < questions.length; index += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PreviewQuestion(
                        paper: paper,
                        question: questions[index],
                        label: questions[index].isWordContentBlock
                            ? ''
                            : PaperStructureService.questionLabel(
                                PaperStructureService.numberedQuestionOrdinal(
                                  section,
                                  index,
                                ),
                                paper,
                                section,
                              ),
                        section: section,
                      ),
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      child: index + 1 < questions.length
                          ? _PreviewQuestion(
                              paper: paper,
                              question: questions[index + 1],
                              label: questions[index + 1].isWordContentBlock
                                  ? ''
                                  : PaperStructureService.questionLabel(
                                      PaperStructureService.numberedQuestionOrdinal(
                                        section,
                                        index + 1,
                                      ),
                                      paper,
                                      section,
                                    ),
                              section: section,
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
              )
          else
            for (final questionEntry in questions.asMap().entries)
              _PreviewQuestion(
                paper: paper,
                question: questionEntry.value,
                label: questionEntry.value.isWordContentBlock
                    ? ''
                    : PaperStructureService.questionLabel(
                        PaperStructureService.numberedQuestionOrdinal(
                          section,
                          questionEntry.key,
                        ),
                        paper,
                        section,
                      ),
                section: section,
              ),
        ],
      ),
    );
  }
}

class _PreviewQuestion extends StatelessWidget {
  final Paper paper;
  final Question question;
  final String label;
  final PaperSection section;

  const _PreviewQuestion({
    required this.paper,
    required this.question,
    required this.label,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    if (question.isWordContentBlock &&
        WordContentBlockService.kindOf(question) ==
            WordContentBlockKind.pageBreak) {
      return const _PreviewPageBreak();
    }
    final paragraphGap = paper.pageLayout.paragraphSpacingPoints;
    if (question.isWordContentBlock) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: (4 + paragraphGap).clamp(6, 30).toDouble(),
        ),
        child: _PreviewQuestionContent(question: question, section: section),
      );
    }
    final answerSpace = QuestionAdvancedStructureService.resolveAnswerSpace(
      question,
      section,
    );
    return Padding(
      padding: EdgeInsets.only(
        bottom: (8 + paragraphGap).clamp(10, 36).toDouble(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  '$label.',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: _PreviewQuestionContent(
                  question: question,
                  section: section,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '[${PaperMarksResolver.format(question.marks)}]',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (answerSpace.isVisible)
            Padding(
              padding: const EdgeInsets.only(left: 38, top: 6),
              child: _AnswerSpacePreview(answerSpace: answerSpace),
            ),
        ],
      ),
    );
  }
}

class _PreviewPageBreak extends StatelessWidget {
  final String label;

  const _PreviewPageBreak({this.label = 'Page break'});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
          const SizedBox(width: 8),
          Icon(
            Icons.insert_page_break_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
        ],
      ),
    );
  }
}

class _PreviewQuestionContent extends StatelessWidget {
  static const _codec = QuestionRichTextCodec();

  final Question question;
  final PaperSection section;

  const _PreviewQuestionContent({
    required this.question,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    final advanced = QuestionAdvancedContent.fromQuestion(question);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestionRichTextPreview(question: question, maxHeight: 220),
        if (advanced.hasStimulus) ...[
          const SizedBox(height: 7),
          _PreviewStimulus(stimulus: advanced.stimulus!),
        ],
        for (final expression in _codec.unplacedMathExpressions(question))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SafeMathExpression(expression: expression),
          ),
        if (question.attachments.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final attachment in question.attachments)
            _PreviewAttachment(attachment: attachment),
        ],
        if (question.tableData != null) ...[
          const SizedBox(height: 7),
          _PreviewQuestionTable(table: question.tableData!),
        ],
        if (advanced.hasWordBank) ...[
          const SizedBox(height: 7),
          _PreviewWordBank(items: advanced.wordBank),
        ],
        if (question.options.isNotEmpty) ...[
          const SizedBox(height: 5),
          _PreviewOptions(question: question),
        ],
        if (question.subQuestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final entry in question.subQuestions.asMap().entries)
            _PreviewNestedQuestion(
              label: QuestionAdvancedStructureService.partLabel(entry.key),
              question: entry.value,
              section: section,
            ),
        ],
        if (question.internalChoices.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final entry in question.internalChoices.asMap().entries) ...[
            if (entry.key > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 5),
                child: Center(
                  child: Text(
                    'OR',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            _PreviewNestedQuestion(
              label: '',
              question: entry.value,
              section: section,
            ),
          ],
        ],
        if (question.isOptional)
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Text(
              '(Optional / OR choice)',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}

class _PreviewNestedQuestion extends StatelessWidget {
  final String label;
  final Question question;
  final PaperSection section;

  const _PreviewNestedQuestion({
    required this.label,
    required this.question,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    final answerSpace = QuestionAdvancedStructureService.resolveAnswerSpace(
      question,
      section,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label.isNotEmpty)
                SizedBox(
                  width: 34,
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              Expanded(
                child: _PreviewQuestionContent(
                  question: question,
                  section: section,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '[${PaperMarksResolver.format(question.marks)}]',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (answerSpace.questionOverride && answerSpace.isVisible)
            Padding(
              padding: EdgeInsets.only(left: label.isEmpty ? 0 : 34, top: 4),
              child: _AnswerSpacePreview(answerSpace: answerSpace),
            ),
        ],
      ),
    );
  }
}

class _PreviewStimulus extends StatelessWidget {
  final QuestionStimulus stimulus;

  const _PreviewStimulus({required this.stimulus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stimulus.title.trim().isNotEmpty) ...[
            Text(
              stimulus.title.trim(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            stimulus.text,
            style: TextStyle(
              fontStyle: stimulus.kind == QuestionStimulusKind.poem
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewWordBank extends StatelessWidget {
  final List<String> items;

  const _PreviewWordBank({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(border: Border.all(color: Colors.black26)),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 5,
        children: items.map((item) => Text(item)).toList(),
      ),
    );
  }
}

class _PreviewAttachment extends StatelessWidget {
  final QuestionAttachment attachment;

  const _PreviewAttachment({required this.attachment});

  @override
  Widget build(BuildContext context) {
    if (attachment.kind != QuestionAttachmentKind.image ||
        attachment.path.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final file = File(attachment.path);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (file.existsSync())
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: Image.file(
                file,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          if (attachment.caption.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                attachment.caption.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewQuestionTable extends StatelessWidget {
  final QuestionTable table;

  const _PreviewQuestionTable({required this.table});

  @override
  Widget build(BuildContext context) {
    final columnCount = table.headers.isNotEmpty
        ? table.headers.length
        : (table.rows.isEmpty ? 0 : table.rows.first.length);
    if (columnCount == 0) return const SizedBox.shrink();

    final rows = <TableRow>[];
    if (table.headers.isNotEmpty) {
      rows.add(
        TableRow(
          children: List.generate(
            columnCount,
            (index) => _PreviewTableCell(
              text: index < table.headers.length ? table.headers[index] : '',
              bold: true,
            ),
          ),
        ),
      );
    }
    for (final row in table.rows) {
      rows.add(
        TableRow(
          children: List.generate(
            columnCount,
            (index) =>
                _PreviewTableCell(text: index < row.length ? row[index] : ''),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (table.caption.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              table.caption.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        Table(
          border: TableBorder.all(color: Colors.black45),
          children: rows,
        ),
      ],
    );
  }
}

class _PreviewTableCell extends StatelessWidget {
  final String text;
  final bool bold;

  const _PreviewTableCell({required this.text, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
        ),
      ),
    );
  }
}

class _PreviewOptions extends StatelessWidget {
  final Question question;

  const _PreviewOptions({required this.question});

  @override
  Widget build(BuildContext context) {
    final layout = QuestionOptionLayoutCodec.fromQuestion(question);
    final options = question.options.asMap().entries.toList();

    Widget option(int index) {
      final entry = options[index];
      return Text(
        '${String.fromCharCode(65 + entry.key)}) ${entry.value.text}',
      );
    }

    return switch (layout) {
      QuestionOptionLayout.vertical => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < options.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: option(index),
            ),
        ],
      ),
      QuestionOptionLayout.inline => Wrap(
        spacing: 16,
        runSpacing: 5,
        children: [
          for (var index = 0; index < options.length; index++) option(index),
        ],
      ),
      QuestionOptionLayout.twoColumn => LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 14) / 2;
          return Wrap(
            spacing: 14,
            runSpacing: 5,
            children: [
              for (var index = 0; index < options.length; index++)
                SizedBox(width: itemWidth, child: option(index)),
            ],
          );
        },
      ),
    };
  }
}

class _AnswerSpacePreview extends StatelessWidget {
  final ResolvedQuestionAnswerSpace answerSpace;

  const _AnswerSpacePreview({required this.answerSpace});

  @override
  Widget build(BuildContext context) {
    switch (answerSpace.style) {
      case QuestionAnswerSpaceStyle.graph:
        return Container(
          height: answerSpace.lines * 10.0,
          decoration: BoxDecoration(border: Border.all(color: Colors.black26)),
          child: CustomPaint(painter: _PreviewGraphPainter()),
        );
      case QuestionAnswerSpaceStyle.box:
        return Container(
          height: answerSpace.lines * 14.0,
          decoration: BoxDecoration(border: Border.all(color: Colors.black38)),
        );
      case QuestionAnswerSpaceStyle.ruled:
        return Column(
          children: [
            for (var index = 0; index < answerSpace.lines; index++)
              Container(
                height: 14,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black26)),
                ),
              ),
          ],
        );
      case QuestionAnswerSpaceStyle.blank:
        return SizedBox(height: answerSpace.lines * 14.0);
      case QuestionAnswerSpaceStyle.none:
        return const SizedBox.shrink();
    }
  }
}

class _PreviewGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 0.5;
    const step = 10.0;
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
