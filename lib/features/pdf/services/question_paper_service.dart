import 'dart:convert';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/question_numbering_service.dart';
import 'package:edusheet/features/pdf/application/paper_header_layout_factory.dart';
import 'package:edusheet/features/pdf/application/paper_marks_resolver.dart';
import 'package:edusheet/features/pdf/domain/models/paper_export_config.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/services/builders/header_builders.dart';
import 'package:edusheet/features/omr/domain/models/omr_config.dart';
import 'package:edusheet/features/omr/services/omr_widgets_builder.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

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

  static Future<pw.Document> generateDocument(
    Paper paper,
    PaperTemplate template, {
    PaperExportConfig config = const PaperExportConfig(),
  }) async {
    final configErrors = config.validate();
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

    final headerBuilder = CustomHeaderBuilder();
    var pageFormat = switch (config.pageSize) {
      ExportPageSize.useTemplate => _getPageFormat(template.paperSize),
      ExportPageSize.a4 => PdfPageFormat.a4,
      ExportPageSize.letter => PdfPageFormat.letter,
    };
    if (config.orientation == ExportOrientation.landscape) {
      pageFormat = pageFormat.landscape;
    }
    final horizontalMargin = config.marginPoints +
        (config.booklet.enabled ? config.booklet.gutterPoints / 2 : 0);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: config.marginPoints,
          ),
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
          if (paper.headerText.trim().isEmpty || context.pageNumber == 1) {
            return pw.SizedBox();
          }
          return pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.only(bottom: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
            ),
            child: pw.Text(
              paper.headerText.trim(),
              style: pw.TextStyle(fontSize: 9 * config.fontScale),
            ),
          );
        },
        footer: (context) {
          final parts = <String>[];
          if (paper.footerText.trim().isNotEmpty) {
            parts.add(paper.footerText.trim());
          }
          if (paper.showPageNumbers) {
            parts.add('Page ${context.pageNumber} of ${context.pagesCount}');
          }
          if (parts.isEmpty) return pw.SizedBox();
          return pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Text(
              parts.join('  •  '),
              style: const pw.TextStyle(fontSize: 9),
            ),
          );
        },
        build: (context) => [
          if (paper.includeCoverPage) ...[
            _buildCoverPage(paper, template, config),
            pw.NewPage(),
          ],
          headerBuilder.build(
            paper,
            logos,
            template,
            customImages: customImages,
          ),
          if (config.outputMode == PaperOutputMode.multipleSet)
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                'SET ${config.setLabel.trim().toUpperCase()}',
                style: pw.TextStyle(
                  fontSize: 16 * config.fontScale,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          if (config.includesAnswers)
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                config.includesSolutions
                    ? 'TEACHER SOLUTION COPY'
                    : 'ANSWER KEY',
                style: pw.TextStyle(
                  fontSize: 13 * config.fontScale,
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
              _buildSection(section, template, paper, config),
            ],
          ),
          if (paper.includeOmr)
            ..._buildOmrSheet(paper, logos.isNotEmpty ? logos.first : null),
        ],
      ),
    );

    return pdf;
  }

  static pw.Widget _buildSection(
    PaperSection section,
    PaperTemplate template,
    Paper paper,
    PaperExportConfig config,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 20 * config.spacingScale),
        if (section.showTitle || section.prefix.isNotEmpty)
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
        if (section.instruction != null && section.instruction!.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              'Instruction: ${section.instruction}',
              style: pw.TextStyle(
                fontStyle: pw.FontStyle.italic,
                fontSize: 12 * config.fontScale,
              ),
            ),
          ),
        if (section.showDivider) pw.Divider(),
        _buildQuestionList(section, template, paper, config),
      ],
    );
  }

  static pw.Widget _buildQuestionList(
    PaperSection section,
    PaperTemplate template,
    Paper paper,
    PaperExportConfig config,
  ) {
    final questions = section.questions.asMap().entries.map((entry) {
      return _buildQuestion(
        entry.key + 1,
        entry.value,
        template,
        paper,
        section,
        config,
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
  ) {
    final label = QuestionNumberingService.paperLabel(index, paper);
    final fontSize = template.questionFontSize * config.fontScale;
    final requestedAnswerLines = section.answerSpaceLines > 0
        ? section.answerSpaceLines
        : (config.includesAnswerSpace ? 4 : 0);
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
                child: _parseRichTextToPdf(
                  q.text,
                  fontSize,
                  textAlign: _pdfTextAlign(q.alignment),
                ),
              ),
              pw.SizedBox(
                width: 40,
                child: pw.Text(
                  '[${q.marks}]',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: fontSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          for (final expression in MathExpression.unplacedInRichText(q.text, q.mathExpressions))
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 34, top: 5, bottom: 3),
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
          if (q.type.usesOptions)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 34, top: 4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: q.options.asMap().entries.map((optEntry) {
                  final optIdx = String.fromCharCode(65 + optEntry.key);
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '$optIdx) ',
                          style: pw.TextStyle(
                            fontSize: fontSize,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            optEntry.value.text,
                            style: pw.TextStyle(
                              fontSize: fontSize,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          if (q.type == QuestionType.fillInTheBlanks)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 34, top: 4),
              child: pw.Text(
                'Ans: ________________________',
                style: pw.TextStyle(fontSize: fontSize),
              ),
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
          if (!config.includesAnswers && requestedAnswerLines > 0)
            _buildAnswerArea(
              requestedAnswerLines,
              ruled: section.ruledAnswerArea || !section.graphAnswerArea,
              graph: section.graphAnswerArea,
            ),
        ],
      ),
    );
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
          pw.Text(
            'Maximum marks: ${PaperMarksResolver.format(PaperMarksResolver.effectiveMaximumMarks(paper))}',
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildAnswerArea(
    int lines, {
    required bool ruled,
    required bool graph,
  }) {
    final lineHeight = graph ? 14.0 : 18.0;
    return pw.Container(
      margin: const pw.EdgeInsets.only(left: 34, top: 8),
      child: pw.Column(
        children: List.generate(
          lines,
          (_) => pw.Container(
            height: lineHeight,
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: ruled || graph ? PdfColors.grey500 : PdfColors.white,
                  width: 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    for (var section in paper.sections) {
      totalQuestions += section.questions.length;
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
