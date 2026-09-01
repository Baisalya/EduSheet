import 'dart:convert';
import 'dart:io';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/editor/domain/models/question_option_layout.dart';
import 'package:edusheet/features/editor/services/paper_structure_service.dart';
import 'package:edusheet/features/omr/domain/models/omr_config.dart';
import 'package:edusheet/features/paper_composer/application/question_advanced_structure_service.dart';
import 'package:edusheet/features/paper_composer/application/word_content_block_service.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/omr/services/omr_widgets_builder.dart';
import 'package:edusheet/features/pdf/application/paper_document_marks.dart';
import 'package:edusheet/features/pdf/application/paper_header_layout_factory.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_export_config.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/services/builders/header_builders.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

class QuestionPaperService {
  static Future<pw.ThemeData>? _themeFuture;

  static Future<pw.ThemeData> _loadTheme() async {
    final cachedTheme = _themeFuture;
    if (cachedTheme != null) return cachedTheme;

    _themeFuture = _buildTheme();
    return _themeFuture!;
  }

  static void preloadTheme() {
    _loadTheme();
  }

  static Future<pw.ThemeData> _buildTheme() async {
    final fonts = await Future.wait([
      PdfGoogleFonts.notoSansRegular(),
      PdfGoogleFonts.notoSansMathRegular(),
      PdfGoogleFonts.notoSansSymbols2Regular(),
      PdfGoogleFonts.notoSansDevanagariRegular(),
      PdfGoogleFonts.notoSansOriyaRegular(),
      PdfGoogleFonts.notoSansBengaliRegular(),
      PdfGoogleFonts.notoSansTamilRegular(),
      PdfGoogleFonts.notoSansTeluguRegular(),
      PdfGoogleFonts.notoSansKannadaRegular(),
      PdfGoogleFonts.notoSansGujaratiRegular(),
      PdfGoogleFonts.notoSansMalayalamRegular(),
      PdfGoogleFonts.notoSansGurmukhiRegular(),
      PdfGoogleFonts.notoSansArabicRegular(),
      PdfGoogleFonts.notoSansJPRegular(),
    ]);

    return pw.ThemeData.withFont(
      base: fonts[0],
      fontFallback: fonts.sublist(1),
    );
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
                textAlign: pw.TextAlign.center,
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
    final answerRule = PaperStructureService.answerRuleText(section);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: (showHeading ? 20 : 8) * config.spacingScale),
        if (showHeading && (section.showTitle || section.prefix.isNotEmpty))
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: template.type == TemplateType.coaching
                ? pw.BoxDecoration(color: template.secondaryColor)
                : null,
            child: pw.Text(
              '${section.prefix} ${section.showTitle ? section.title : ""}'
                  .trim(),
              style: pw.TextStyle(
                fontSize: 18 * config.fontScale,
                fontWeight: pw.FontWeight.bold,
                color: template.type == TemplateType.coaching
                    ? template.primaryColor
                    : PdfColors.black,
              ),
            ),
          ),
        if (showHeading &&
            section.instruction != null &&
            section.instruction!.isNotEmpty)
          pw.Padding(
            padding: pw.EdgeInsets.only(
              bottom: paper.pageLayout.paragraphSpacingPoints
                  .clamp(2, 18)
                  .toDouble(),
            ),
            child: pw.Text(
              'Instruction: ${section.instruction}',
              style: pw.TextStyle(
                fontStyle: pw.FontStyle.italic,
                fontSize: 12 * config.fontScale,
              ),
            ),
          ),
        if (showHeading && answerRule != null)
          pw.Padding(
            padding: pw.EdgeInsets.only(
              bottom: paper.pageLayout.paragraphSpacingPoints
                  .clamp(2, 18)
                  .toDouble(),
            ),
            child: pw.Text(
              answerRule,
              style: pw.TextStyle(
                fontSize: 11 * config.fontScale,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        if (showHeading && section.showDivider) pw.Divider(),
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
                ),
              ),
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
    Map<String, pw.ImageProvider> questionImages,
  ) {
    final advanced = QuestionAdvancedContent.fromQuestion(question);
    final children = <pw.Widget>[];

    children.add(
      _parseRichTextToPdf(
        question.text,
        fontSize,
        textAlign: _pdfTextAlign(question.alignment),
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
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                '[${PaperStructureService.marksSummary(question.marks)}]',
                style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
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
      if (text.startsWith('[') || text.startsWith('{')) {
        final List<dynamic> deltaJson = jsonDecode(text);
        final normalizedDelta = deltaJson.map((raw) {
          if (raw is! Map) return <String, dynamic>{};
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
              operation['insert'] = '[diagram]';
            }
          }
          return operation;
        }).toList();
        final converter = QuillDeltaToHtmlConverter(normalizedDelta);
        final html = converter.convert();
        final document = html_parser.parse(html);
        return pw.RichText(
          textAlign: textAlign,
          text: pw.TextSpan(
            children: _domToTextSpans(document.body!, fontSize),
          ),
        );
      }
    } catch (e) {
      // Fallback to plain text
    }
    return pw.Text(
      text,
      textAlign: textAlign,
      style: pw.TextStyle(fontSize: fontSize),
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
