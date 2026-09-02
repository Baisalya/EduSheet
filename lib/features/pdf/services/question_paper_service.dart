import 'dart:convert';
import 'dart:io';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/editor/domain/models/question_option_layout.dart';
import 'package:edusheet/features/editor/services/paper_structure_service.dart';
import 'package:edusheet/features/geometry_builder/application/geometry_embed_layout.dart';
import 'package:edusheet/features/geometry_builder/services/geometry_svg_service.dart';
import 'package:edusheet/features/omr/domain/models/omr_config.dart';
import 'package:edusheet/features/paper_composer/application/question_advanced_structure_service.dart';
import 'package:edusheet/features/paper_composer/application/word_content_block_service.dart';
import 'package:edusheet/features/paper_composer/application/word_shape_service.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/omr/services/omr_widgets_builder.dart';
import 'package:edusheet/features/pdf/application/paper_document_marks.dart';
import 'package:edusheet/features/pdf/application/paper_header_layout_factory.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_export_config.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/services/builders/header_builders.dart';
import 'package:edusheet/features/pdf/services/pdf_export_theme_service.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

class QuestionPaperService {
  static Future<pw.ThemeData> _loadTheme() {
    return PdfExportThemeService.loadTheme();
  }

  static void preloadTheme() {
    _loadTheme();
  }

  static PdfPageFormat _getPageFormat(PaperSize size) {
    switch (size) {
      case PaperSize.a4:
        return PdfPageFormat.a4;
      case PaperSize.a5:
        return PdfPageFormat.a5;
      case PaperSize.a3:
        return PdfPageFormat.a3;
      case PaperSize.letter:
        return PdfPageFormat.letter;
      case PaperSize.legal:
        return PdfPageFormat.legal;
    }
  }

  static PdfPageFormat _pageFormatForPaper(
    PaperPageLayout layout,
    PaperSize templateSize,
  ) {
    var format = switch (layout.pageSize) {
      PaperPageSize.useTemplate => _getPageFormat(templateSize),
      PaperPageSize.a4 => PdfPageFormat.a4,
      PaperPageSize.a5 => PdfPageFormat.a5,
      PaperPageSize.a3 => PdfPageFormat.a3,
      PaperPageSize.letter => PdfPageFormat.letter,
      PaperPageSize.legal => PdfPageFormat.legal,
    };
    if (layout.orientation == PaperPageOrientation.landscape) {
      format = format.landscape;
    }
    return format;
  }

  static Future<pw.Document> generateDocument(
    Paper paper,
    PaperTemplate template, {
    PaperExportConfig? config,
  }) async {
    final usePaperLayout = config == null;
    final exportConfig = config ?? const PaperExportConfig();
    final configErrors = exportConfig.validate();
    if (configErrors.isNotEmpty) {
      throw ArgumentError(configErrors.join(' '));
    }
    final theme = await _loadTheme();
    final pdf = pw.Document(theme: theme);

    // Pre-load standard logos in parallel
    final List<pw.ImageProvider?> logos = await Future.wait(
      paper.logos.map((path) async {
        if (path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            return pw.MemoryImage(await file.readAsBytes());
          }
        }
        return null;
      }),
    );

    // Pre-load custom template images in parallel
    final Map<String, pw.ImageProvider> customImages = {};
    final layout = PaperHeaderLayoutFactory.resolve(template);
    final logoElements = layout.elements
        .where((el) => el.type == ElementType.logo && el.content.isNotEmpty)
        .toList();

    final customImageEntries = await Future.wait(
      logoElements.map((el) async {
        final file = File(el.content);
        if (await file.exists()) {
          return MapEntry(el.content, pw.MemoryImage(await file.readAsBytes()));
        }
        return null;
      }),
    );

    for (var entry in customImageEntries) {
      if (entry != null) {
        customImages[entry.key] = entry.value;
      }
    }

    final questionImages = <String, pw.ImageProvider>{};
    final questionImageEntries = await Future.wait(
      _questionImagePaths(paper).map((imagePath) async {
        final file = File(imagePath);
        if (!await file.exists()) return null;
        return MapEntry<String, pw.ImageProvider>(
          imagePath,
          pw.MemoryImage(await file.readAsBytes()),
        );
      }),
    );
    for (final entry in questionImageEntries) {
      if (entry != null) questionImages[entry.key] = entry.value;
    }

    final headerBuilder = CustomHeaderBuilder();
    var pageFormat = usePaperLayout
        ? _pageFormatForPaper(paper.pageLayout, template.paperSize)
        : switch (exportConfig.pageSize) {
            ExportPageSize.useTemplate => _getPageFormat(template.paperSize),
            ExportPageSize.a4 => PdfPageFormat.a4,
            ExportPageSize.letter => PdfPageFormat.letter,
          };
    if (!usePaperLayout &&
        exportConfig.orientation == ExportOrientation.landscape) {
      pageFormat = pageFormat.landscape;
    }
    final bookletExtra = exportConfig.booklet.enabled
        ? exportConfig.booklet.gutterPoints / 2
        : 0.0;
    final pageMargins = usePaperLayout
        ? pw.EdgeInsets.fromLTRB(
            paper.pageLayout.margins.leftPoints + bookletExtra,
            paper.pageLayout.margins.topPoints,
            paper.pageLayout.margins.rightPoints + bookletExtra,
            paper.pageLayout.margins.bottomPoints,
          )
        : pw.EdgeInsets.symmetric(
            horizontal: exportConfig.marginPoints + bookletExtra,
            vertical: exportConfig.marginPoints,
          );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          margin: pageMargins,
          buildBackground: (context) {
            if (template.hasBorder) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Container(
                  margin: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: template.primaryColor,
                      width: 1,
                    ),
                  ),
                ),
              );
            }
            return pw.SizedBox();
          },
        ),
        header: (context) {
          final parts = <String>[];
          if (paper.headerText.trim().isNotEmpty) {
            parts.add(paper.headerText.trim());
          }
          if (paper.showPageNumbers &&
              paper.pageLayout.pageNumberPosition ==
                  PaperPageNumberPosition.headerRight) {
            parts.add('Page ${context.pageNumber} of ${context.pagesCount}');
          }
          if (parts.isEmpty) return pw.SizedBox();
          final rightAligned =
              paper.pageLayout.pageNumberPosition ==
              PaperPageNumberPosition.headerRight;
          return pw.Container(
            alignment: rightAligned
                ? pw.Alignment.centerRight
                : pw.Alignment.center,
            padding: pw.EdgeInsets.only(
              bottom: usePaperLayout
                  ? paper.pageLayout.headerDistancePoints
                        .clamp(0, 36)
                        .toDouble()
                  : 6,
            ),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
            ),
            child: pw.Text(
              parts.join('  •  '),
              style: pw.TextStyle(fontSize: 9 * exportConfig.fontScale),
            ),
          );
        },
        footer: (context) {
          final parts = <String>[];
          if (paper.footerText.trim().isNotEmpty) {
            parts.add(paper.footerText.trim());
          }
          final pageNumberPosition = paper.pageLayout.pageNumberPosition;
          if (paper.showPageNumbers &&
              pageNumberPosition != PaperPageNumberPosition.headerRight) {
            parts.add('Page ${context.pageNumber} of ${context.pagesCount}');
          }
          if (parts.isEmpty) return pw.SizedBox();
          return pw.Container(
            alignment: pageNumberPosition == PaperPageNumberPosition.footerRight
                ? pw.Alignment.centerRight
                : pw.Alignment.center,
            padding: pw.EdgeInsets.only(
              top: usePaperLayout
                  ? paper.pageLayout.footerDistancePoints
                        .clamp(0, 36)
                        .toDouble()
                  : 6,
            ),
            child: pw.Text(
              parts.join('  •  '),
              style: const pw.TextStyle(fontSize: 9),
            ),
          );
        },
        build: (context) => [
          if (paper.includeCoverPage) ...[
            _buildCoverPage(paper, template, exportConfig),
            pw.NewPage(),
          ],
          headerBuilder.build(
            paper,
            logos,
            template,
            customImages: customImages,
          ),
          if (exportConfig.outputMode == PaperOutputMode.multipleSet)
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                'SET ${exportConfig.setLabel.trim().toUpperCase()}',
                style: pw.TextStyle(
                  fontSize: 16 * exportConfig.fontScale,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          if (exportConfig.includesAnswers)
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                exportConfig.includesSolutions
                    ? 'TEACHER SOLUTION COPY'
                    : 'ANSWER KEY',
                style: pw.TextStyle(
                  fontSize: 13 * exportConfig.fontScale,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          if (paper.instruction.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8, bottom: 8),
              child: pw.Text(
                paper.instruction.trim(),
                style: pw.TextStyle(
                  fontSize: template.questionFontSize,
                  fontStyle: pw.FontStyle.italic,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: _pdfTextAlign(paper.instructionAlignment),
              ),
            ),
          ...paper.sections.expand(
            (section) => [
              if (section.pageBreakBefore) pw.NewPage(),
              ..._buildSectionFlow(
                section,
                template,
                paper,
                exportConfig,
                questionImages,
              ),
            ],
          ),
          if (paper.includeOmr)
            ..._buildOmrSheet(paper, logos.isNotEmpty ? logos.first : null),
        ],
      ),
    );

    return pdf;
  }

  static List<pw.Widget> _buildSectionFlow(
    PaperSection section,
    PaperTemplate template,
    Paper paper,
    PaperExportConfig config,
    Map<String, pw.ImageProvider> questionImages,
  ) {
    final widgets = <pw.Widget>[];
    var current = <MapEntry<int, Question>>[];
    var showHeading = true;

    void flush() {
      if (current.isEmpty && !showHeading) return;
      widgets.add(
        _buildSectionSegment(
          section,
          current,
          template,
          paper,
          config,
          questionImages,
          showHeading: showHeading,
        ),
      );
      current = <MapEntry<int, Question>>[];
      showHeading = false;
    }

    for (final entry in section.questions.asMap().entries) {
      final question = entry.value;
      final isPageBreak =
          question.isWordContentBlock &&
          WordContentBlockService.kindOf(question) ==
              WordContentBlockKind.pageBreak;
      if (!isPageBreak) {
        current.add(entry);
        continue;
      }

      if (current.isNotEmpty) flush();
      widgets.add(pw.NewPage());
    }

    if (current.isNotEmpty || showHeading) flush();
    return widgets;
  }

  static pw.Widget _buildSectionSegment(
    PaperSection section,
    List<MapEntry<int, Question>> entries,
    PaperTemplate template,
    Paper paper,
    PaperExportConfig config,
    Map<String, pw.ImageProvider> questionImages, {
    required bool showHeading,
  }) {
    final heading = showHeading
        ? _buildSectionHeadingWidgets(section, template, paper, config)
        : <pw.Widget>[];

    if (showHeading &&
        section.keepTogether &&
        entries.isNotEmpty &&
        template.paperLayout != PaperLayout.twoColumn &&
        _canKeepSectionHeadingWith(entries.first.value, section)) {
      final firstEntry = entries.first;
      final firstQuestion = _buildQuestion(
        PaperStructureService.numberedQuestionOrdinal(section, firstEntry.key),
        firstEntry.value,
        template,
        paper,
        section,
        config,
        questionImages,
      );
      final remaining = entries.skip(1).toList();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [...heading, firstQuestion],
            ),
          ),
          if (remaining.isNotEmpty)
            _buildQuestionEntries(
              section,
              remaining,
              template,
              paper,
              config,
              questionImages,
            ),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        ...heading,
        _buildQuestionEntries(
          section,
          entries,
          template,
          paper,
          config,
          questionImages,
        ),
      ],
    );
  }

  static List<pw.Widget> _buildSectionHeadingWidgets(
    PaperSection section,
    PaperTemplate template,
    Paper paper,
    PaperExportConfig config,
  ) {
    final answerRule = PaperStructureService.answerRuleText(section);
    final marksText = section.sectionMarksText;
    final headingText = section.formattedHeadingText;
    final headingFontSize =
        18 * config.fontScale * section.headingSize.exportScale;
    final headingWidget = pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: section.headingBoxed
          ? pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700))
          : template.type == TemplateType.coaching
          ? pw.BoxDecoration(color: template.secondaryColor)
          : null,
      child: section.sectionMarksDisplay == SectionMarksDisplay.right
          ? pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    headingText,
                    textAlign: _pdfTextAlign(section.headingAlignment),
                    style: pw.TextStyle(
                      fontSize: headingFontSize,
                      fontWeight: section.headingBold
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      color: template.type == TemplateType.coaching
                          ? template.primaryColor
                          : PdfColors.black,
                    ),
                  ),
                ),
                if (marksText != null) ...[
                  pw.SizedBox(width: 12),
                  pw.Text(
                    marksText,
                    style: pw.TextStyle(
                      fontSize: 11 * config.fontScale,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ],
            )
          : pw.Text(
              section.sectionMarksDisplay == SectionMarksDisplay.inline &&
                      marksText != null
                  ? '$headingText ($marksText)'
                  : headingText,
              textAlign: _pdfTextAlign(section.headingAlignment),
              style: pw.TextStyle(
                fontSize: headingFontSize,
                fontWeight: section.headingBold
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                color: template.type == TemplateType.coaching
                    ? template.primaryColor
                    : PdfColors.black,
              ),
            ),
    );

    return [
      pw.SizedBox(height: section.spacing.beforePoints * config.spacingScale),
      if (section.showTopDivider) pw.Divider(),
      if (section.showTitle || section.prefix.isNotEmpty) headingWidget,
      if (section.instruction != null && section.instruction!.isNotEmpty)
        pw.Padding(
          padding: pw.EdgeInsets.only(
            bottom: paper.pageLayout.paragraphSpacingPoints
                .clamp(2, 18)
                .toDouble(),
          ),
          child: pw.Text(
            '${section.showInstructionLabel ? 'Instruction: ' : ''}${section.instruction}',
            textAlign: _pdfTextAlign(section.instructionAlignment),
            style: pw.TextStyle(
              fontStyle: pw.FontStyle.italic,
              fontSize: 12 * config.fontScale,
            ),
          ),
        ),
      if (answerRule != null)
        pw.Padding(
          padding: pw.EdgeInsets.only(
            bottom: paper.pageLayout.paragraphSpacingPoints
                .clamp(2, 18)
                .toDouble(),
          ),
          child: pw.Text(
            answerRule,
            textAlign: _pdfTextAlign(section.answerRuleAlignment),
            style: pw.TextStyle(
              fontSize: 11 * config.fontScale,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      if (section.showBottomDivider) pw.Divider(),
      pw.SizedBox(height: section.spacing.afterPoints * config.spacingScale),
    ];
  }

  static bool _canKeepSectionHeadingWith(
    Question question,
    PaperSection section,
  ) {
    if (question.isWordContentBlock) return false;
    if (question.attachments.isNotEmpty || question.tableData != null) {
      return false;
    }
    if (question.subQuestions.isNotEmpty ||
        question.internalChoices.isNotEmpty) {
      return false;
    }
    final answerSpace = QuestionAdvancedStructureService.resolveAnswerSpace(
      question,
      section,
    );
    if (answerSpace.isVisible && answerSpace.lines > 4) return false;
    return question.plainTextAccessibility.length <= 480;
  }

  static pw.Widget _buildQuestionEntries(
    PaperSection section,
    List<MapEntry<int, Question>> entries,
    PaperTemplate template,
    Paper paper,
    PaperExportConfig config,
    Map<String, pw.ImageProvider> questionImages,
  ) {
    final questions = entries.map((entry) {
      return _buildQuestion(
        PaperStructureService.numberedQuestionOrdinal(section, entry.key),
        entry.value,
        template,
        paper,
        section,
        config,
        questionImages,
      );
    }).toList();

    if (template.paperLayout != PaperLayout.twoColumn) {
      return pw.Column(children: questions);
    }

    return pw.LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints?.maxWidth.isFinite == true
            ? constraints!.maxWidth
            : CustomLayout.designWidth;
        final gap = 16.0;
        final columnWidth = (contentWidth - gap) / 2;

        return pw.Wrap(
          spacing: gap,
          runSpacing: 0,
          children: questions
              .map(
                (question) => pw.Container(width: columnWidth, child: question),
              )
              .toList(),
        );
      },
    );
  }

  static pw.Widget _buildQuestion(
    int index,
    Question q,
    PaperTemplate template,
    Paper paper,
    PaperSection section,
    PaperExportConfig config,
    Map<String, pw.ImageProvider> questionImages,
  ) {
    final fontSize = template.questionFontSize * config.fontScale;
    if (q.isWordContentBlock) {
      return pw.Padding(
        padding: pw.EdgeInsets.symmetric(vertical: 5 * config.spacingScale),
        child: _buildQuestionContent(
          q,
          fontSize,
          section,
          config,
          questionImages,
        ),
      );
    }
    final label = PaperStructureService.questionLabel(index, paper, section);
    final answerSpace = QuestionAdvancedStructureService.resolveAnswerSpace(
      q,
      section,
      fallbackLines: config.includesAnswerSpace ? 4 : 0,
    );
    final correctOptions = q.options
        .where((option) => option.isCorrect)
        .map((option) => option.text)
        .join(', ');
    final answer = q.correctAnswer.trim().isNotEmpty
        ? q.correctAnswer.trim()
        : correctOptions;

    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 8 * config.spacingScale),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 34,
                child: pw.Text(
                  '$label.',
                  style: pw.TextStyle(
                    fontSize: fontSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Expanded(
                child: _buildQuestionContent(
                  q,
                  fontSize,
                  section,
                  config,
                  questionImages,
                  inlineMarks:
                      section.questionMarksPlacement ==
                      QuestionMarksPlacement.inline,
                ),
              ),
              if (section.questionMarksPlacement ==
                  QuestionMarksPlacement.rightEdge)
                pw.SizedBox(
                  width: 40,
                  child: pw.Text(
                    '[${PaperStructureService.marksSummary(q.marks)}]',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: fontSize,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (config.includesAnswers)
            pw.Container(
              margin: const pw.EdgeInsets.only(left: 34, top: 7),
              padding: const pw.EdgeInsets.all(7),
              width: double.infinity,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    answer.isEmpty ? 'Answer: Not provided' : 'Answer: $answer',
                    style: pw.TextStyle(
                      fontSize: fontSize,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (config.includesSolutions &&
                      q.explanation.trim().isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Text(
                        'Explanation: ${q.explanation.trim()}',
                        style: pw.TextStyle(fontSize: fontSize),
                      ),
                    ),
                ],
              ),
            ),
          if (!config.includesAnswers && answerSpace.isVisible)
            _buildAnswerArea(answerSpace),
        ],
      ),
    );
  }

  static pw.Widget _buildQuestionContent(
    Question question,
    double fontSize,
    PaperSection section,
    PaperExportConfig config,
    Map<String, pw.ImageProvider> questionImages, {
    bool inlineMarks = false,
  }) {
    final advanced = QuestionAdvancedContent.fromQuestion(question);
    final children = <pw.Widget>[];

    if (question.instructions.trim().isNotEmpty) {
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Text(
            question.instructions.trim(),
            textAlign: _pdfTextAlign(question.instructionAlignment),
            style: pw.TextStyle(
              fontSize: fontSize * 0.9,
              fontStyle: pw.FontStyle.italic,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final questionText = _parseRichTextToPdf(
      question.text,
      fontSize,
      textAlign: _pdfTextAlign(question.alignment),
    );
    final questionTextBlock = inlineMarks
        ? pw.Wrap(
            crossAxisAlignment: pw.WrapCrossAlignment.center,
            spacing: 5,
            children: [
              questionText,
              pw.Text(
                '[${PaperStructureService.marksSummary(question.marks)}]',
                style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          )
        : questionText;
    children.add(
      _buildPdfQuestionTextWithShapes(
        questionTextBlock,
        WordShapeService.shapesOf(question),
        fontSize,
      ),
    );

    if (advanced.hasStimulus) {
      children.add(pw.SizedBox(height: 6));
      children.add(_buildStimulus(advanced.stimulus!, fontSize));
    }

    for (final expression in MathExpression.unplacedInRichText(
      question.text,
      question.mathExpressions,
    )) {
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 5, bottom: 3),
          child: pw.Text(
            expression.plainText.trim().isEmpty
                ? expression.latex
                : expression.plainText,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
      );
    }

    for (final attachment in question.attachments) {
      final image = questionImages[attachment.path];
      if (attachment.kind != QuestionAttachmentKind.image || image == null) {
        continue;
      }
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Image(image, height: 180, fit: pw.BoxFit.contain),
              ),
              if (attachment.caption.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3),
                  child: pw.Text(
                    attachment.caption.trim(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: fontSize * 0.86,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (question.tableData != null) {
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 7),
          child: _buildQuestionTable(question.tableData!, fontSize),
        ),
      );
    }

    if (advanced.hasWordBank) {
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 7),
          child: _buildWordBank(advanced.wordBank, fontSize),
        ),
      );
    }

    if (question.options.isNotEmpty) {
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: _buildOptions(question, fontSize),
        ),
      );
    }

    if (question.type == QuestionType.fillInTheBlanks) {
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            'Ans: ________________________',
            style: pw.TextStyle(fontSize: fontSize),
          ),
        ),
      );
    }

    if (question.subQuestions.isNotEmpty) {
      children.add(pw.SizedBox(height: 7));
      for (final entry in question.subQuestions.asMap().entries) {
        children.add(
          _buildNestedQuestion(
            label: QuestionAdvancedStructureService.partLabel(entry.key),
            question: entry.value,
            fontSize: fontSize,
            section: section,
            config: config,
            questionImages: questionImages,
          ),
        );
      }
    }

    if (question.internalChoices.isNotEmpty) {
      children.add(pw.SizedBox(height: 7));
      for (final entry in question.internalChoices.asMap().entries) {
        if (entry.key > 0) {
          children.add(
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              child: pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'OR',
                  style: pw.TextStyle(
                    fontSize: fontSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }
        children.add(
          _buildNestedQuestion(
            label: '',
            question: entry.value,
            fontSize: fontSize,
            section: section,
            config: config,
            questionImages: questionImages,
          ),
        );
      }
    }

    if (question.isOptional) {
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 3),
          child: pw.Text(
            '(Optional / OR choice)',
            style: pw.TextStyle(
              fontSize: fontSize * 0.84,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: children,
    );
  }

  static pw.Widget _buildPdfQuestionTextWithShapes(
    pw.Widget questionText,
    List<WordShapeObject> shapes,
    double fontSize,
  ) {
    if (shapes.isEmpty) return questionText;
    final ordered = [...shapes]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    WordShapeObject? square;
    for (final shape in ordered) {
      if (shape.wrapMode == WordTextWrapMode.squareLeft ||
          shape.wrapMode == WordTextWrapMode.squareRight) {
        square = shape;
        break;
      }
    }
    final behind = ordered
        .where((shape) => shape.wrapMode == WordTextWrapMode.behindText)
        .toList(growable: false);
    final front = ordered
        .where((shape) => shape.wrapMode == WordTextWrapMode.inFrontOfText)
        .toList(growable: false);
    final flow = ordered
        .where((shape) {
          return shape.wrapMode == WordTextWrapMode.inline ||
              shape.wrapMode == WordTextWrapMode.topAndBottom;
        })
        .toList(growable: false);

    pw.Widget text = questionText;
    if (square != null) {
      final shapeWidget = _buildPdfShape(square, fontSize, compact: true);
      text = pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (square.wrapMode == WordTextWrapMode.squareLeft) ...[
            shapeWidget,
            pw.SizedBox(width: 8),
          ],
          pw.Expanded(child: questionText),
          if (square.wrapMode == WordTextWrapMode.squareRight) ...[
            pw.SizedBox(width: 8),
            shapeWidget,
          ],
        ],
      );
    }

    if (behind.isNotEmpty || front.isNotEmpty) {
      text = pw.Stack(
        children: [
          for (final shape in behind)
            pw.Positioned(
              left: (shape.x * 180).clamp(0, 150).toDouble(),
              top: (shape.y * 55).clamp(0, 45).toDouble(),
              child: _buildPdfShape(shape, fontSize, compact: true),
            ),
          text,
          for (final shape in front)
            pw.Positioned(
              left: (shape.x * 180).clamp(0, 150).toDouble(),
              top: (shape.y * 55).clamp(0, 45).toDouble(),
              child: _buildPdfShape(shape, fontSize, compact: true),
            ),
        ],
      );
    }

    if (flow.isEmpty) return text;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        text,
        pw.SizedBox(height: 5),
        for (final shape in flow)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Align(
              alignment: _pdfShapeAlignment(shape),
              child: _buildPdfShape(shape, fontSize),
            ),
          ),
      ],
    );
  }

  static pw.Alignment _pdfShapeAlignment(WordShapeObject shape) {
    if (shape.x <= 0.25) return pw.Alignment.centerLeft;
    if (shape.x >= 0.65) return pw.Alignment.centerRight;
    return pw.Alignment.center;
  }

  static pw.Widget _buildPdfShape(
    WordShapeObject shape,
    double fontSize, {
    bool compact = false,
  }) {
    final baseWidth = compact ? 105.0 : 180.0;
    final baseHeight = compact ? 48.0 : 86.0;
    final width = (baseWidth * (shape.width / 0.36))
        .clamp(compact ? 54.0 : 72.0, compact ? 135.0 : 220.0)
        .toDouble();
    final height = (baseHeight * (shape.height / 0.30))
        .clamp(18.0, compact ? 70.0 : 120.0)
        .toDouble();
    final border = pw.Border.all(color: PdfColors.black, width: 0.8);

    switch (shape.kind) {
      case WordShapeKind.rectangle:
        return pw.Container(
          width: width,
          height: height,
          decoration: pw.BoxDecoration(border: border),
        );
      case WordShapeKind.roundedRectangle:
        return pw.Container(
          width: width,
          height: height,
          decoration: pw.BoxDecoration(
            border: border,
            borderRadius: pw.BorderRadius.circular(8),
          ),
        );
      case WordShapeKind.ellipse:
        return pw.Container(
          width: width,
          height: height,
          decoration: pw.BoxDecoration(
            border: border,
            borderRadius: pw.BorderRadius.circular(height / 2),
          ),
        );
      case WordShapeKind.line:
        return pw.Container(
          width: width,
          height: 8,
          alignment: pw.Alignment.center,
          child: pw.Container(
            width: width,
            height: 0.8,
            color: PdfColors.black,
          ),
        );
      case WordShapeKind.arrow:
        return _buildPdfArrow(width, fontSize, startHead: false, endHead: true);
      case WordShapeKind.doubleArrow:
        return _buildPdfArrow(width, fontSize, startHead: true, endHead: true);
      case WordShapeKind.textBox:
        return pw.Container(
          width: width,
          height: height,
          padding: const pw.EdgeInsets.all(5),
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(border: border),
          child: pw.Text(
            shape.text,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: fontSize * 0.9),
          ),
        );
      case WordShapeKind.callout:
        return pw.Container(
          width: width,
          height: height,
          padding: const pw.EdgeInsets.all(5),
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: border,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            shape.text,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: fontSize * 0.9),
          ),
        );
    }
  }

  static pw.Widget _buildPdfArrow(
    double width,
    double fontSize, {
    required bool startHead,
    required bool endHead,
  }) {
    return pw.SizedBox(
      width: width,
      height: 18,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (startHead)
            pw.Text('<', style: pw.TextStyle(fontSize: fontSize * 0.9)),
          pw.Expanded(child: pw.Container(height: 0.8, color: PdfColors.black)),
          if (endHead)
            pw.Text('>', style: pw.TextStyle(fontSize: fontSize * 0.9)),
        ],
      ),
    );
  }

  static pw.Widget _buildNestedQuestion({
    required String label,
    required Question question,
    required double fontSize,
    required PaperSection section,
    required PaperExportConfig config,
    required Map<String, pw.ImageProvider> questionImages,
  }) {
    final advanced = QuestionAdvancedContent.fromQuestion(question);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (label.isNotEmpty)
                pw.SizedBox(
                  width: 30,
                  child: pw.Text(
                    label,
                    style: pw.TextStyle(
                      fontSize: fontSize,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              pw.Expanded(
                child: _buildQuestionContent(
                  question,
                  fontSize,
                  section,
                  config,
                  questionImages,
                  inlineMarks:
                      section.questionMarksPlacement ==
                      QuestionMarksPlacement.inline,
                ),
              ),
              if (section.questionMarksPlacement ==
                  QuestionMarksPlacement.rightEdge) ...[
                pw.SizedBox(width: 6),
                pw.Text(
                  '[${PaperStructureService.marksSummary(question.marks)}]',
                  style: pw.TextStyle(
                    fontSize: fontSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          if (advanced.hasAnswerSpace)
            _buildAnswerArea(
              ResolvedQuestionAnswerSpace(
                style: advanced.answerSpace.style,
                lines: advanced.answerSpace.lines,
                questionOverride: true,
              ),
              leftMargin: label.isEmpty ? 0 : 30,
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildStimulus(QuestionStimulus stimulus, double fontSize) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (stimulus.title.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                stimulus.title.trim(),
                style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          pw.Text(
            stimulus.text,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontStyle: stimulus.kind == QuestionStimulusKind.poem
                  ? pw.FontStyle.italic
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildWordBank(List<String> items, double fontSize) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
      ),
      child: pw.Wrap(
        alignment: pw.WrapAlignment.center,
        spacing: 14,
        runSpacing: 4,
        children: items
            .map(
              (item) => pw.Text(item, style: pw.TextStyle(fontSize: fontSize)),
            )
            .toList(),
      ),
    );
  }

  static pw.Widget _buildQuestionTable(QuestionTable table, double fontSize) {
    final columnCount = table.headers.isNotEmpty
        ? table.headers.length
        : (table.rows.isEmpty ? 0 : table.rows.first.length);
    if (columnCount == 0) return pw.SizedBox();

    final rows = <pw.TableRow>[];
    if (table.headers.isNotEmpty) {
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: List.generate(
            columnCount,
            (index) => _pdfTableCell(
              index < table.headers.length ? table.headers[index] : '',
              fontSize,
              bold: true,
            ),
          ),
        ),
      );
    }
    for (final row in table.rows) {
      rows.add(
        pw.TableRow(
          children: List.generate(
            columnCount,
            (index) =>
                _pdfTableCell(index < row.length ? row[index] : '', fontSize),
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (table.caption.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              table.caption.trim(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
          children: rows,
        ),
      ],
    );
  }

  static pw.Widget _pdfTableCell(
    String text,
    double fontSize, {
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }

  static pw.Widget _buildOptions(Question question, double fontSize) {
    final layout = QuestionOptionLayoutCodec.fromQuestion(question);
    final entries = question.options.asMap().entries.toList();

    pw.Widget option(MapEntry<int, QuestionOption> entry) {
      final label = String.fromCharCode(65 + entry.key);
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$label) ', style: pw.TextStyle(fontSize: fontSize)),
          pw.Expanded(
            child: pw.Text(
              entry.value.text,
              style: pw.TextStyle(fontSize: fontSize),
            ),
          ),
        ],
      );
    }

    switch (layout) {
      case QuestionOptionLayout.vertical:
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: entries
              .map(
                (entry) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: option(entry),
                ),
              )
              .toList(),
        );
      case QuestionOptionLayout.inline:
        return pw.Wrap(
          spacing: 14,
          runSpacing: 5,
          children: entries
              .map(
                (entry) => pw.Text(
                  '${String.fromCharCode(65 + entry.key)}) ${entry.value.text}',
                  style: pw.TextStyle(fontSize: fontSize),
                ),
              )
              .toList(),
        );
      case QuestionOptionLayout.twoColumn:
        return pw.LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints?.maxWidth.isFinite == true
                ? constraints!.maxWidth
                : 420.0;
            final itemWidth = (width - 14) / 2;
            return pw.Wrap(
              spacing: 14,
              runSpacing: 5,
              children: entries
                  .map(
                    (entry) =>
                        pw.Container(width: itemWidth, child: option(entry)),
                  )
                  .toList(),
            );
          },
        );
    }
  }

  static Iterable<String> _questionImagePaths(Paper paper) sync* {
    for (final section in paper.sections) {
      for (final question in section.questions) {
        yield* _questionImagePathsForQuestion(question);
      }
    }
  }

  static Iterable<String> _questionImagePathsForQuestion(
    Question question,
  ) sync* {
    for (final attachment in question.attachments) {
      if (attachment.kind == QuestionAttachmentKind.image &&
          attachment.path.trim().isNotEmpty) {
        yield attachment.path;
      }
    }
    for (final child in [
      ...question.subQuestions,
      ...question.internalChoices,
    ]) {
      yield* _questionImagePathsForQuestion(child);
    }
  }

  static pw.Widget _buildCoverPage(
    Paper paper,
    PaperTemplate template,
    PaperExportConfig config,
  ) {
    return pw.Container(
      height: 650,
      alignment: pw.Alignment.center,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            paper.schoolName,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 24 * config.fontScale,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 28),
          pw.Text(
            paper.title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 30 * config.fontScale,
              fontWeight: pw.FontWeight.bold,
              color: config.colourMode == ExportColourMode.grayscale
                  ? PdfColors.black
                  : template.primaryColor,
            ),
          ),
          if (config.outputMode == PaperOutputMode.multipleSet) ...[
            pw.SizedBox(height: 16),
            pw.Text('SET ${config.setLabel.trim().toUpperCase()}'),
          ],
          pw.SizedBox(height: 36),
          pw.Text(PaperDocumentMarks.maximumMarksLabel(paper)),
        ],
      ),
    );
  }

  static pw.Widget _buildAnswerArea(
    ResolvedQuestionAnswerSpace answerSpace, {
    double leftMargin = 34,
  }) {
    final margin = pw.EdgeInsets.only(left: leftMargin, top: 8);
    switch (answerSpace.style) {
      case QuestionAnswerSpaceStyle.graph:
        return pw.Container(
          margin: margin,
          child: pw.Column(
            children: List.generate(
              answerSpace.lines,
              (_) => pw.Row(
                children: List.generate(
                  12,
                  (_) => pw.Expanded(
                    child: pw.Container(
                      height: 14,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.grey400,
                          width: 0.25,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      case QuestionAnswerSpaceStyle.box:
        return pw.Container(
          margin: margin,
          height: answerSpace.lines * 18.0,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
          ),
        );
      case QuestionAnswerSpaceStyle.ruled:
        return pw.Container(
          margin: margin,
          child: pw.Column(
            children: List.generate(
              answerSpace.lines,
              (_) => pw.Container(
                height: 18,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.4),
                  ),
                ),
              ),
            ),
          ),
        );
      case QuestionAnswerSpaceStyle.blank:
        return pw.Container(margin: margin, height: answerSpace.lines * 18.0);
      case QuestionAnswerSpaceStyle.none:
        return pw.SizedBox();
    }
  }

  static pw.Widget _parseRichTextToPdf(
    String text,
    double fontSize, {
    pw.TextAlign textAlign = pw.TextAlign.left,
  }) {
    try {
      final trimmed = text.trimLeft();
      if (trimmed.startsWith('[')) {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          final children = <pw.Widget>[];
          final pending = <Map<String, dynamic>>[];

          void flushText() {
            if (pending.isEmpty) return;
            final converter = QuillDeltaToHtmlConverter(List.of(pending));
            final html = converter.convert();
            final document = html_parser.parse(html);
            final body = document.body;
            if (body != null) {
              children.add(
                pw.RichText(
                  textAlign: textAlign,
                  text: pw.TextSpan(children: _domToTextSpans(body, fontSize)),
                ),
              );
            }
            pending.clear();
          }

          for (final raw in decoded) {
            if (raw is! Map) continue;
            final operation = Map<String, dynamic>.from(raw);
            final insert = operation['insert'];
            if (insert is Map) {
              if (insert.containsKey(MathExpression.quillEmbedKey)) {
                final expression = MathExpression.tryFromQuillEmbedData(
                  insert[MathExpression.quillEmbedKey],
                );
                final plain = expression?.plainText.trim() ?? '';
                operation['insert'] = expression == null
                    ? '[formula]'
                    : (plain.isEmpty ? expression.latex : plain);
              } else if (insert.containsKey('geometry')) {
                flushText();
                children.add(
                  _geometryEmbedToPdf(
                    GeometryEmbedLayout.fromData(insert['geometry']),
                  ),
                );
                continue;
              }
            }
            pending.add(operation);
          }
          flushText();

          if (children.isEmpty) return pw.SizedBox();
          if (children.length == 1) return children.single;
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: children,
          );
        }
      }
    } catch (_) {
      // Fallback to plain text below. Export must never lose the rest of a
      // question merely because one legacy rich-text operation is malformed.
    }
    return pw.Text(
      text,
      textAlign: textAlign,
      style: pw.TextStyle(fontSize: fontSize),
    );
  }

  static pw.Widget _geometryEmbedToPdf(GeometryEmbedLayout rawLayout) {
    final layout = rawLayout.normalized();
    final diagram = layout.diagram;
    if (diagram == null) {
      return pw.Padding(
        padding: pw.EdgeInsets.only(
          top: layout.marginTop,
          bottom: layout.marginBottom,
        ),
        child: pw.Text('[diagram]'),
      );
    }

    // Geometry embeds are canonical block objects in EduSheet. Use a stable
    // printable content width so their relative width/alignment matches Word
    // Mode and Preview while remaining safe across A4/A5/Letter margins.
    const printableReferenceWidth = 420.0;
    final figureWidth = (printableReferenceWidth * layout.widthFactor)
        .clamp(140.0, printableReferenceWidth)
        .toDouble();
    final figureHeight = (layout.height * 0.75).clamp(72.0, 390.0).toDouble();
    final alignment = switch (layout.effectiveAlignmentX) {
      < -0.5 => pw.Alignment.centerLeft,
      > 0.5 => pw.Alignment.centerRight,
      _ => pw.Alignment.center,
    };

    return pw.Padding(
      padding: pw.EdgeInsets.only(
        top: layout.marginTop,
        bottom: layout.marginBottom,
      ),
      child: pw.Align(
        alignment: alignment,
        child: pw.Container(
          width: figureWidth,
          height: figureHeight,
          child: pw.SvgImage(
            svg: GeometrySvgService().toSvg(diagram.copyWith(showGrid: false)),
            width: figureWidth,
            height: figureHeight,
            fit: pw.BoxFit.contain,
          ),
        ),
      ),
    );
  }

  static pw.TextAlign _pdfTextAlign(dynamic alignment) {
    switch (alignment.toString().split('.').last) {
      case 'center':
        return pw.TextAlign.center;
      case 'right':
      case 'end':
        return pw.TextAlign.right;
      case 'justify':
        return pw.TextAlign.justify;
      default:
        return pw.TextAlign.left;
    }
  }

  static List<pw.InlineSpan> _domToTextSpans(dom.Node node, double fontSize) {
    List<pw.InlineSpan> spans = [];

    for (var child in node.nodes) {
      if (child is dom.Text) {
        if (child.text.trim().isNotEmpty) {
          spans.add(
            pw.TextSpan(
              text: child.text,
              style: pw.TextStyle(fontSize: fontSize),
            ),
          );
        }
      } else if (child is dom.Element) {
        pw.TextStyle style = pw.TextStyle(fontSize: fontSize);
        if (child.localName == 'strong' || child.localName == 'b') {
          style = style.copyWith(fontWeight: pw.FontWeight.bold);
        } else if (child.localName == 'em' || child.localName == 'i') {
          style = style.copyWith(fontStyle: pw.FontStyle.italic);
        } else if (child.localName == 'u') {
          style = style.copyWith(decoration: pw.TextDecoration.underline);
        }

        spans.add(
          pw.TextSpan(
            text: child.nodes.isEmpty
                ? (child.text.isNotEmpty ? child.text : null)
                : null,
            style: style,
            children: child.nodes.isNotEmpty
                ? _domToTextSpans(child, fontSize)
                : null,
          ),
        );
      }
    }
    return spans;
  }

  static List<pw.Widget> _buildOmrSheet(
    Paper paper,
    pw.ImageProvider? logoImage,
  ) {
    int totalQuestions = 0;
    for (final section in paper.sections) {
      totalQuestions += PaperStructureService.assessmentQuestionCount(section);
    }

    if (totalQuestions == 0) totalQuestions = 20;

    final config = OmrConfig(
      schoolName: paper.schoolName,
      examName: paper.title,
      questionCount: totalQuestions,
      includeBarcode: true,
      barcodeData: paper.id,
    );

    return [
      pw.NewPage(),
      ...OmrWidgetsBuilder.build(config, logoImage: logoImage),
    ];
  }
}
