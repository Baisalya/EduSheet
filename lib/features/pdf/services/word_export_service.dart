import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/editor/domain/models/question_option_layout.dart';
import 'package:edusheet/features/editor/services/paper_structure_service.dart';
import 'package:edusheet/features/pdf/application/paper_header_layout_factory.dart';
import 'package:edusheet/features/paper_composer/application/question_advanced_structure_service.dart';
import 'package:edusheet/features/paper_composer/application/smart_paper_docx_round_trip_service.dart';
import 'package:edusheet/features/paper_composer/application/word_content_block_service.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/pdf/application/paper_document_marks.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/services/export_file_service.dart';
import 'package:edusheet/features/pdf/services/office_text_formatter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

class WordExportService {
  static const _wordNamespace =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  static const _relationsNamespace =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  static Future<File> exportAndOpen(Paper paper, PaperTemplate template) async {
    final file = await export(paper, template);
    await OpenFilex.open(file.path);
    return file;
  }

  static Future<File> export(
    Paper paper,
    PaperTemplate template, {
    String? fileNameBase,
  }) async {
    final file = await ExportFileService.uniqueFile(
      fileNameBase: fileNameBase ?? paper.title,
      extension: '.docx',
    );
    final package = await _buildPackage(paper, template);
    await file.writeAsBytes(package, flush: true);
    return file;
  }

  static Future<List<int>> _buildPackage(
    Paper paper,
    PaperTemplate template,
  ) async {
    final archive = Archive();
    final imageParts = await _readImageParts(paper);

    void addString(String name, String content) {
      archive.addFile(ArchiveFile.string(name, content));
    }

    final relationshipBase = imageParts.length + 1;
    final hasHeader =
        paper.headerText.trim().isNotEmpty ||
        (paper.showPageNumbers &&
            paper.pageLayout.pageNumberPosition ==
                PaperPageNumberPosition.headerRight);
    final hasFooter =
        paper.footerText.trim().isNotEmpty ||
        (paper.showPageNumbers &&
            paper.pageLayout.pageNumberPosition !=
                PaperPageNumberPosition.headerRight);
    final headerRelId = hasHeader ? 'rId$relationshipBase' : null;
    final footerRelId = hasFooter
        ? 'rId${relationshipBase + (hasHeader ? 1 : 0)}'
        : null;
    final stylesRelId =
        'rId${relationshipBase + (hasHeader ? 1 : 0) + (hasFooter ? 1 : 0)}';
    final roundTripRelId =
        'rId${relationshipBase + (hasHeader ? 1 : 0) + (hasFooter ? 1 : 0) + 1}';
    final documentXml = _documentXml(
      paper,
      template,
      imageParts,
      headerRelId: headerRelId,
      footerRelId: footerRelId,
    );
    final stylesXml = _stylesXml(paper.pageLayout);
    final headerXml = hasHeader ? _headerPartXml(paper) : null;
    final footerXml = hasFooter ? _footerPartXml(paper) : null;

    addString(
      '[Content_Types].xml',
      _contentTypesXml(
        imageParts,
        hasHeader: hasHeader,
        hasFooter: hasFooter,
        includeRoundTripMetadata: true,
      ),
    );
    addString('_rels/.rels', _rootRelsXml());
    addString('docProps/core.xml', _coreXml(paper));
    addString('docProps/app.xml', _appXml());
    addString(
      'word/_rels/document.xml.rels',
      _documentRelsXml(
        imageParts,
        headerRelId: headerRelId,
        footerRelId: footerRelId,
        stylesRelId: stylesRelId,
        roundTripRelId: roundTripRelId,
      ),
    );
    addString('word/styles.xml', stylesXml);
    if (headerXml != null) {
      addString('word/header1.xml', headerXml);
    }
    if (footerXml != null) {
      addString('word/footer1.xml', footerXml);
    }
    addString('word/document.xml', documentXml);
    addString(
      SmartPaperDocxRoundTripService.customXmlPartName,
      SmartPaperDocxRoundTripService.buildEnvelopeXml(
        paper: paper,
        documentXml: documentXml,
        headerXml: headerXml,
        footerXml: footerXml,
        stylesXml: stylesXml,
      ),
    );

    for (final image in imageParts) {
      archive.addFile(
        ArchiveFile.bytes('word/media/${image.fileName}', image.bytes),
      );
    }

    return ZipEncoder().encode(archive);
  }

  static Future<List<_ImagePart>> _readImageParts(Paper paper) async {
    final images = <_ImagePart>[];
    var relationshipIndex = 1;

    for (final logoPath in paper.logos.where(
      (path) => path.trim().isNotEmpty,
    )) {
      final file = File(logoPath);
      if (!await file.exists()) continue;

      final extension = _imageExtension(file.path);
      if (extension == null) continue;

      images.add(
        _ImagePart(
          relationshipId: 'rId$relationshipIndex',
          fileName: 'image$relationshipIndex.$extension',
          contentType: _imageContentType(extension),
          bytes: await file.readAsBytes(),
          sourcePath: logoPath,
          headerLogo: true,
        ),
      );
      relationshipIndex++;
    }

    final seenQuestionPaths = <String>{};
    for (final attachment in _questionImageAttachments(paper)) {
      final sourcePath = attachment.path.trim();
      if (sourcePath.isEmpty || !seenQuestionPaths.add(sourcePath)) continue;
      final file = File(sourcePath);
      if (!await file.exists()) continue;
      final extension = _imageExtension(file.path);
      if (extension == null) continue;
      images.add(
        _ImagePart(
          relationshipId: 'rId$relationshipIndex',
          fileName: 'image$relationshipIndex.$extension',
          contentType: _imageContentType(extension),
          bytes: await file.readAsBytes(),
          sourcePath: sourcePath,
          headerLogo: false,
        ),
      );
      relationshipIndex++;
    }

    return images;
  }

  static String _documentXml(
    Paper paper,
    PaperTemplate template,
    List<_ImagePart> images, {
    required String? headerRelId,
    required String? footerRelId,
  }) {
    final buffer = StringBuffer();

    buffer
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
        '<w:document xmlns:w="$_wordNamespace" xmlns:r="$_relationsNamespace" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">',
      )
      ..write('<w:body>');

    if (template.hasBorder) {
      buffer.write(_paragraph('', spacingAfter: 80));
    }

    buffer.write(_headerXml(paper, template, images));

    if (paper.instruction.trim().isNotEmpty) {
      buffer.write(
        _paragraph(
          paper.instruction.trim(),
          editableTag: SmartPaperDocxRoundTripService.paperInstructionTag,
          alignment: _wordAlignment(paper.instructionAlignment.name),
          bold: true,
          italic: true,
          fontSize: template.questionFontSize,
          spacingAfter: 180,
        ),
      );
    }

    for (final section in paper.sections) {
      buffer.write(_sectionXml(section, template, paper, images));
    }

    if (paper.includeOmr) {
      buffer.write(
        _paragraph(
          'OMR sheet is not embedded in this Word document. Use the OMR Generator when you need a separate OMR sheet.',
          italic: true,
          fontSize: template.questionFontSize,
          spacingBefore: 240,
        ),
      );
    }

    buffer
      ..write(
        _sectionProperties(
          template,
          paper,
          headerRelId: headerRelId,
          footerRelId: footerRelId,
        ),
      )
      ..write('</w:body></w:document>');

    return buffer.toString();
  }

  static String _headerXml(
    Paper paper,
    PaperTemplate template,
    List<_ImagePart> images,
  ) {
    final layout = PaperHeaderLayoutFactory.resolveForPaper(template, paper);
    final buffer = StringBuffer();
    final logoImages = images.where((image) => image.headerLogo).toList();
    var imageIndex = 0;

    final elements = [...layout.elements]
      ..sort((a, b) {
        final y = a.y.compareTo(b.y);
        return y != 0 ? y : a.x.compareTo(b.x);
      });

    for (final element in elements) {
      final alignment = _wordAlignment(element.properties['alignment']);
      final fontSize =
          (element.properties['fontSize'] as num?)?.toDouble() ??
          template.questionFontSize;
      final bold = element.properties['bold'] == true;
      final italic = element.properties['italic'] == true;
      final underline = element.properties['decoration'] == 'underline';

      switch (element.type) {
        case ElementType.logo:
          if (imageIndex < logoImages.length) {
            buffer.write(
              _imageParagraph(logoImages[imageIndex], alignment: alignment),
            );
            imageIndex++;
          }
          break;
        case ElementType.schoolName:
          buffer.write(
            _paragraph(
              paper.schoolName,
              editableTag: SmartPaperDocxRoundTripService.schoolNameTag,
              alignment: alignment,
              bold: bold,
              italic: italic,
              underline: underline,
              fontSize: fontSize,
            ),
          );
          break;
        case ElementType.paperTitle:
          buffer.write(
            _paragraph(
              paper.title,
              editableTag: SmartPaperDocxRoundTripService.paperTitleTag,
              alignment: alignment,
              bold: bold,
              italic: italic,
              underline: underline,
              fontSize: fontSize,
            ),
          );
          break;
        case ElementType.maxMarks:
          buffer.write(
            _paragraph(
              PaperDocumentMarks.maximumMarksLabel(paper),
              alignment: alignment,
              bold: true,
              fontSize: fontSize,
            ),
          );
          break;
        case ElementType.headerFieldsBlock:
          buffer.write(_headerFieldsXml(paper, element, fontSize, alignment));
          break;
        case ElementType.staticText:
          final content =
              paper.customHeaderValues[element.paperBindingKey] ??
              element.content;
          if (content.trim().isNotEmpty) {
            buffer.write(
              _paragraph(
                content,
                alignment: alignment,
                bold: bold,
                italic: italic,
                underline: underline,
                fontSize: fontSize,
              ),
            );
          }
          break;
        case ElementType.horizontalLine:
          buffer.write(_divider());
          break;
        case ElementType.rectangular:
          if (element.content.trim().isNotEmpty) {
            buffer.write(
              _paragraph(
                element.content,
                alignment: alignment,
                bold: bold,
                fontSize: fontSize,
              ),
            );
          }
          break;
      }
    }

    return buffer.toString();
  }

  static String _headerFieldsXml(
    Paper paper,
    TemplateElement element,
    double fontSize,
    String alignment,
  ) {
    final fields = PaperHeaderLayoutFactory.resolveHeaderFields(element, paper);
    if (fields.isEmpty) return '';

    final rows = StringBuffer();
    for (var index = 0; index < fields.length; index += 2) {
      final rowFields = fields.sublist(
        index,
        (index + 2).clamp(0, fields.length).toInt(),
      );
      final cells = <String>[];
      for (var cellIndex = 0; cellIndex < 2; cellIndex++) {
        if (cellIndex >= rowFields.length) {
          cells.add(_tableCell(_paragraph('')));
          continue;
        }
        final field = rowFields[cellIndex];
        final value = field.value.trim();
        final content = field.isPlaceholder || value.isEmpty
            ? '________________'
            : value;
        cells.add(
          _tableCell(
            _paragraphRuns([
              _Run('${field.label}: ', bold: true, fontSize: fontSize * 0.85),
              _Run(content, fontSize: fontSize * 0.85),
            ], alignment: alignment),
          ),
        );
      }
      rows.write('<w:tr>${cells.join()}</w:tr>');
    }

    return '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/></w:tblPr>'
        '${rows.toString()}</w:tbl>';
  }

  static String _sectionXml(
    PaperSection section,
    PaperTemplate template,
    Paper paper,
    List<_ImagePart> images,
  ) {
    final buffer = StringBuffer();
    if (section.pageBreakBefore) {
      buffer.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
    }

    final keepNext = section.keepTogether && section.questions.isNotEmpty;
    final headingFontSize = 16 * section.headingSize.exportScale;
    final sectionMarksText = section.sectionMarksText;
    final rightTabPosition = _contentWidthTwips(template, paper);

    if (section.showTopDivider) {
      buffer.write(_divider(keepNext: keepNext));
    }

    if (section.showTitle || section.prefix.isNotEmpty) {
      final headingRuns = <_Run>[
        if (section.prefix.trim().isNotEmpty)
          _Run(
            section.showTitle
                ? '${section.prefix.trim()} '
                : section.prefix.trim(),
            bold: section.headingBold,
            allCaps: section.headingUppercase,
            fontSize: headingFontSize,
          ),
        if (section.showTitle)
          _Run(
            section.title,
            bold: section.headingBold,
            allCaps: section.headingUppercase,
            fontSize: headingFontSize,
            editableTag: SmartPaperDocxRoundTripService.sectionTitleTag(
              section.id,
            ),
          ),
        if (section.sectionMarksDisplay == SectionMarksDisplay.inline &&
            sectionMarksText != null)
          _Run(' ($sectionMarksText)', bold: true, fontSize: 11),
        if (section.sectionMarksDisplay == SectionMarksDisplay.right &&
            sectionMarksText != null) ...[
          const _Run('\t'),
          _Run(sectionMarksText, bold: true, fontSize: 11),
        ],
      ];
      buffer.write(
        _paragraphRuns(
          headingRuns,
          alignment: _wordAlignment(section.headingAlignment.name),
          spacingBefore: _pointsToTwips(section.spacing.beforePoints),
          spacingAfter: 80,
          rightTabPosition:
              section.sectionMarksDisplay == SectionMarksDisplay.right
              ? rightTabPosition
              : null,
          keepNext: keepNext,
          boxed: section.headingBoxed,
        ),
      );
    }

    if (section.instruction?.trim().isNotEmpty == true) {
      buffer.write(
        _paragraphRuns(
          [
            if (section.showInstructionLabel)
              const _Run('Instruction: ', italic: true, fontSize: 11),
            _Run(
              section.instruction!.trim(),
              italic: true,
              fontSize: 11,
              editableTag: SmartPaperDocxRoundTripService.sectionInstructionTag(
                section.id,
              ),
            ),
          ],
          alignment: _wordAlignment(section.instructionAlignment.name),
          spacingAfter: 80,
          keepNext: keepNext,
        ),
      );
    }

    final answerRule = PaperStructureService.answerRuleText(section);
    if (answerRule != null) {
      buffer.write(
        _paragraph(
          answerRule,
          bold: true,
          fontSize: 10,
          alignment: _wordAlignment(section.answerRuleAlignment.name),
          spacingAfter: 80,
          keepNext: keepNext,
        ),
      );
    }

    if (section.showBottomDivider) {
      buffer.write(_divider(keepNext: keepNext));
    }

    if (section.spacing.afterPoints > 0) {
      buffer.write(
        _paragraph(
          '',
          spacingAfter: _pointsToTwips(section.spacing.afterPoints),
          keepNext: keepNext,
        ),
      );
    }

    final hasManualPageBreak = section.questions.any(
      (question) =>
          question.isWordContentBlock &&
          WordContentBlockService.kindOf(question) ==
              WordContentBlockKind.pageBreak,
    );

    if (template.paperLayout == PaperLayout.twoColumn && !hasManualPageBreak) {
      buffer.write(
        '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
        '<w:tblCellMar><w:right w:w="180" w:type="dxa"/>'
        '<w:left w:w="180" w:type="dxa"/></w:tblCellMar></w:tblPr>',
      );
      for (var index = 0; index < section.questions.length; index += 2) {
        final left = _questionXml(
          PaperStructureService.numberedQuestionOrdinal(section, index),
          section.questions[index],
          template,
          paper,
          section,
          images,
        );
        final right = index + 1 < section.questions.length
            ? _questionXml(
                PaperStructureService.numberedQuestionOrdinal(
                  section,
                  index + 1,
                ),
                section.questions[index + 1],
                template,
                paper,
                section,
                images,
              )
            : _paragraph('');
        buffer.write('<w:tr>${_tableCell(left)}${_tableCell(right)}</w:tr>');
      }
      buffer.write('</w:tbl>');
    } else {
      for (final entry in section.questions.asMap().entries) {
        final question = entry.value;
        if (question.isWordContentBlock &&
            WordContentBlockService.kindOf(question) ==
                WordContentBlockKind.pageBreak) {
          buffer.write(_manualPageBreakParagraph());
          continue;
        }
        buffer.write(
          _questionXml(
            PaperStructureService.numberedQuestionOrdinal(section, entry.key),
            question,
            template,
            paper,
            section,
            images,
          ),
        );
      }
    }

    return buffer.toString();
  }

  static String _questionXml(
    int index,
    Question question,
    PaperTemplate template,
    Paper paper,
    PaperSection section,
    List<_ImagePart> images,
  ) {
    final buffer = StringBuffer();
    final text = OfficeTextFormatter.questionText(question.text).trim();
    final alignment = _wordAlignment(_flutterTextAlignName(question.alignment));
    final fontSize = template.questionFontSize;
    final paragraphSpacing = _pointsToTwips(
      paper.pageLayout.paragraphSpacingPoints,
    );

    if (question.isWordContentBlock) {
      if (text.isNotEmpty) {
        buffer.write(
          _paragraph(
            text,
            editableTag: SmartPaperDocxRoundTripService.questionTextTag(
              question.id,
            ),
            alignment: alignment,
            fontSize: fontSize,
            spacingBefore: 40,
            spacingAfter: paragraphSpacing,
          ),
        );
      }
      buffer.write(
        _questionAdvancedBlocksXml(
          question,
          fontSize: fontSize,
          images: images,
          indentLeft: 0,
        ),
      );
      return buffer.toString();
    }

    final label = PaperStructureService.questionLabel(index, paper, section);
    if (question.instructions.trim().isNotEmpty) {
      buffer.write(
        _paragraph(
          question.instructions.trim(),
          alignment: _wordAlignment(question.instructionAlignment.name),
          italic: true,
          bold: true,
          fontSize: fontSize * 0.9,
          indentLeft: 360,
          spacingAfter: 50,
        ),
      );
    }
    buffer.write(
      _paragraphRuns(
        [
          _Run('$label. ', bold: true, fontSize: fontSize),
          _Run(
            text,
            fontSize: fontSize,
            editableTag: SmartPaperDocxRoundTripService.questionTextTag(
              question.id,
            ),
          ),
          if (section.questionMarksPlacement == QuestionMarksPlacement.inline)
            _Run(
              ' [${_marks(question.marks)}]',
              bold: true,
              fontSize: fontSize,
              editableTag: SmartPaperDocxRoundTripService.questionMarksTag(
                question.id,
              ),
            )
          else ...[
            const _Run('\t'),
            _Run(
              '[${_marks(question.marks)}]',
              bold: true,
              fontSize: fontSize,
              editableTag: SmartPaperDocxRoundTripService.questionMarksTag(
                question.id,
              ),
            ),
          ],
        ],
        alignment: alignment,
        spacingBefore: 80,
        spacingAfter: paragraphSpacing,
        rightTabPosition:
            section.questionMarksPlacement == QuestionMarksPlacement.rightEdge
            ? _contentWidthTwips(template, paper)
            : null,
      ),
    );

    buffer.write(
      _questionAdvancedBlocksXml(
        question,
        fontSize: fontSize,
        images: images,
        indentLeft: 360,
      ),
    );

    if (question.isOptional) {
      buffer.write(
        _paragraph(
          '(Optional/OR Choice)',
          italic: true,
          fontSize: 9,
          indentLeft: 360,
        ),
      );
    }

    for (final expression in MathExpression.unplacedInRichText(
      question.text,
      question.mathExpressions,
    )) {
      buffer.write(
        _paragraph(
          expression.plainText.trim().isEmpty
              ? expression.latex
              : expression.plainText,
          italic: true,
          fontSize: fontSize,
          indentLeft: 360,
        ),
      );
    }

    if (question.options.isNotEmpty) {
      buffer.write(_optionsXml(question, fontSize: fontSize, indentLeft: 360));
    }

    if (question.type == QuestionType.fillInTheBlanks) {
      buffer.write(
        _paragraph(
          'Ans: ________________________',
          fontSize: fontSize,
          indentLeft: 360,
          spacingAfter: 80,
        ),
      );
    }

    if (question.subQuestions.isNotEmpty) {
      for (final entry in question.subQuestions.asMap().entries) {
        buffer.write(
          _nestedQuestionXml(
            label: QuestionAdvancedStructureService.partLabel(entry.key),
            question: entry.value,
            fontSize: fontSize,
            images: images,
            indentLeft: 360,
            marksPlacement: section.questionMarksPlacement,
            rightTabPosition: _contentWidthTwips(template, paper),
          ),
        );
      }
    }

    if (question.internalChoices.isNotEmpty) {
      for (final entry in question.internalChoices.asMap().entries) {
        if (entry.key > 0) {
          buffer.write(
            _paragraph(
              'OR',
              alignment: 'center',
              bold: true,
              fontSize: fontSize,
              spacingBefore: 60,
              spacingAfter: 60,
            ),
          );
        }
        buffer.write(
          _nestedQuestionXml(
            label: '',
            question: entry.value,
            fontSize: fontSize,
            images: images,
            indentLeft: 360,
            marksPlacement: section.questionMarksPlacement,
            rightTabPosition: _contentWidthTwips(template, paper),
          ),
        );
      }
    }

    final answerSpace = QuestionAdvancedStructureService.resolveAnswerSpace(
      question,
      section,
    );
    if (answerSpace.isVisible) {
      buffer.write(_answerSpaceXml(answerSpace, fontSize, indentLeft: 360));
    }

    return buffer.toString();
  }

  static String _nestedQuestionXml({
    required String label,
    required Question question,
    required double fontSize,
    required List<_ImagePart> images,
    required int indentLeft,
    required QuestionMarksPlacement marksPlacement,
    required int rightTabPosition,
  }) {
    final buffer = StringBuffer();
    final text = OfficeTextFormatter.questionText(question.text).trim();
    if (question.instructions.trim().isNotEmpty) {
      buffer.write(
        _paragraph(
          question.instructions.trim(),
          alignment: _wordAlignment(question.instructionAlignment.name),
          italic: true,
          bold: true,
          fontSize: fontSize * 0.9,
          indentLeft: indentLeft,
          spacingAfter: 40,
        ),
      );
    }
    final runs = <_Run>[
      if (label.isNotEmpty) _Run('$label ', bold: true, fontSize: fontSize),
      _Run(
        text,
        fontSize: fontSize,
        editableTag: SmartPaperDocxRoundTripService.questionTextTag(
          question.id,
        ),
      ),
      if (marksPlacement == QuestionMarksPlacement.inline)
        _Run(
          ' [${_marks(question.marks)}]',
          bold: true,
          fontSize: fontSize,
          editableTag: SmartPaperDocxRoundTripService.questionMarksTag(
            question.id,
          ),
        )
      else ...[
        const _Run('\t'),
        _Run(
          '[${_marks(question.marks)}]',
          bold: true,
          fontSize: fontSize,
          editableTag: SmartPaperDocxRoundTripService.questionMarksTag(
            question.id,
          ),
        ),
      ],
    ];
    buffer.write(
      _paragraphRuns(
        runs,
        indentLeft: indentLeft,
        spacingBefore: 50,
        spacingAfter: 60,
        rightTabPosition: marksPlacement == QuestionMarksPlacement.rightEdge
            ? rightTabPosition
            : null,
      ),
    );

    buffer.write(
      _questionAdvancedBlocksXml(
        question,
        fontSize: fontSize,
        images: images,
        indentLeft: indentLeft + 240,
      ),
    );

    for (final expression in MathExpression.unplacedInRichText(
      question.text,
      question.mathExpressions,
    )) {
      buffer.write(
        _paragraph(
          expression.plainText.trim().isEmpty
              ? expression.latex
              : expression.plainText,
          italic: true,
          fontSize: fontSize,
          indentLeft: indentLeft + 240,
        ),
      );
    }

    if (question.options.isNotEmpty) {
      buffer.write(
        _optionsXml(question, fontSize: fontSize, indentLeft: indentLeft + 240),
      );
    }

    if (question.subQuestions.isNotEmpty) {
      for (final entry in question.subQuestions.asMap().entries) {
        buffer.write(
          _nestedQuestionXml(
            label: QuestionAdvancedStructureService.partLabel(entry.key),
            question: entry.value,
            fontSize: fontSize,
            images: images,
            indentLeft: indentLeft + 240,
            marksPlacement: marksPlacement,
            rightTabPosition: rightTabPosition,
          ),
        );
      }
    }

    if (question.internalChoices.isNotEmpty) {
      for (final entry in question.internalChoices.asMap().entries) {
        if (entry.key > 0) {
          buffer.write(
            _paragraph(
              'OR',
              alignment: 'center',
              bold: true,
              fontSize: fontSize,
              spacingBefore: 40,
              spacingAfter: 40,
            ),
          );
        }
        buffer.write(
          _nestedQuestionXml(
            label: '',
            question: entry.value,
            fontSize: fontSize,
            images: images,
            indentLeft: indentLeft + 240,
            marksPlacement: marksPlacement,
            rightTabPosition: rightTabPosition,
          ),
        );
      }
    }

    final advanced = QuestionAdvancedContent.fromQuestion(question);
    if (advanced.hasAnswerSpace) {
      buffer.write(
        _answerSpaceXml(
          ResolvedQuestionAnswerSpace(
            style: advanced.answerSpace.style,
            lines: advanced.answerSpace.lines,
            questionOverride: true,
          ),
          fontSize,
          indentLeft: indentLeft + 240,
        ),
      );
    }

    return buffer.toString();
  }

  static String _questionAdvancedBlocksXml(
    Question question, {
    required double fontSize,
    required List<_ImagePart> images,
    required int indentLeft,
  }) {
    final buffer = StringBuffer();
    final advanced = QuestionAdvancedContent.fromQuestion(question);

    if (advanced.hasStimulus) {
      buffer.write(
        _stimulusXml(
          advanced.stimulus!,
          fontSize: fontSize,
          indentLeft: indentLeft,
        ),
      );
    }

    for (final attachment in question.attachments) {
      if (attachment.kind != QuestionAttachmentKind.image) continue;
      final image = _imageForSourcePath(images, attachment.path);
      if (image == null) continue;
      buffer.write(
        _imageParagraph(image, alignment: 'center', sizeEmu: 2286000),
      );
      if (attachment.caption.trim().isNotEmpty) {
        buffer.write(
          _paragraph(
            attachment.caption.trim(),
            alignment: 'center',
            italic: true,
            fontSize: fontSize * 0.85,
            spacingAfter: 80,
          ),
        );
      }
    }

    if (question.tableData != null) {
      buffer.write(_questionTableXml(question.tableData!, fontSize: fontSize));
    }

    if (advanced.hasWordBank) {
      buffer.write(
        _wordBankXml(
          advanced.wordBank,
          fontSize: fontSize,
          indentLeft: indentLeft,
        ),
      );
    }

    return buffer.toString();
  }

  static String _stimulusXml(
    QuestionStimulus stimulus, {
    required double fontSize,
    required int indentLeft,
  }) {
    final content = StringBuffer();
    if (stimulus.title.trim().isNotEmpty) {
      content.write(
        _paragraph(
          stimulus.title.trim(),
          bold: true,
          fontSize: fontSize,
          spacingAfter: 40,
        ),
      );
    }
    for (final line in stimulus.text.split('\n')) {
      content.write(
        _paragraph(
          line,
          italic: stimulus.kind == QuestionStimulusKind.poem,
          fontSize: fontSize,
          spacingAfter: 25,
        ),
      );
    }
    return '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
        '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="A6A6A6"/>'
        '<w:left w:val="single" w:sz="4" w:color="A6A6A6"/>'
        '<w:bottom w:val="single" w:sz="4" w:color="A6A6A6"/>'
        '<w:right w:val="single" w:sz="4" w:color="A6A6A6"/>'
        '</w:tblBorders></w:tblPr><w:tr>${_tableCell(content.toString())}</w:tr></w:tbl>';
  }

  static String _wordBankXml(
    List<String> items, {
    required double fontSize,
    required int indentLeft,
  }) {
    final text = items.join('     ');
    return '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
        '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="A6A6A6"/>'
        '<w:left w:val="single" w:sz="4" w:color="A6A6A6"/>'
        '<w:bottom w:val="single" w:sz="4" w:color="A6A6A6"/>'
        '<w:right w:val="single" w:sz="4" w:color="A6A6A6"/>'
        '</w:tblBorders></w:tblPr><w:tr>${_tableCell(_paragraph(text, alignment: 'center', fontSize: fontSize, indentLeft: indentLeft, spacingAfter: 40))}</w:tr></w:tbl>';
  }

  static String _questionTableXml(
    QuestionTable table, {
    required double fontSize,
  }) {
    final columnCount = table.headers.isNotEmpty
        ? table.headers.length
        : (table.rows.isEmpty ? 0 : table.rows.first.length);
    if (columnCount == 0) return '';

    final buffer = StringBuffer();
    if (table.caption.trim().isNotEmpty) {
      buffer.write(
        _paragraph(
          table.caption.trim(),
          alignment: 'center',
          bold: true,
          fontSize: fontSize,
          spacingAfter: 50,
        ),
      );
    }
    buffer.write(
      '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
      '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="808080"/>'
      '<w:left w:val="single" w:sz="4" w:color="808080"/>'
      '<w:bottom w:val="single" w:sz="4" w:color="808080"/>'
      '<w:right w:val="single" w:sz="4" w:color="808080"/>'
      '<w:insideH w:val="single" w:sz="4" w:color="BFBFBF"/>'
      '<w:insideV w:val="single" w:sz="4" w:color="BFBFBF"/>'
      '</w:tblBorders></w:tblPr>',
    );
    if (table.headers.isNotEmpty) {
      buffer.write('<w:tr>');
      for (var index = 0; index < columnCount; index++) {
        final text = index < table.headers.length ? table.headers[index] : '';
        buffer.write(
          _tableCell(
            _paragraph(text, bold: true, fontSize: fontSize, spacingAfter: 30),
          ),
        );
      }
      buffer.write('</w:tr>');
    }
    for (final row in table.rows) {
      buffer.write('<w:tr>');
      for (var index = 0; index < columnCount; index++) {
        final text = index < row.length ? row[index] : '';
        buffer.write(
          _tableCell(_paragraph(text, fontSize: fontSize, spacingAfter: 30)),
        );
      }
      buffer.write('</w:tr>');
    }
    buffer.write('</w:tbl>');
    return buffer.toString();
  }

  static String _optionsXml(
    Question question, {
    required double fontSize,
    int indentLeft = 360,
  }) {
    final layout = QuestionOptionLayoutCodec.fromQuestion(question);
    final entries = question.options.asMap().entries.toList();

    List<_Run> optionRuns(MapEntry<int, QuestionOption> entry) {
      return [
        _Run('${String.fromCharCode(65 + entry.key)}) ', fontSize: fontSize),
        _Run(
          entry.value.text,
          fontSize: fontSize,
          editableTag: SmartPaperDocxRoundTripService.questionOptionTag(
            question.id,
            entry.value.id,
          ),
        ),
      ];
    }

    switch (layout) {
      case QuestionOptionLayout.vertical:
        return entries
            .map(
              (entry) => _paragraphRuns(
                optionRuns(entry),
                indentLeft: indentLeft,
                spacingAfter: 40,
              ),
            )
            .join();
      case QuestionOptionLayout.inline:
        final runs = <_Run>[];
        for (var index = 0; index < entries.length; index++) {
          if (index > 0) runs.add(_Run('     ', fontSize: fontSize));
          runs.addAll(optionRuns(entries[index]));
        }
        return _paragraphRuns(runs, indentLeft: indentLeft, spacingAfter: 60);
      case QuestionOptionLayout.twoColumn:
        final buffer = StringBuffer()
          ..write(
            '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
            '<w:tblCellMar><w:right w:w="120" w:type="dxa"/>'
            '<w:left w:w="120" w:type="dxa"/></w:tblCellMar></w:tblPr>',
          );
        for (var index = 0; index < entries.length; index += 2) {
          final left = _paragraphRuns(
            optionRuns(entries[index]),
            spacingAfter: 30,
          );
          final right = index + 1 < entries.length
              ? _paragraphRuns(optionRuns(entries[index + 1]), spacingAfter: 30)
              : _paragraph('');
          buffer.write('<w:tr>${_tableCell(left)}${_tableCell(right)}</w:tr>');
        }
        buffer.write('</w:tbl>');
        return buffer.toString();
    }
  }

  static String _answerSpaceXml(
    ResolvedQuestionAnswerSpace answerSpace,
    double fontSize, {
    required int indentLeft,
  }) {
    switch (answerSpace.style) {
      case QuestionAnswerSpaceStyle.graph:
        final rows = answerSpace.lines.clamp(1, 16).toInt();
        final buffer = StringBuffer()
          ..write(
            '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
            '<w:tblBorders>'
            '<w:top w:val="single" w:sz="2" w:color="BFBFBF"/>'
            '<w:left w:val="single" w:sz="2" w:color="BFBFBF"/>'
            '<w:bottom w:val="single" w:sz="2" w:color="BFBFBF"/>'
            '<w:right w:val="single" w:sz="2" w:color="BFBFBF"/>'
            '<w:insideH w:val="single" w:sz="2" w:color="D9D9D9"/>'
            '<w:insideV w:val="single" w:sz="2" w:color="D9D9D9"/>'
            '</w:tblBorders></w:tblPr>',
          );
        for (var row = 0; row < rows; row++) {
          buffer.write('<w:tr>');
          for (var column = 0; column < 8; column++) {
            buffer.write(_tableCell(_paragraph('', spacingAfter: 20)));
          }
          buffer.write('</w:tr>');
        }
        buffer.write('</w:tbl>');
        return buffer.toString();
      case QuestionAnswerSpaceStyle.box:
        final body = StringBuffer();
        for (var index = 0; index < answerSpace.lines; index++) {
          body.write(_paragraph(' ', fontSize: fontSize, spacingAfter: 45));
        }
        return '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
            '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="808080"/>'
            '<w:left w:val="single" w:sz="4" w:color="808080"/>'
            '<w:bottom w:val="single" w:sz="4" w:color="808080"/>'
            '<w:right w:val="single" w:sz="4" w:color="808080"/>'
            '</w:tblBorders></w:tblPr><w:tr>${_tableCell(body.toString())}</w:tr></w:tbl>';
      case QuestionAnswerSpaceStyle.ruled:
        final buffer = StringBuffer();
        for (var index = 0; index < answerSpace.lines; index++) {
          buffer.write(
            _paragraph(
              '________________________________________',
              fontSize: fontSize,
              indentLeft: indentLeft,
              spacingAfter: 25,
            ),
          );
        }
        return buffer.toString();
      case QuestionAnswerSpaceStyle.blank:
        final buffer = StringBuffer();
        for (var index = 0; index < answerSpace.lines; index++) {
          buffer.write(
            _paragraph(
              ' ',
              fontSize: fontSize,
              indentLeft: indentLeft,
              spacingAfter: 55,
            ),
          );
        }
        return buffer.toString();
      case QuestionAnswerSpaceStyle.none:
        return '';
    }
  }

  static _ImagePart? _imageForSourcePath(
    List<_ImagePart> images,
    String sourcePath,
  ) {
    for (final image in images) {
      if (!image.headerLogo && image.sourcePath == sourcePath) return image;
    }
    return null;
  }

  static Iterable<QuestionAttachment> _questionImageAttachments(
    Paper paper,
  ) sync* {
    for (final section in paper.sections) {
      for (final question in section.questions) {
        yield* _questionImageAttachmentsForQuestion(question);
      }
    }
  }

  static Iterable<QuestionAttachment> _questionImageAttachmentsForQuestion(
    Question question,
  ) sync* {
    for (final attachment in question.attachments) {
      if (attachment.kind == QuestionAttachmentKind.image) yield attachment;
    }
    for (final child in [
      ...question.subQuestions,
      ...question.internalChoices,
    ]) {
      yield* _questionImageAttachmentsForQuestion(child);
    }
  }

  static String _marks(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  static String _paragraph(
    String text, {
    String? editableTag,
    String alignment = 'left',
    bool bold = false,
    bool italic = false,
    bool underline = false,
    double fontSize = 12,
    int spacingBefore = 0,
    int spacingAfter = 120,
    int indentLeft = 0,
    int? rightTabPosition,
    bool keepNext = false,
    bool boxed = false,
  }) {
    return _paragraphRuns(
      [
        _Run(
          text,
          bold: bold,
          italic: italic,
          underline: underline,
          fontSize: fontSize,
          editableTag: editableTag,
        ),
      ],
      alignment: alignment,
      spacingBefore: spacingBefore,
      spacingAfter: spacingAfter,
      indentLeft: indentLeft,
      rightTabPosition: rightTabPosition,
      keepNext: keepNext,
      boxed: boxed,
    );
  }

  static String _paragraphRuns(
    List<_Run> runs, {
    String alignment = 'left',
    int spacingBefore = 0,
    int spacingAfter = 120,
    int indentLeft = 0,
    int? rightTabPosition,
    bool keepNext = false,
    bool boxed = false,
  }) {
    final paragraphProperties = StringBuffer()
      ..write('<w:pPr>')
      ..write('<w:jc w:val="$alignment"/>')
      ..write('<w:spacing w:before="$spacingBefore" w:after="$spacingAfter"/>');
    if (keepNext) {
      paragraphProperties.write('<w:keepNext/>');
    }
    if (rightTabPosition != null) {
      paragraphProperties.write(
        '<w:tabs><w:tab w:val="right" w:pos="$rightTabPosition"/></w:tabs>',
      );
    }
    if (boxed) {
      paragraphProperties.write(
        '<w:pBdr><w:top w:val="single" w:sz="6" w:space="3" w:color="666666"/>'
        '<w:left w:val="single" w:sz="6" w:space="3" w:color="666666"/>'
        '<w:bottom w:val="single" w:sz="6" w:space="3" w:color="666666"/>'
        '<w:right w:val="single" w:sz="6" w:space="3" w:color="666666"/></w:pBdr>',
      );
    }
    if (indentLeft > 0) {
      paragraphProperties.write('<w:ind w:left="$indentLeft"/>');
    }
    paragraphProperties.write('</w:pPr>');

    return '<w:p>$paragraphProperties${runs.map(_runXml).join()}</w:p>';
  }

  static String _runXml(_Run run) {
    if (run.text == '\t') return '<w:r><w:tab/></w:r>';
    final halfPoints = (run.fontSize * 2).round();
    final properties = StringBuffer()
      ..write('<w:rPr>')
      ..write(run.bold ? '<w:b/>' : '')
      ..write(run.allCaps ? '<w:caps/>' : '')
      ..write(run.italic ? '<w:i/>' : '')
      ..write(run.underline ? '<w:u w:val="single"/>' : '')
      ..write('<w:sz w:val="$halfPoints"/>')
      ..write('<w:szCs w:val="$halfPoints"/>')
      ..write('</w:rPr>');

    final runXml =
        '<w:r>$properties<w:t xml:space="preserve">${_xml(run.text)}</w:t></w:r>';
    if (run.editableTag == null || run.editableTag!.isEmpty) return runXml;
    return '<w:sdt><w:sdtPr><w:tag w:val="${_xml(run.editableTag!)}"/>'
        '<w:alias w:val="EduSheet editable content"/></w:sdtPr>'
        '<w:sdtContent>$runXml</w:sdtContent></w:sdt>';
  }

  static String _imageParagraph(
    _ImagePart image, {
    String alignment = 'center',
    int sizeEmu = 914400,
  }) {
    final id = image.relationshipId.replaceAll(RegExp(r'\D'), '');

    return '<w:p><w:pPr><w:jc w:val="$alignment"/></w:pPr><w:r><w:drawing>'
        '<wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$sizeEmu" cy="$sizeEmu"/>'
        '<wp:docPr id="$id" name="Logo $id"/>'
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic><pic:nvPicPr><pic:cNvPr id="$id" name="${_xml(image.fileName)}"/>'
        '<pic:cNvPicPr/></pic:nvPicPr><pic:blipFill>'
        '<a:blip r:embed="${image.relationshipId}"/><a:stretch><a:fillRect/></a:stretch>'
        '</pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/>'
        '<a:ext cx="$sizeEmu" cy="$sizeEmu"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic></wp:inline>'
        '</w:drawing></w:r></w:p>';
  }

  static String _divider({bool keepNext = false}) {
    final keep = keepNext ? '<w:keepNext/>' : '';
    return '<w:p><w:pPr>$keep<w:pBdr><w:bottom w:val="single" w:sz="6" '
        'w:space="1" w:color="000000"/></w:pBdr>'
        '<w:spacing w:after="120"/></w:pPr></w:p>';
  }

  static String _tableCell(String content) {
    return '<w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr>'
        '$content</w:tc>';
  }

  static String _sectionProperties(
    PaperTemplate template,
    Paper paper, {
    required String? headerRelId,
    required String? footerRelId,
  }) {
    final page = _resolvedPageSizeTwips(template, paper.pageLayout);
    final margins = paper.pageLayout.margins;
    final orientation = paper.pageLayout.orientation;
    final border = template.hasBorder
        ? '<w:pgBorders w:offsetFrom="page"><w:top w:val="single" w:sz="8" w:space="24" w:color="000000"/>'
              '<w:left w:val="single" w:sz="8" w:space="24" w:color="000000"/>'
              '<w:bottom w:val="single" w:sz="8" w:space="24" w:color="000000"/>'
              '<w:right w:val="single" w:sz="8" w:space="24" w:color="000000"/></w:pgBorders>'
        : '';
    final refs = StringBuffer();
    if (headerRelId != null) {
      refs.write('<w:headerReference w:type="default" r:id="$headerRelId"/>');
    }
    if (footerRelId != null) {
      refs.write('<w:footerReference w:type="default" r:id="$footerRelId"/>');
    }
    final orient = orientation == PaperPageOrientation.landscape
        ? ' w:orient="landscape"'
        : '';

    return '<w:sectPr>${refs.toString()}'
        '<w:pgSz w:w="${page.width}" w:h="${page.height}"$orient/>'
        '<w:pgMar w:top="${_pointsToTwips(margins.topPoints)}" '
        'w:right="${_pointsToTwips(margins.rightPoints)}" '
        'w:bottom="${_pointsToTwips(margins.bottomPoints)}" '
        'w:left="${_pointsToTwips(margins.leftPoints)}" '
        'w:header="${_pointsToTwips(paper.pageLayout.headerDistancePoints)}" '
        'w:footer="${_pointsToTwips(paper.pageLayout.footerDistancePoints)}" '
        'w:gutter="0"/>'
        '<w:cols w:space="720"/>$border</w:sectPr>';
  }

  static _PageSize _resolvedPageSizeTwips(
    PaperTemplate template,
    PaperPageLayout layout,
  ) {
    final portrait = switch (layout.pageSize) {
      PaperPageSize.useTemplate => _pageSizeTwips(template.paperSize),
      PaperPageSize.a4 => const _PageSize(11906, 16838),
      PaperPageSize.a5 => const _PageSize(8391, 11906),
      PaperPageSize.a3 => const _PageSize(16838, 23811),
      PaperPageSize.letter => const _PageSize(12240, 15840),
      PaperPageSize.legal => const _PageSize(12240, 20160),
    };
    if (layout.orientation == PaperPageOrientation.landscape) {
      return _PageSize(portrait.height, portrait.width);
    }
    return portrait;
  }

  static _PageSize _pageSizeTwips(PaperSize size) {
    switch (size) {
      case PaperSize.a3:
        return const _PageSize(16838, 23811);
      case PaperSize.a5:
        return const _PageSize(8391, 11906);
      case PaperSize.letter:
        return const _PageSize(12240, 15840);
      case PaperSize.legal:
        return const _PageSize(12240, 20160);
      case PaperSize.a4:
        return const _PageSize(11906, 16838);
    }
  }

  static int _pointsToTwips(double points) => (points * 20).round();

  static int _contentWidthTwips(PaperTemplate template, Paper paper) {
    final page = _resolvedPageSizeTwips(template, paper.pageLayout);
    final margins = paper.pageLayout.margins;
    final width =
        page.width -
        _pointsToTwips(margins.leftPoints) -
        _pointsToTwips(margins.rightPoints);
    return width.clamp(2400, 18000).toInt();
  }

  static String _manualPageBreakParagraph() {
    return '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';
  }

  static String _documentRelsXml(
    List<_ImagePart> images, {
    required String? headerRelId,
    required String? footerRelId,
    required String stylesRelId,
    required String roundTripRelId,
  }) {
    final rels = StringBuffer();
    for (final image in images) {
      rels.write(
        '<Relationship Id="${image.relationshipId}" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
        'Target="media/${image.fileName}"/>',
      );
    }
    if (headerRelId != null) {
      rels.write(
        '<Relationship Id="$headerRelId" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" '
        'Target="header1.xml"/>',
      );
    }
    if (footerRelId != null) {
      rels.write(
        '<Relationship Id="$footerRelId" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" '
        'Target="footer1.xml"/>',
      );
    }
    rels.write(
      '<Relationship Id="$stylesRelId" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
      'Target="styles.xml"/>',
    );
    rels.write(
      '<Relationship Id="$roundTripRelId" '
      'Type="${SmartPaperDocxRoundTripService.relationshipType}" '
      'Target="../${SmartPaperDocxRoundTripService.customXmlPartName}"/>',
    );

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${rels.toString()}</Relationships>';
  }

  static String _contentTypesXml(
    List<_ImagePart> images, {
    required bool hasHeader,
    required bool hasFooter,
    required bool includeRoundTripMetadata,
  }) {
    final imageDefaults = images
        .map(
          (image) =>
              '<Default Extension="${p.extension(image.fileName).substring(1)}" '
              'ContentType="${image.contentType}"/>',
        )
        .toSet()
        .join();
    final headerOverride = hasHeader
        ? '<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>'
        : '';
    final footerOverride = hasFooter
        ? '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>'
        : '';

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '$imageDefaults'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
        '${includeRoundTripMetadata ? '<Override PartName="/${SmartPaperDocxRoundTripService.customXmlPartName}" ContentType="application/xml"/>' : ''}'
        '$headerOverride$footerOverride'
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
        '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
        '</Types>';
  }

  static String _stylesXml(PaperPageLayout layout) {
    final line = (layout.lineSpacing * 240).round().clamp(192, 720);
    final after = _pointsToTwips(layout.paragraphSpacingPoints);
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w="$_wordNamespace">'
        '<w:docDefaults><w:rPrDefault><w:rPr>'
        '<w:sz w:val="24"/><w:szCs w:val="24"/>'
        '</w:rPr></w:rPrDefault><w:pPrDefault><w:pPr>'
        '<w:spacing w:after="$after" w:line="$line" w:lineRule="auto"/>'
        '</w:pPr></w:pPrDefault></w:docDefaults>'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
        '<w:name w:val="Normal"/><w:qFormat/>'
        '<w:pPr><w:spacing w:after="$after" w:line="$line" w:lineRule="auto"/></w:pPr>'
        '</w:style>'
        '</w:styles>';
  }

  static String _headerPartXml(Paper paper) {
    final text = paper.headerText.trim();
    final includePageNumber =
        paper.showPageNumbers &&
        paper.pageLayout.pageNumberPosition ==
            PaperPageNumberPosition.headerRight;
    final body = _headerFooterBody(
      text: text,
      includePageNumber: includePageNumber,
      pageNumberAlignment: 'right',
      textAlignment: 'left',
    );
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:hdr xmlns:w="$_wordNamespace" xmlns:r="$_relationsNamespace">'
        '$body</w:hdr>';
  }

  static String _footerPartXml(Paper paper) {
    final text = paper.footerText.trim();
    final position = paper.pageLayout.pageNumberPosition;
    final includePageNumber =
        paper.showPageNumbers &&
        position != PaperPageNumberPosition.headerRight;
    final pageAlignment = position == PaperPageNumberPosition.footerRight
        ? 'right'
        : 'center';
    final body = _headerFooterBody(
      text: text,
      includePageNumber: includePageNumber,
      pageNumberAlignment: pageAlignment,
      textAlignment: text.isNotEmpty && includePageNumber
          ? 'left'
          : pageAlignment,
    );
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:ftr xmlns:w="$_wordNamespace" xmlns:r="$_relationsNamespace">'
        '$body</w:ftr>';
  }

  static String _headerFooterBody({
    required String text,
    required bool includePageNumber,
    required String pageNumberAlignment,
    required String textAlignment,
  }) {
    if (text.isNotEmpty && includePageNumber) {
      final borderlessTableStart =
          '<w:tbl><w:tblPr><w:tblW w:w="5000" w:type="pct"/>'
          '<w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/>'
          '<w:bottom w:val="nil"/><w:right w:val="nil"/>'
          '<w:insideH w:val="nil"/><w:insideV w:val="nil"/>'
          '</w:tblBorders></w:tblPr><w:tr>';
      final textParagraph = _paragraph(
        text,
        alignment: textAlignment,
        fontSize: 9,
        spacingAfter: 0,
      );
      final pageParagraph = _pageNumberParagraph(
        alignment: pageNumberAlignment,
      );
      if (pageNumberAlignment == 'center') {
        return '$borderlessTableStart'
            '${_headerFooterCell(textParagraph, 1667)}'
            '${_headerFooterCell(pageParagraph, 1666)}'
            '${_headerFooterCell(_paragraph('', spacingAfter: 0), 1667)}'
            '</w:tr></w:tbl>';
      }
      return '$borderlessTableStart'
          '${_headerFooterCell(textParagraph, 2500)}'
          '${_headerFooterCell(pageParagraph, 2500)}'
          '</w:tr></w:tbl>';
    }
    if (text.isNotEmpty) {
      return _paragraph(
        text,
        alignment: textAlignment,
        fontSize: 9,
        spacingAfter: 0,
      );
    }
    if (includePageNumber) {
      return _pageNumberParagraph(alignment: pageNumberAlignment);
    }
    return _paragraph('', spacingAfter: 0);
  }

  static String _headerFooterCell(String content, int widthPct) {
    return '<w:tc><w:tcPr><w:tcW w:w="$widthPct" w:type="pct"/></w:tcPr>'
        '$content</w:tc>';
  }

  static String _pageNumberParagraph({required String alignment}) {
    return '<w:p><w:pPr><w:jc w:val="$alignment"/>'
        '<w:spacing w:after="0"/></w:pPr>'
        '<w:r><w:t xml:space="preserve">Page </w:t></w:r>'
        '${_fieldRun('PAGE')}'
        '<w:r><w:t xml:space="preserve"> of </w:t></w:r>'
        '${_fieldRun('NUMPAGES')}'
        '</w:p>';
  }

  static String _fieldRun(String instruction) {
    return '<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
        '<w:r><w:instrText xml:space="preserve"> $instruction </w:instrText></w:r>'
        '<w:r><w:fldChar w:fldCharType="separate"/></w:r>'
        '<w:r><w:t>1</w:t></w:r>'
        '<w:r><w:fldChar w:fldCharType="end"/></w:r>';
  }

  static String _rootRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
        '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
        '</Relationships>';
  }

  static String _coreXml(Paper paper) {
    final now = DateTime.now().toUtc().toIso8601String();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>${_xml(paper.title)}</dc:title>'
        '<dc:creator>EduSheet</dc:creator>'
        '<cp:lastModifiedBy>EduSheet</cp:lastModifiedBy>'
        '<dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created>'
        '<dcterms:modified xsi:type="dcterms:W3CDTF">$now</dcterms:modified>'
        '</cp:coreProperties>';
  }

  static String _appXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
        'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
        '<Application>EduSheet</Application></Properties>';
  }

  static String _wordAlignment(String? alignment) {
    switch (alignment) {
      case 'center':
        return 'center';
      case 'right':
      case 'end':
        return 'right';
      case 'justify':
        return 'both';
      default:
        return 'left';
    }
  }

  static String _flutterTextAlignName(dynamic alignment) {
    final name = alignment.toString().split('.').last;
    return name == 'end' ? 'right' : name;
  }

  static String? _imageExtension(String filePath) {
    final extension = p.extension(filePath).replaceFirst('.', '').toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return extension;
      default:
        return null;
    }
  }

  static String _imageContentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/png';
    }
  }

  static String _xml(String value) {
    return OfficeTextFormatter.xml(value);
  }
}

class _Run {
  final String text;
  final bool bold;
  final bool italic;
  final bool allCaps;
  final bool underline;
  final double fontSize;
  final String? editableTag;

  const _Run(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.allCaps = false,
    this.underline = false,
    this.fontSize = 12,
    this.editableTag,
  });
}

class _ImagePart {
  final String relationshipId;
  final String fileName;
  final String contentType;
  final List<int> bytes;
  final String sourcePath;
  final bool headerLogo;

  const _ImagePart({
    required this.relationshipId,
    required this.fileName,
    required this.contentType,
    required this.bytes,
    required this.sourcePath,
    required this.headerLogo,
  });
}

class _PageSize {
  final int width;
  final int height;

  const _PageSize(this.width, this.height);
}
