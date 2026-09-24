import 'dart:io';
import 'dart:math' as math;

import 'package:edusheet/features/math_keyboard/domain/services/math_production_policy.dart';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/editor/domain/models/question_option_layout.dart';
import 'package:edusheet/features/editor/domain/models/question_math_content.dart';
import 'package:edusheet/features/editor/services/paper_structure_service.dart';
import 'package:edusheet/features/geometry_builder/application/geometry_embed_layout.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_shape.dart';
import 'package:edusheet/features/geometry_builder/services/geometry_svg_service.dart';
import 'package:edusheet/features/omr/domain/models/omr_config.dart';
import 'package:edusheet/features/paper_composer/application/question_advanced_structure_service.dart';
import 'package:edusheet/features/paper_composer/application/question_math_surface_service.dart';
import 'package:edusheet/features/paper_composer/application/question_math_validation_service.dart';
import 'package:edusheet/features/paper_composer/application/question_print_content_projection.dart';
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
import 'package:edusheet/features/pdf/services/shaping/pdf_complex_text_service.dart';
import 'package:edusheet/features/pdf/services/math/pdf_math_typesetter.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import 'package:edusheet/features/math_keyboard/domain/services/math_compatibility_service.dart';


class _PdfGeometryLabel {
  const _PdfGeometryLabel({
    required this.text,
    required this.x,
    required this.y,
    required this.fontSize,
    this.rotation = 0,
    this.bold = false,
  });

  final String text;
  final double x;
  final double y;
  final double fontSize;
  final double rotation;
  final bool bold;
}

class QuestionPaperService {
  static const _mathSurfaceService = QuestionMathSurfaceService();
  static const _mathValidationService = QuestionMathValidationService();
  static const _pdfMathTypesetter = PdfMathTypesetter();
  static Future<pw.ThemeData> _loadTheme({bool requireUnicode = false}) {
    return PdfExportThemeService.loadTheme(requireUnicode: requireUnicode);
  }

  static void preloadTheme() {
    _loadTheme();
  }

  static bool _paperRequiresUnicodeFonts(Paper paper) {
    return paper.toJson().toString().runes.any((rune) => rune > 0x7F);
  }

  static pw.Widget _pdfText(
    String text, {
    double fontSize = 12,
    PdfColor color = PdfColors.black,
    pw.TextAlign textAlign = pw.TextAlign.left,
    pw.FontWeight? fontWeight,
    pw.FontStyle? fontStyle,
    double? lineHeight,
    double? letterSpacing,
    bool underline = false,
    int? maxLines,
  }) {
    return PdfComplexTextService.text(
      text,
      fontSize: fontSize,
      color: color,
      textAlign: textAlign,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      underline: underline,
      maxLines: maxLines,
    );
  }

  static String _operationsPlainText(List<Map<String, dynamic>> operations) {
    final buffer = StringBuffer();
    for (final operation in operations) {
      final insert = operation['insert'];
      if (insert is String) {
        buffer.write(insert);
      }
    }
    return buffer.toString();
  }

  static pw.Widget _complexRichOperationsToPdf(
    List<Map<String, dynamic>> operations,
    double fontSize, {
    required pw.TextAlign textAlign,
  }) {
    final lines = <List<pw.Widget>>[<pw.Widget>[]];

    void addText(String value, Map<dynamic, dynamic>? attributes) {
      if (value.isEmpty) return;
      final bold = attributes?['bold'] == true;
      final italic = attributes?['italic'] == true;
      final underline = attributes?['underline'] == true;
      final parts = value.split('\n');
      for (var partIndex = 0; partIndex < parts.length; partIndex++) {
        final part = parts[partIndex];
        for (final match in RegExp(r'\s+|\S+').allMatches(part)) {
          lines.last.add(
            _pdfText(
              match.group(0)!,
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : null,
              fontStyle: italic ? pw.FontStyle.italic : null,
              underline: underline,
            ),
          );
        }
        if (partIndex < parts.length - 1) {
          lines.add(<pw.Widget>[]);
        }
      }
    }

    for (final operation in operations) {
      final insert = operation['insert'];
      if (insert is! String) continue;
      final rawAttributes = operation['attributes'];
      addText(
        insert,
        rawAttributes is Map ? rawAttributes : null,
      );
    }

    final wrapAlignment = switch (textAlign) {
      pw.TextAlign.center => pw.WrapAlignment.center,
      pw.TextAlign.right || pw.TextAlign.end => pw.WrapAlignment.end,
      _ => pw.WrapAlignment.start,
    };
    final lineWidgets = lines
        .map(
          (line) => line.isEmpty
              ? pw.SizedBox(height: fontSize * 1.2)
              : pw.Wrap(
                  alignment: wrapAlignment,
                  crossAxisAlignment: pw.WrapCrossAlignment.center,
                  children: line,
                ),
        )
        .toList(growable: false);
    if (lineWidgets.isEmpty) return pw.SizedBox();
    if (lineWidgets.length == 1) return lineWidgets.single;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: lineWidgets,
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

  /// Resolves the exact page geometry used by [generateDocument].
  ///
  /// Print preview and the native system print dialog use this so landscape,
  /// A3/A5, Letter, and Legal papers are not initially treated as A4.
  static PdfPageFormat resolvePageFormat(
    Paper paper,
    PaperTemplate template, {
    PaperExportConfig? config,
  }) {
    if (config == null) {
      return _pageFormatForPaper(paper.pageLayout, template.paperSize);
    }

    var format = switch (config.pageSize) {
      ExportPageSize.useTemplate => _getPageFormat(template.paperSize),
      ExportPageSize.a4 => PdfPageFormat.a4,
      ExportPageSize.letter => PdfPageFormat.letter,
    };
    if (config.orientation == ExportOrientation.landscape) {
      format = format.landscape;
    }
    return format;
  }

  static Future<pw.Document> generateDocument(
    Paper inputPaper,
    PaperTemplate template, {
    PaperExportConfig? config,
  }) async {
    final paper = _mathValidationService
        .validateAndRepairPaper(inputPaper)
        .safePaper;
    final usePaperLayout = config == null;
    final exportConfig = config ?? const PaperExportConfig();
    final configErrors = exportConfig.validate();
    if (configErrors.isNotEmpty) {
      throw ArgumentError(configErrors.join(' '));
    }
    final templateStaticText = PaperHeaderLayoutFactory.resolve(template)
        .elements
        .map((element) => element.content)
        .join(' ');
    final complexScriptText = '${paper.toJson()} $templateStaticText';
    if (PdfComplexTextService.containsComplexScript(complexScriptText)) {
      await PdfComplexTextService.ensureInitialized();
    }
    final theme = await _loadTheme(
      requireUnicode: _paperRequiresUnicodeFonts(paper),
    );
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
    final pageFormat = resolvePageFormat(
      paper,
      template,
      config: usePaperLayout ? null : exportConfig,
    );
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
        maxPages: MathProductionLimits.maxGeneratedPdfPages,
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          margin: pageMargins,
          buildBackground: (context) {
            final watermark = paper.pageLayout.watermarkText.trim();
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Stack(
                children: [
                  pw.Positioned(left: 0, top: 0, right: 0, bottom: 0,
                    child: pw.Container(
                      color: _pdfColorWithOpacity(
                        paper.pageLayout.pageBackgroundArgb,
                        1,
                      ),
                    ),
                  ),
                  if (watermark.isNotEmpty)
                    pw.Positioned(left: 0, top: 0, right: 0, bottom: 0,
                      child: pw.Center(
                        child: pw.Transform.rotate(
                          angle: -math.pi / 5,
                          child: _pdfText(
                            watermark,
                            maxLines: 1,
                            fontSize: 54,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 3,
                            color: _pdfColorWithOpacity(
                              0xFF000000,
                              paper.pageLayout.watermarkOpacity,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (template.hasBorder)
                    pw.Positioned(left: 0, top: 0, right: 0, bottom: 0,
                      child: pw.Container(
                        margin: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: template.primaryColor,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
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
            child: _pdfText(
              parts.join('  •  '),
              fontSize: 9 * exportConfig.fontScale,
              textAlign: rightAligned ? pw.TextAlign.right : pw.TextAlign.center,
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
            child: _pdfText(
              parts.join('  •  '),
              fontSize: 9,
              textAlign: pageNumberPosition == PaperPageNumberPosition.footerRight
                  ? pw.TextAlign.right
                  : pw.TextAlign.center,
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
              child: _pdfText(
                paper.instruction.trim(),
                fontSize: template.questionFontSize,
                fontStyle: pw.FontStyle.italic,
                fontWeight: pw.FontWeight.bold,
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

  static int _resolvedColumnCount(Paper paper, PaperTemplate template) {
    return paper.pageLayout.columns.explicitCount ??
        (template.paperLayout == PaperLayout.twoColumn ? 2 : 1);
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

    final columnCount = _resolvedColumnCount(paper, template);
    final isSingleColumn = columnCount == 1;

    if (showHeading &&
        section.keepTogether &&
        entries.isNotEmpty &&
        isSingleColumn &&
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
      final remaining = entries.skip(1).toList(growable: false);
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [...heading, firstQuestion],
            ),
          ),
          ..._buildSingleColumnQuestionWidgets(
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
        if (isSingleColumn)
          ..._buildSingleColumnQuestionWidgets(
            section,
            entries,
            template,
            paper,
            config,
            questionImages,
          )
        else
          _buildQuestionEntries(
            section,
            entries,
            template,
            paper,
            config,
            questionImages,
            columnCount: columnCount,
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
                  child: _pdfText(
                    headingText,
                    textAlign: _pdfTextAlign(section.headingAlignment),
                    fontSize: headingFontSize,
                    fontWeight: section.headingBold
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                    color: template.type == TemplateType.coaching
                        ? template.primaryColor
                        : PdfColors.black,
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
          : _pdfText(
              section.sectionMarksDisplay == SectionMarksDisplay.inline &&
                      marksText != null
                  ? '$headingText ($marksText)'
                  : headingText,
              textAlign: _pdfTextAlign(section.headingAlignment),
              fontSize: headingFontSize,
              fontWeight: section.headingBold
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
              color: template.type == TemplateType.coaching
                  ? template.primaryColor
                  : PdfColors.black,
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
          child: _pdfText(
            '${section.showInstructionLabel ? 'Instruction: ' : ''}${section.instruction}',
            textAlign: _pdfTextAlign(section.instructionAlignment),
            fontStyle: pw.FontStyle.italic,
            fontSize: 12 * config.fontScale,
          ),
        ),
      if (answerRule != null)
        pw.Padding(
          padding: pw.EdgeInsets.only(
            bottom: paper.pageLayout.paragraphSpacingPoints
                .clamp(2, 18)
                .toDouble(),
          ),
          child: _pdfText(
            answerRule,
            textAlign: _pdfTextAlign(section.answerRuleAlignment),
            fontSize: 11 * config.fontScale,
            fontWeight: pw.FontWeight.bold,
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

  static List<pw.Widget> _buildSingleColumnQuestionWidgets(
    PaperSection section,
    List<MapEntry<int, Question>> entries,
    PaperTemplate template,
    Paper paper,
    PaperExportConfig config,
    Map<String, pw.ImageProvider> questionImages,
  ) => entries
      .map(
        (entry) => _buildQuestion(
          PaperStructureService.numberedQuestionOrdinal(section, entry.key),
          entry.value,
          template,
          paper,
          section,
          config,
          questionImages,
        ),
      )
      .toList(growable: false);

  static pw.Widget _buildQuestionEntries(
    PaperSection section,
    List<MapEntry<int, Question>> entries,
    PaperTemplate template,
    Paper paper,
    PaperExportConfig config,
    Map<String, pw.ImageProvider> questionImages, {
    required int columnCount,
  }) {
    final questions = _buildSingleColumnQuestionWidgets(
      section,
      entries,
      template,
      paper,
      config,
      questionImages,
    );

    return pw.LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints?.maxWidth.isFinite == true
            ? constraints!.maxWidth
            : CustomLayout.designWidth;
        final gap = paper.pageLayout.columnSpacingPoints.clamp(0, 72).toDouble();
        final safeCount = columnCount.clamp(1, 3);
        final columnWidth =
            (contentWidth - gap * (safeCount - 1)) / safeCount;

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
                  if (q.correctAnswer.trim().isNotEmpty)
                    pw.Wrap(
                      crossAxisAlignment: pw.WrapCrossAlignment.center,
                      children: [
                        pw.Text(
                          'Answer: ',
                          style: pw.TextStyle(
                            fontSize: fontSize,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        _mathSurfacePdf(
                          q,
                          QuestionMathSurfaceKey.correctAnswer,
                          q.correctAnswer,
                          fontSize: fontSize,
                          bold: true,
                        ),
                      ],
                    )
                  else
                    _pdfText(
                      answer.isEmpty
                          ? 'Answer: Not provided'
                          : 'Answer: $answer',
                      fontSize: fontSize,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  if (config.includesSolutions &&
                      q.explanation.trim().isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Wrap(
                        crossAxisAlignment: pw.WrapCrossAlignment.center,
                        children: [
                          pw.Text(
                            'Explanation: ',
                            style: pw.TextStyle(fontSize: fontSize),
                          ),
                          _mathSurfacePdf(
                            q,
                            QuestionMathSurfaceKey.explanation,
                            q.explanation,
                            fontSize: fontSize,
                          ),
                        ],
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
    int nestedDepth = 0,
  }) {
    final advanced = QuestionAdvancedContent.fromQuestion(question);
    final children = <pw.Widget>[];

    if (question.instructions.trim().isNotEmpty) {
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: _mathSurfacePdf(
            question,
            QuestionMathSurfaceKey.instructions,
            question.instructions,
            fontSize: fontSize * 0.9,
            textAlign: _pdfTextAlign(question.instructionAlignment),
            italic: true,
            bold: true,
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
      children.add(_buildStimulus(question, advanced.stimulus!, fontSize));
    }

    for (final expression in _unplacedExportMath(question)) {
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 5, bottom: 3),
          child: _mathExpressionPdf(expression, fontSize: fontSize),
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
                  child: _mathSurfacePdf(
                    question,
                    QuestionMathSurfaceKey.attachmentCaption(attachment.id),
                    attachment.caption,
                    fontSize: fontSize * 0.86,
                    textAlign: pw.TextAlign.center,
                    italic: true,
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
          child: _buildQuestionTable(question, question.tableData!, fontSize),
        ),
      );
    }

    if (advanced.hasWordBank) {
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 7),
          child: _buildWordBank(question, advanced.wordBank, fontSize),
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

    if ((question.subQuestions.isNotEmpty ||
            question.internalChoices.isNotEmpty) &&
        nestedDepth >= MathProductionLimits.maxQuestionNestingDepth) {
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 7),
          child: pw.Text(
            '[Nested question depth limit reached]',
            style: pw.TextStyle(fontSize: fontSize * 0.85),
          ),
        ),
      );
    } else {
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
              nestedDepth: nestedDepth + 1,
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
              nestedDepth: nestedDepth + 1,
            ),
          );
        }
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
    final strokeColor = PdfColor.fromInt(shape.strokeColorArgb);
    final fillColor = shape.fillOpacity > 0
        ? _pdfColorWithOpacity(shape.fillColorArgb, shape.fillOpacity)
        : null;
    final border = shape.borderVisible
        ? pw.Border.all(
            color: strokeColor,
            width: (shape.strokeWidth * 0.5).clamp(0.2, 4).toDouble(),
          )
        : null;
    final decoration = pw.BoxDecoration(border: border, color: fillColor);

    switch (shape.kind) {
      case WordShapeKind.rectangle:
        return pw.Container(
          width: width,
          height: height,
          decoration: decoration,
        );
      case WordShapeKind.roundedRectangle:
        return pw.Container(
          width: width,
          height: height,
          decoration: pw.BoxDecoration(
            border: border,
            color: fillColor,
            borderRadius: pw.BorderRadius.circular(8),
          ),
        );
      case WordShapeKind.ellipse:
        return pw.Container(
          width: width,
          height: height,
          decoration: pw.BoxDecoration(
            border: border,
            color: fillColor,
            borderRadius: pw.BorderRadius.circular(height / 2),
          ),
        );
      case WordShapeKind.line:
        return pw.Container(
          width: width,
          height: 8,
          alignment: pw.Alignment.center,
          child: shape.borderVisible
              ? pw.Container(
                  width: width,
                  height: math.max(0.4, shape.strokeWidth * 0.5),
                  color: strokeColor,
                )
              : pw.SizedBox(),
        );
      case WordShapeKind.arrow:
        return _buildPdfArrow(
          width,
          fontSize,
          color: strokeColor,
          visible: shape.borderVisible,
          startHead: false,
          endHead: true,
        );
      case WordShapeKind.doubleArrow:
        return _buildPdfArrow(
          width,
          fontSize,
          color: strokeColor,
          visible: shape.borderVisible,
          startHead: true,
          endHead: true,
        );
      case WordShapeKind.textBox:
        return pw.Container(
          width: width,
          height: height,
          padding: pw.EdgeInsets.all(shape.padding.clamp(0, 32).toDouble()),
          alignment: pw.Alignment.center,
          decoration: decoration,
          child: _pdfText(
            shape.text,
            textAlign: pw.TextAlign.center,
            fontSize: fontSize * 0.9,
          ),
        );
      case WordShapeKind.callout:
        return pw.Container(
          width: width,
          height: height,
          padding: pw.EdgeInsets.all(shape.padding.clamp(0, 32).toDouble()),
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: border,
            color: fillColor,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: _pdfText(
            shape.text,
            textAlign: pw.TextAlign.center,
            fontSize: fontSize * 0.9,
          ),
        );
      case WordShapeKind.geometry:
        final diagram = shape.geometryDiagram;
        if (diagram == null) {
          return pw.Container(
            width: width,
            height: height,
            decoration: decoration,
            alignment: pw.Alignment.center,
            child: pw.Text('[diagram]'),
          );
        }
        final inset = shape.padding.clamp(0, 32).toDouble();
        final innerWidth = math.max(1.0, width - inset * 2);
        final innerHeight = math.max(1.0, height - inset * 2);
        return pw.Container(
          width: width,
          height: height,
          padding: pw.EdgeInsets.all(inset),
          decoration: decoration,
          child: _geometryDiagramPdf(
            diagram.copyWith(showGrid: false),
            width: innerWidth,
            height: innerHeight,
          ),
        );
    }
  }

  /// Renders geometry vectors without SVG text, then overlays every label with
  /// normal PDF text. The PDF package otherwise resolves SVG `font-family`
  /// through its built-in Helvetica face, which is not Unicode-safe and emits
  /// warnings for Indic/math labels. Overlay text inherits the document's
  /// Unicode-capable [pw.ThemeData], keeping geometry labels on the same font
  /// path as question text.
  static pw.Widget _geometryDiagramPdf(
    GeometryDiagram diagram, {
    required double width,
    required double height,
  }) {
    final canvasWidth = math.max(1.0, diagram.canvasSize.width);
    final canvasHeight = math.max(1.0, diagram.canvasSize.height);
    final scale = math.min(width / canvasWidth, height / canvasHeight);
    final renderedWidth = canvasWidth * scale;
    final renderedHeight = canvasHeight * scale;
    final offsetX = (width - renderedWidth) / 2;
    final offsetY = (height - renderedHeight) / 2;
    final labels = _geometryPdfLabels(diagram);

    return pw.SizedBox(
      width: width,
      height: height,
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: offsetX,
            top: offsetY,
            child: pw.SvgImage(
              svg: GeometrySvgService().toSvg(
                diagram,
                includeText: false,
              ),
              width: renderedWidth,
              height: renderedHeight,
              fit: pw.BoxFit.fill,
            ),
          ),
          for (final label in labels)
            pw.Positioned(
              left: offsetX + label.x * scale,
              top: math.max(
                0.0,
                offsetY + label.y * scale - label.fontSize * scale * 0.82,
              ),
              child: pw.Transform.rotate(
                angle: label.rotation,
                child: _pdfText(
                  label.text,
                  fontSize: (label.fontSize * scale).clamp(6.0, 36.0),
                  fontWeight: label.bold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static List<_PdfGeometryLabel> _geometryPdfLabels(GeometryDiagram diagram) {
    final labels = <_PdfGeometryLabel>[];
    for (final point in diagram.points) {
      final text = point.label.trim();
      if (text.isEmpty) continue;
      final position = point.labelPosition;
      labels.add(
        _PdfGeometryLabel(
          text: text,
          x: position.dx,
          y: position.dy,
          fontSize: point.labelFontSize,
          rotation: point.labelRotation,
          bold: point.labelBold,
        ),
      );
    }
    for (final label in diagram.labels) {
      final text = label.text.trim();
      if (text.isEmpty) continue;
      labels.add(
        _PdfGeometryLabel(
          text: text,
          x: label.position.dx,
          y: label.position.dy,
          fontSize: label.fontSize,
          rotation: label.rotation,
          bold: label.isBold,
        ),
      );
    }

    final pointMap = diagram.pointMap;
    for (final shape in diagram.shapes) {
      if (shape.type != GeometryShapeType.coordinateAxes ||
          shape.pointIds.length < 4) {
        continue;
      }
      final yEnd = pointMap[shape.pointIds[0]]?.position;
      final xEnd = pointMap[shape.pointIds[3]]?.position;
      if (xEnd != null) {
        labels.add(
          _PdfGeometryLabel(
            text: 'x',
            x: xEnd.dx + 8,
            y: xEnd.dy - 8,
            fontSize: 12,
          ),
        );
      }
      if (yEnd != null) {
        labels.add(
          _PdfGeometryLabel(
            text: 'y',
            x: yEnd.dx + 8,
            y: yEnd.dy + 12,
            fontSize: 12,
          ),
        );
      }
    }
    return labels;
  }

  static PdfColor _pdfColorWithOpacity(int argb, double opacity) {
    final red = ((argb >> 16) & 0xFF) / 255.0;
    final green = ((argb >> 8) & 0xFF) / 255.0;
    final blue = (argb & 0xFF) / 255.0;
    return PdfColor(red, green, blue, opacity.clamp(0.0, 1.0).toDouble());
  }

  static pw.Widget _buildPdfArrow(
    double width,
    double fontSize, {
    required PdfColor color,
    required bool visible,
    required bool startHead,
    required bool endHead,
  }) {
    if (!visible) return pw.SizedBox(width: width, height: 18);
    return pw.SizedBox(
      width: width,
      height: 18,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (startHead)
            pw.Text(
              '<',
              style: pw.TextStyle(fontSize: fontSize * 0.9, color: color),
            ),
          pw.Expanded(child: pw.Container(height: 0.8, color: color)),
          if (endHead)
            pw.Text(
              '>',
              style: pw.TextStyle(fontSize: fontSize * 0.9, color: color),
            ),
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
    required int nestedDepth,
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
                  nestedDepth: nestedDepth,
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

  static pw.Widget _buildStimulus(
    Question question,
    QuestionStimulus stimulus,
    double fontSize,
  ) {
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
              child: _mathSurfacePdf(
                question,
                QuestionMathSurfaceKey.stimulusTitle,
                stimulus.title,
                fontSize: fontSize,
                bold: true,
              ),
            ),
          _mathSurfacePdf(
            question,
            QuestionMathSurfaceKey.stimulusText,
            stimulus.text,
            fontSize: fontSize,
            italic: stimulus.kind == QuestionStimulusKind.poem,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildWordBank(
    Question question,
    List<String> items,
    double fontSize,
  ) {
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
            .asMap()
            .entries
            .map(
              (entry) => _mathSurfacePdf(
                question,
                QuestionMathSurfaceKey.wordBank(entry.key),
                entry.value,
                fontSize: fontSize,
              ),
            )
            .toList(),
      ),
    );
  }

  static pw.Widget _buildQuestionTable(
    Question question,
    QuestionTable table,
    double fontSize,
  ) {
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
              question,
              QuestionMathSurfaceKey.tableHeader(index),
              index < table.headers.length ? table.headers[index] : '',
              fontSize,
              bold: true,
            ),
          ),
        ),
      );
    }
    for (final rowEntry in table.rows.asMap().entries) {
      final row = rowEntry.value;
      rows.add(
        pw.TableRow(
          children: List.generate(
            columnCount,
            (index) => _pdfTableCell(
              question,
              QuestionMathSurfaceKey.tableCell(rowEntry.key, index),
              index < row.length ? row[index] : '',
              fontSize,
            ),
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
            child: _mathSurfacePdf(
              question,
              QuestionMathSurfaceKey.tableCaption,
              table.caption,
              fontSize: fontSize,
              textAlign: pw.TextAlign.center,
              bold: true,
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
    Question question,
    String surfaceKey,
    String text,
    double fontSize, {
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: _mathSurfacePdf(
        question,
        surfaceKey,
        text,
        fontSize: fontSize,
        bold: bold,
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
            child: _mathSurfacePdf(
              question,
              QuestionMathSurfaceKey.option(entry.value.id),
              entry.value.text,
              fontSize: fontSize,
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
                (entry) => _pdfText(
                  '${String.fromCharCode(65 + entry.key)}) ${entry.value.text}',
                  fontSize: fontSize,
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
          _pdfText(
            paper.schoolName,
            textAlign: pw.TextAlign.center,
            fontSize: 24 * config.fontScale,
            fontWeight: pw.FontWeight.bold,
          ),
          pw.SizedBox(height: 28),
          _pdfText(
            paper.title,
            textAlign: pw.TextAlign.center,
            fontSize: 30 * config.fontScale,
            fontWeight: pw.FontWeight.bold,
            color: config.colourMode == ExportColourMode.grayscale
                ? PdfColors.black
                : template.primaryColor,
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

  static List<MathExpression> _unplacedExportMath(Question question) {
    final surfaceExpressions = _mathSurfaceService
        .activeContentForQuestion(question)
        .expressions;
    final surfaceIdentities = surfaceExpressions
        .map(_mathExpressionIdentity)
        .toSet();
    return MathExpression.unplacedInRichText(
          question.text,
          question.mathExpressions,
        )
        .where((expression) {
          return !surfaceIdentities.contains(
            _mathExpressionIdentity(expression),
          );
        })
        .toList(growable: false);
  }

  static String _mathExpressionIdentity(MathExpression expression) {
    return expression.id.isNotEmpty
        ? 'id:${expression.id}'
        : 'source:${expression.latex}\u0000${expression.plainText}';
  }

  static pw.Widget _mathExpressionPdf(
    MathExpression expression, {
    required double fontSize,
  }) {
    final native = _pdfMathTypesetter.buildSource(
      expression.latex,
      fontSize: fontSize,
    );
    if (native != null) return native;
    final fallback = const MathCompatibilityService()
        .inspectSource(expression.latex, plainFallback: expression.plainText)
        .readableFallback;
    return pw.Text(
      fallback,
      style: pw.TextStyle(fontSize: fontSize, fontStyle: pw.FontStyle.italic),
    );
  }

  static pw.Widget _mathSurfacePdf(
    Question question,
    String surfaceKey,
    String fallbackText, {
    required double fontSize,
    pw.TextAlign textAlign = pw.TextAlign.left,
    bool bold = false,
    bool italic = false,
  }) {
    final document = _mathSurfaceService.activeDocument(
      question,
      surfaceKey,
      fallbackText,
    );
    if (document == null) {
      return _pdfText(
        fallbackText,
        textAlign: textAlign,
        fontSize: fontSize,
        fontWeight: bold ? pw.FontWeight.bold : null,
        fontStyle: italic ? pw.FontStyle.italic : null,
      );
    }
    return pw.Wrap(
      alignment: switch (textAlign) {
        pw.TextAlign.center => pw.WrapAlignment.center,
        pw.TextAlign.right => pw.WrapAlignment.end,
        _ => pw.WrapAlignment.start,
      },
      crossAxisAlignment: pw.WrapCrossAlignment.center,
      children: document.parts
          .map((part) {
            if (part.kind == QuestionMathInlinePartKind.text ||
                part.expression == null) {
              return _pdfText(
                part.text,
                fontSize: fontSize,
                fontWeight: bold ? pw.FontWeight.bold : null,
                fontStyle: italic ? pw.FontStyle.italic : null,
              );
            }
            return _mathExpressionPdf(part.expression!, fontSize: fontSize);
          })
          .toList(growable: false),
    );
  }

  static pw.Widget _parseRichTextToPdf(
    String text,
    double fontSize, {
    pw.TextAlign textAlign = pw.TextAlign.left,
  }) {
    final projection = QuestionPrintContentProjection.fromRichText(text);
    if (projection.isStructuredRichText) {
      try {
        final children = <pw.Widget>[];
        var hasBlockEmbed = false;

        for (final object in projection.objects) {
          switch (object.kind) {
            case QuestionPrintContentKind.richText:
              if (object.operations.isEmpty) continue;
              final plainText = _operationsPlainText(object.operations);
              if (PdfComplexTextService.containsComplexScript(plainText)) {
                children.add(
                  _complexRichOperationsToPdf(
                    object.operations,
                    fontSize,
                    textAlign: textAlign,
                  ),
                );
                break;
              }
              final converter = QuillDeltaToHtmlConverter(object.operations);
              final html = converter.convert();
              final document = html_parser.parse(html);
              final body = document.body;
              if (body != null) {
                children.add(
                  pw.RichText(
                    textAlign: textAlign,
                    text: pw.TextSpan(
                      children: _domToTextSpans(body, fontSize),
                    ),
                  ),
                );
              }
              break;
            case QuestionPrintContentKind.mathExpression:
              final expression = object.mathExpression;
              if (expression != null) {
                children.add(
                  _mathExpressionPdf(expression, fontSize: fontSize),
                );
              }
              break;
            case QuestionPrintContentKind.geometry:
              final layout = object.geometryLayout;
              if (layout != null) {
                hasBlockEmbed = true;
                children.add(_geometryEmbedToPdf(layout));
              }
              break;
          }
        }

        if (children.isEmpty) return pw.SizedBox();
        if (children.length == 1) return children.single;
        if (!hasBlockEmbed) {
          return pw.Wrap(
            crossAxisAlignment: pw.WrapCrossAlignment.center,
            children: children,
          );
        }
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: children,
        );
      } catch (_) {
        // Export must never lose a question because one legacy rich-text
        // operation is malformed. Fall back to plain text below.
      }
    }
    return _pdfText(
      text,
      textAlign: textAlign,
      fontSize: fontSize,
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
          child: _geometryDiagramPdf(
            diagram.copyWith(showGrid: false),
            width: figureWidth,
            height: figureHeight,
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
