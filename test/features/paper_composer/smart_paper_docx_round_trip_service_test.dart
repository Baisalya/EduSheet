import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/paper_composer/application/smart_paper_docx_round_trip_service.dart';
import 'package:edusheet/features/paper_composer/application/word_content_block_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exact EduSheet DOCX snapshot restores canonical Paper JSON', () {
    final paper = _paper();
    final documentXml = _documentXml(paper, questionText: 'Solve x + 1');
    final bytes = _docxBytes(
      documentXml: documentXml,
      stylesXml: _stylesXml,
      envelopeXml: SmartPaperDocxRoundTripService.buildEnvelopeXml(
        paper: paper,
        documentXml: documentXml,
        stylesXml: _stylesXml,
      ),
    );

    final result = SmartPaperDocxRoundTripService.importFromBytes(bytes);

    expect(result.status, SmartPaperDocxImportStatus.exactEduSheetRoundTrip);
    expect(result.paper, isNotNull);
    expect(jsonEncode(result.paper!.toJson()), jsonEncode(paper.toJson()));
  });

  test('Word text and basic rich formatting safely merge by EduSheet tag', () {
    final paper = _paper();
    final exported = _documentXml(paper, questionText: 'Solve x + 1');
    final edited = _documentXml(
      paper,
      questionText: 'Solve x + 2',
      questionBold: true,
    );
    final bytes = _docxBytes(
      documentXml: edited,
      stylesXml: _stylesXml,
      envelopeXml: SmartPaperDocxRoundTripService.buildEnvelopeXml(
        paper: paper,
        documentXml: exported,
        stylesXml: _stylesXml,
      ),
    );

    final result = SmartPaperDocxRoundTripService.importFromBytes(bytes);

    expect(
      result.status,
      SmartPaperDocxImportStatus.safeMergedEduSheetRoundTrip,
    );
    expect(result.canApplySafely, isTrue);
    expect(result.mergedFieldCount, 1);
    final merged = result.paper!;
    expect(
      merged.sections.single.questions.first.plainTextAccessibility,
      'Solve x + 2',
    );
    expect(
      merged.sections.single.questions.first.text,
      contains('"bold":true'),
    );
    // Everything outside the supported Word edit remains canonical.
    expect(merged.pageLayout.toJson(), paper.pageLayout.toJson());
    expect(
      merged.sections.single.questions.first.metadata,
      paper.sections.single.questions.first.metadata,
    );
    expect(merged.sections.single.questions.last.isWordContentBlock, isTrue);
    expect(
      merged.sections.single.questions.last.plainTextAccessibility,
      'Teacher free paragraph',
    );
  });

  test(
    'marks and answer option edits merge without flattening question data',
    () {
      final paper = _paper(withOptions: true);
      final exported = _documentXml(
        paper,
        questionText: 'Solve x + 1',
        marks: '5',
        optionText: 'One',
      );
      final edited = _documentXml(
        paper,
        questionText: 'Solve x + 1',
        marks: '7',
        optionText: 'First',
      );
      final bytes = _docxBytes(
        documentXml: edited,
        stylesXml: _stylesXml,
        envelopeXml: SmartPaperDocxRoundTripService.buildEnvelopeXml(
          paper: paper,
          documentXml: exported,
          stylesXml: _stylesXml,
        ),
      );

      final result = SmartPaperDocxRoundTripService.importFromBytes(bytes);

      expect(
        result.status,
        SmartPaperDocxImportStatus.safeMergedEduSheetRoundTrip,
      );
      final question = result.paper!.sections.single.questions.first;
      expect(question.marks, 7);
      expect(question.options.first.text, 'First');
      expect(question.options.first.isCorrect, isTrue);
      expect(question.metadata['custom'], 'preserve-me');
    },
  );

  test('unsupported structural Word edits never restore a stale snapshot', () {
    final paper = _paper();
    final exported = _documentXml(paper, questionText: 'Solve x + 1');
    final edited = exported.replaceFirst(
      '<w:body>',
      '<w:body><w:p><w:r><w:t>Unsupported new paragraph</w:t></w:r></w:p>',
    );
    final bytes = _docxBytes(
      documentXml: edited,
      stylesXml: _stylesXml,
      envelopeXml: SmartPaperDocxRoundTripService.buildEnvelopeXml(
        paper: paper,
        documentXml: exported,
        stylesXml: _stylesXml,
      ),
    );

    final result = SmartPaperDocxRoundTripService.importFromBytes(bytes);

    expect(result.status, SmartPaperDocxImportStatus.modifiedOutsideEduSheet);
    expect(result.paper, isNull);
    expect(result.canApplySafely, isFalse);
  });

  test('style/page companion changes are refused as non-lossless imports', () {
    final paper = _paper();
    final documentXml = _documentXml(paper, questionText: 'Solve x + 1');
    final bytes = _docxBytes(
      documentXml: documentXml,
      stylesXml:
          '<w:styles xmlns:w="$_w"><w:style w:type="paragraph"/></w:styles>',
      envelopeXml: SmartPaperDocxRoundTripService.buildEnvelopeXml(
        paper: paper,
        documentXml: documentXml,
        stylesXml: _stylesXml,
      ),
    );

    final result = SmartPaperDocxRoundTripService.importFromBytes(bytes);

    expect(result.status, SmartPaperDocxImportStatus.modifiedOutsideEduSheet);
    expect(result.paper, isNull);
  });

  test(
    'question text with Math/Geometry embed is never flattened by Word merge',
    () {
      final paper = _paper(withEmbed: true);
      final exported = _documentXml(paper, questionText: 'Solve formula');
      final edited = _documentXml(
        paper,
        questionText: 'Changed formula question',
      );
      final bytes = _docxBytes(
        documentXml: edited,
        stylesXml: _stylesXml,
        envelopeXml: SmartPaperDocxRoundTripService.buildEnvelopeXml(
          paper: paper,
          documentXml: exported,
          stylesXml: _stylesXml,
        ),
      );

      final result = SmartPaperDocxRoundTripService.importFromBytes(bytes);

      expect(result.status, SmartPaperDocxImportStatus.modifiedOutsideEduSheet);
      expect(result.paper, isNull);
      expect(result.message, contains('Math/Geometry'));
    },
  );

  test('ordinary external DOCX is identified without lossy conversion', () {
    const documentXml =
        '<w:document xmlns:w="$_w"><w:body><w:p><w:r><w:t>External document</w:t></w:r></w:p></w:body></w:document>';

    final result = SmartPaperDocxRoundTripService.importFromBytes(
      _docxBytes(documentXml: documentXml, stylesXml: _stylesXml),
    );

    expect(
      result.status,
      SmartPaperDocxImportStatus.unsupportedExternalDocument,
    );
    expect(result.paper, isNull);
  });
}

const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const _stylesXml = '<w:styles xmlns:w="$_w"></w:styles>';

String _documentXml(
  Paper paper, {
  required String questionText,
  bool questionBold = false,
  String marks = '5',
  String? optionText,
}) {
  final question = paper.sections.single.questions.first;
  final questionTag = SmartPaperDocxRoundTripService.questionTextTag(
    question.id,
  );
  final marksTag = SmartPaperDocxRoundTripService.questionMarksTag(question.id);
  final option = question.options.isEmpty ? null : question.options.first;
  final optionTag = option == null
      ? null
      : SmartPaperDocxRoundTripService.questionOptionTag(
          question.id,
          option.id,
        );
  final marksXml = _sdt(marksTag, ' [$marks]');
  final optionXml = option == null
      ? ''
      : '<w:p><w:r><w:t>A) </w:t></w:r>'
            '${_sdt(optionTag!, optionText ?? option.text)}</w:p>';
  return '<w:document xmlns:w="$_w"><w:body>'
      '<w:p><w:r><w:t>1. </w:t></w:r>'
      '${_sdt(questionTag, questionText, bold: questionBold)}'
      '$marksXml'
      '</w:p>'
      '$optionXml'
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/></w:sectPr>'
      '</w:body></w:document>';
}

String _sdt(String tag, String text, {bool bold = false}) {
  return '<w:sdt><w:sdtPr><w:tag w:val="$tag"/></w:sdtPr><w:sdtContent>'
      '<w:r><w:rPr>${bold ? '<w:b/>' : ''}<w:sz w:val="24"/></w:rPr>'
      '<w:t xml:space="preserve">$text</w:t></w:r>'
      '</w:sdtContent></w:sdt>';
}

List<int> _docxBytes({
  required String documentXml,
  required String stylesXml,
  String? envelopeXml,
}) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('word/document.xml', documentXml))
    ..addFile(ArchiveFile.string('word/styles.xml', stylesXml));
  if (envelopeXml != null) {
    archive.addFile(
      ArchiveFile.string(
        SmartPaperDocxRoundTripService.customXmlPartName,
        envelopeXml,
      ),
    );
  }
  return ZipEncoder().encode(archive);
}

Paper _paper({bool withOptions = false, bool withEmbed = false}) {
  final paragraph = WordContentBlockService.paragraph(
    text: 'Teacher free paragraph',
  );
  final expression = MathExpression(
    id: 'math-1',
    latex: r'x^2',
    plainText: 'x²',
  );
  final questionText = withEmbed
      ? jsonEncode([
          {'insert': 'Solve '},
          {
            'insert': {
              MathExpression.quillEmbedKey: expression.toQuillEmbedData(),
            },
          },
          {'insert': '\n'},
        ])
      : jsonEncode([
          {'insert': 'Solve x + 1\n'},
        ]);
  return Paper(
    id: 'round-trip-paper',
    title: 'Round Trip Algebra',
    schoolName: 'EduSheet School',
    instruction: 'Answer carefully.',
    createdAt: DateTime.utc(2026, 8, 31, 12, 30),
    headerText: 'Class X',
    footerText: 'Confidential',
    showPageNumbers: true,
    pageLayout: const PaperPageLayout(
      pageSize: PaperPageSize.a4,
      orientation: PaperPageOrientation.landscape,
      margins: PaperPageMargins(
        topPoints: 40,
        rightPoints: 45,
        bottomPoints: 50,
        leftPoints: 55,
      ),
      lineSpacing: 1.5,
      paragraphSpacingPoints: 8,
      pageNumberPosition: PaperPageNumberPosition.footerRight,
    ),
    sections: [
      PaperSection(
        id: 'section-a',
        title: 'Section A',
        requiredCount: 1,
        questions: [
          Question(
            id: 'q1',
            text: questionText,
            plainTextAccessibility: withEmbed ? 'Solve x²' : 'Solve x + 1',
            marks: 5,
            mathExpressions: withEmbed ? [expression] : const [],
            options: withOptions
                ? [
                    QuestionOption(id: 'o1', text: 'One', isCorrect: true),
                    QuestionOption(id: 'o2', text: 'Two'),
                  ]
                : const [],
            metadata: const {'custom': 'preserve-me'},
          ),
          paragraph,
        ],
      ),
    ],
  );
}
