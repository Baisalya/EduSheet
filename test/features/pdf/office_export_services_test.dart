import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/editor/domain/models/question_option_layout.dart';
import 'package:edusheet/features/geometry_builder/application/geometry_embed_layout.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_mark.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_point.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_shape.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/paper_composer/application/smart_paper_docx_round_trip_service.dart';
import 'package:edusheet/features/paper_composer/application/word_content_block_service.dart';
import 'package:edusheet/features/paper_composer/application/word_shape_service.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:edusheet/features/pdf/application/question_paper_export_service.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/services/export_file_service.dart';
import 'package:edusheet/features/pdf/services/pdf_service.dart';
import 'package:edusheet/features/pdf/services/presentation_export_service.dart';
import 'package:edusheet/features/pdf/services/spreadsheet_export_service.dart';
import 'package:edusheet/features/pdf/services/word_export_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:xml/xml.dart' as xml;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('office_export_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return tempDir.path;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'ExportFileService creates EduSheet folder and unique file names',
    () async {
      final first = await ExportFileService.uniqueFile(
        fileNameBase: 'Algebra Test',
        extension: '.pdf',
      );
      await first.writeAsString('existing');

      final second = await ExportFileService.uniqueFile(
        fileNameBase: 'Algebra Test',
        extension: '.pdf',
      );

      expect(first.path, contains('${Platform.pathSeparator}EduSheet'));
      expect(first.path, endsWith('Algebra Test.pdf'));
      expect(second.path, endsWith('Algebra Test (1).pdf'));
    },
  );

  test('question paper export policy exposes PDF and Word', () {
    expect(
      QuestionPaperExportPolicy.supportedFormats,
      equals({QuestionPaperExportFormat.pdf, QuestionPaperExportFormat.word}),
    );
    expect(
      QuestionPaperExportPolicy.supports(QuestionPaperExportFormat.pdf),
      isTrue,
    );
    expect(
      QuestionPaperExportPolicy.supports(QuestionPaperExportFormat.word),
      isTrue,
    );
  });

  test('question paper export coordinator creates a PDF', () async {
    final output = await QuestionPaperExportService.exportPdf(
      paper: _samplePaper(),
      availableTemplates: [_sampleTemplate()],
    );

    expect(output.path, endsWith('.pdf'));
    expect(await output.exists(), isTrue);
    expect(await output.length(), greaterThan(0));
  });

  test('question paper export coordinator creates a DOCX', () async {
    final output = await QuestionPaperExportService.exportWord(
      paper: _samplePaper(),
      availableTemplates: [_sampleTemplate()],
    );

    expect(output.path, endsWith('.docx'));
    expect(await output.exists(), isTrue);
    final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
    expect(
      _archiveText(archive, 'word/document.xml'),
      contains('Algebra Test'),
    );
  });

  test('Word export preserves sparse header logo slot ordering', () async {
    final logo = File('${tempDir.path}${Platform.pathSeparator}logo.png');
    await logo.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    final paper = _samplePaper().copyWith(logos: ['', logo.path]);
    final template = PaperTemplate(
      id: 'sparse-logo-layout',
      name: 'Sparse logo layout',
      type: TemplateType.school,
      headerLayout: HeaderLayout.custom,
      customLayout: CustomLayout(
        canvasHeight: 80,
        elements: [
          // Slot indexes follow canonical template element order, not the
          // x/y sorting Word uses to serialize the visual header. Slot 0 is
          // intentionally on the right and blank; slot 1 is on the left.
          TemplateElement(
            id: 'logo-right-slot-0',
            type: ElementType.logo,
            x: 170,
            y: 0,
            width: 40,
            height: 40,
          ),
          TemplateElement(
            id: 'between',
            type: ElementType.staticText,
            x: 50,
            y: 0,
            width: 100,
            height: 20,
            content: 'BETWEEN-LOGOS',
          ),
          TemplateElement(
            id: 'logo-left-slot-1',
            type: ElementType.logo,
            x: 0,
            y: 0,
            width: 40,
            height: 40,
          ),
        ],
      ),
    );

    final output = await WordExportService.export(paper, template);
    final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
    final documentXml = _archiveText(archive, 'word/document.xml');
    final markerIndex = documentXml.indexOf('BETWEEN-LOGOS');
    final imageIndex = documentXml.indexOf('<a:blip');

    expect(markerIndex, greaterThanOrEqualTo(0));
    expect(imageIndex, greaterThanOrEqualTo(0));
    expect(imageIndex, lessThan(markerIndex));
  });

  test(
    'Word export embeds an exact EduSheet Smart Paper round-trip envelope',
    () async {
      final paper = _samplePaper();
      final output = await WordExportService.export(paper, _sampleTemplate());
      final archive = ZipDecoder().decodeBytes(await output.readAsBytes());

      expect(
        archive.files.any(
          (entry) =>
              entry.name == SmartPaperDocxRoundTripService.customXmlPartName,
        ),
        isTrue,
      );

      final restored = await SmartPaperDocxRoundTripService.importFromFile(
        output,
      );
      expect(restored.canRestoreExactly, isTrue);
      expect(jsonEncode(restored.paper!.toJson()), jsonEncode(paper.toJson()));
    },
  );

  test(
    'Word export tags supported edits and safely merges them back',
    () async {
      final paper = _samplePaper();
      final output = await WordExportService.export(paper, _sampleTemplate());
      final sourceArchive = ZipDecoder().decodeBytes(
        await output.readAsBytes(),
      );
      final documentXml = _archiveText(sourceArchive, 'word/document.xml');
      final questionTag = SmartPaperDocxRoundTripService.questionTextTag('q1');

      expect(documentXml, contains('w:tag w:val="$questionTag"'));
      expect(documentXml, contains('Solve x + 2 = 5'));

      final editedDocumentXml = documentXml.replaceFirst(
        'Solve x + 2 = 5',
        'Solve x + 4 = 9',
      );
      final editedArchive = Archive();
      for (final entry in sourceArchive.files) {
        final bytes = List<int>.from(entry.content as List<int>);
        if (entry.name == 'word/document.xml') {
          editedArchive.addFile(
            ArchiveFile.string('word/document.xml', editedDocumentXml),
          );
        } else {
          editedArchive.addFile(ArchiveFile.bytes(entry.name, bytes));
        }
      }

      final result = SmartPaperDocxRoundTripService.importFromBytes(
        ZipEncoder().encode(editedArchive),
      );
      expect(
        result.status,
        SmartPaperDocxImportStatus.safeMergedEduSheetRoundTrip,
      );
      expect(
        result.paper!.sections.single.questions.single.plainTextAccessibility,
        'Solve x + 4 = 9',
      );
      expect(result.paper!.sections.single.questions.single.marks, 2);
      expect(result.paper!.pageLayout.toJson(), paper.pageLayout.toJson());
    },
  );

  test(
    'WordExportService saves custom file names inside EduSheet folder',
    () async {
      final output = await WordExportService.export(
        _samplePaper(),
        _sampleTemplate(),
        fileNameBase: 'Class 10 Exam',
      );
      final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
      final documentXml = _archiveText(archive, 'word/document.xml');

      expect(output.path, contains('${Platform.pathSeparator}EduSheet'));
      expect(output.path, endsWith('Class 10 Exam.docx'));
      expect(documentXml, contains('Algebra Test'));
      expect(documentXml, contains('Solve x + 2 = 5'));
    },
  );

  test(
    'Word student document keeps marks diagnostics out of printable content',
    () async {
      final paper = _samplePaper().copyWith(maximumMarks: 10);
      final output = await WordExportService.export(paper, _sampleTemplate());
      final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
      final documentXml = _archiveText(archive, 'word/document.xml');

      expect(documentXml, contains('Maximum Marks: 10'));
      expect(_occurrences(documentXml, 'Maximum Marks:'), 1);
      expect(documentXml, isNot(contains('Assigned marks')));
      expect(documentXml, isNot(contains('marks are not assigned yet')));
    },
  );

  test(
    'Word export preserves smart section formatting and option layout',
    () async {
      final paper = Paper(
        id: 'smart-format-paper',
        title: 'Smart Format',
        createdAt: DateTime(2026, 8, 31),
        sections: [
          PaperSection(
            id: 'section-a',
            title: 'Section A',
            requiredCount: 1,
            numberingStyle: QuestionNumberStyle.lowerAlpha,
            pageBreakBefore: true,
            answerSpaceLines: 2,
            ruledAnswerArea: true,
            questions: [
              Question(
                id: 'q1',
                text: 'Pick one',
                type: QuestionType.mcq,
                options: [
                  QuestionOption(id: 'a', text: 'One'),
                  QuestionOption(id: 'b', text: 'Two'),
                ],
                metadata: const {
                  QuestionOptionLayoutCodec.metadataKey: 'inline',
                },
              ),
              Question(id: 'q2', text: 'Explain why'),
            ],
          ),
        ],
      );

      final output = await WordExportService.export(paper, _sampleTemplate());
      final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
      final documentXml = _archiveText(archive, 'word/document.xml');

      expect(documentXml, contains('<w:br w:type="page"/>'));
      expect(documentXml, contains('Answer any 1 of 2 questions.'));
      expect(documentXml, contains('a. '));
      expect(
        documentXml,
        contains(SmartPaperDocxRoundTripService.questionOptionTag('q1', 'a')),
      );
      expect(
        documentXml,
        contains(SmartPaperDocxRoundTripService.questionOptionTag('q1', 'b')),
      );
      final renderedText = xml.XmlDocument.parse(
        documentXml,
      ).rootElement.innerText;
      expect(renderedText, contains('A) One     B) Two'));
      expect(documentXml, contains('________________________________________'));
    },
  );

  test('Word export preserves Phase 2 professional section styling', () async {
    final paper = Paper(
      id: 'professional-phase2',
      title: 'Professional Phase 2',
      createdAt: DateTime(2026, 9, 1),
      sections: [
        PaperSection(
          id: 'section-a',
          title: 'Section A',
          prefix: 'Part I',
          headingBold: true,
          headingUppercase: true,
          headingBoxed: true,
          headingSize: SectionHeadingSize.large,
          spacing: SectionSpacing.compact,
          sectionMarksDisplay: SectionMarksDisplay.right,
          questionMarksPlacement: QuestionMarksPlacement.rightEdge,
          keepTogether: true,
          questions: [Question(id: 'q1', text: 'Explain gravity.', marks: 5)],
        ),
      ],
    );

    final output = await WordExportService.export(paper, _sampleTemplate());
    final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
    final documentXml = _archiveText(archive, 'word/document.xml');
    final renderedText = xml.XmlDocument.parse(
      documentXml,
    ).rootElement.innerText;

    expect(renderedText, contains('Part I Section A'));
    expect(documentXml, contains('<w:caps/>'));
    expect(renderedText, contains('5 Marks'));
    expect(documentXml, contains('<w:keepNext/>'));
    expect(documentXml, contains('<w:pBdr>'));
    expect(documentXml, contains('<w:tab/>'));
    expect(documentXml, contains('w:val="right"'));
  });

  test('Word export preserves advanced paper content blocks', () async {
    final output = await WordExportService.export(
      _advancedPaper(),
      _sampleTemplate(),
      fileNameBase: 'Advanced Paper Blocks',
    );
    final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
    final documentXml = _archiveText(archive, 'word/document.xml');

    expect(documentXml, contains('Read the source and answer.'));
    expect(documentXml, contains('Rainfall case study'));
    expect(documentXml, contains('Village A received 40 mm of rain.'));
    expect(documentXml, contains('increase     decrease     unchanged'));
    expect(documentXml, contains('Observation table'));
    expect(documentXml, contains('(a) '));
    expect(documentXml, contains('Calculate the difference.'));
    expect(documentXml, contains('OR'));
    expect(documentXml, contains('Use a bar graph.'));
  });

  test(
    'Word export applies Step 9 page layout, header/footer and page fields',
    () async {
      final pageBreak = WordContentBlockService.pageBreak();
      final paper = Paper(
        id: 'step9-layout-paper',
        title: 'Step 9 Layout',
        headerText: 'Class X Mathematics',
        footerText: 'EduSheet School',
        showPageNumbers: true,
        pageLayout: const PaperPageLayout(
          pageSize: PaperPageSize.letter,
          orientation: PaperPageOrientation.landscape,
          margins: PaperPageMargins(
            topPoints: 54,
            rightPoints: 36,
            bottomPoints: 72,
            leftPoints: 45,
          ),
          headerDistancePoints: 20,
          footerDistancePoints: 24,
          lineSpacing: 1.5,
          paragraphSpacingPoints: 9,
          pageNumberPosition: PaperPageNumberPosition.footerRight,
        ),
        createdAt: DateTime(2026, 8, 31),
        sections: [
          PaperSection(
            id: 'section-a',
            title: 'Section A',
            questions: [
              Question(id: 'q1', text: 'Before break', marks: 2),
              pageBreak,
              Question(id: 'q2', text: 'After break', marks: 3),
            ],
          ),
        ],
      );

      final output = await WordExportService.export(paper, _sampleTemplate());
      final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
      final documentXml = _archiveText(archive, 'word/document.xml');
      final relsXml = _archiveText(archive, 'word/_rels/document.xml.rels');
      final contentTypes = _archiveText(archive, '[Content_Types].xml');
      final stylesXml = _archiveText(archive, 'word/styles.xml');
      final headerXml = _archiveText(archive, 'word/header1.xml');
      final footerXml = _archiveText(archive, 'word/footer1.xml');

      expect(
        documentXml,
        contains('<w:pgSz w:w="15840" w:h="12240" w:orient="landscape"/>'),
      );
      expect(documentXml, contains('w:top="1080"'));
      expect(documentXml, contains('w:right="720"'));
      expect(documentXml, contains('w:bottom="1440"'));
      expect(documentXml, contains('w:left="900"'));
      expect(documentXml, contains('w:header="400"'));
      expect(documentXml, contains('w:footer="480"'));
      expect(_occurrences(documentXml, '<w:br w:type="page"/>'), 1);
      expect(documentXml, contains('Before break'));
      expect(documentXml, contains('After break'));
      expect(relsXml, contains('relationships/header'));
      expect(relsXml, contains('relationships/footer'));
      expect(relsXml, contains('relationships/styles'));
      expect(contentTypes, contains('/word/header1.xml'));
      expect(contentTypes, contains('/word/footer1.xml'));
      expect(stylesXml, contains('w:line="360"'));
      expect(stylesXml, contains('w:after="180"'));
      expect(headerXml, contains('Class X Mathematics'));
      expect(footerXml, contains('EduSheet School'));
      expect(footerXml, contains(' PAGE '));
      expect(footerXml, contains(' NUMPAGES '));
    },
  );

  test(
    'Word export preserves free Word Mode content without assessment chrome',
    () async {
      final freeParagraph = WordContentBlockService.paragraph(
        text: 'Custom teacher note between questions.',
      );
      final paper = Paper(
        id: 'word-mode-free-content',
        title: 'Word Mode Paper',
        createdAt: DateTime(2026, 8, 31),
        sections: [
          PaperSection(
            id: 'section-a',
            title: 'Section A',
            questions: [
              Question(id: 'q1', text: 'First question', marks: 2),
              freeParagraph,
              Question(id: 'q2', text: 'Second question', marks: 3),
            ],
          ),
        ],
      );

      final output = await WordExportService.export(paper, _sampleTemplate());
      final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
      final documentXml = _archiveText(archive, 'word/document.xml');

      expect(documentXml, contains('Custom teacher note between questions.'));
      expect(documentXml, contains('First question'));
      expect(documentXml, contains('Second question'));
      expect(documentXml, isNot(contains('[0]')));
    },
  );

  test('PDF export accepts advanced paper content blocks', () async {
    final output = await PdfService.export(
      _advancedPaper(),
      _sampleTemplate(),
      fileNameBase: 'Advanced Paper Blocks PDF',
    );

    expect(output.path, endsWith('Advanced Paper Blocks PDF.pdf'));
    expect(await output.exists(), isTrue);
    expect(await output.length(), greaterThan(0));
  });

  test('PdfService exports a PDF file inside EduSheet folder', () async {
    final output = await PdfService.export(
      _samplePaper(),
      _sampleTemplate(),
      fileNameBase: 'Printable Algebra',
    );

    expect(output.path, contains('${Platform.pathSeparator}EduSheet'));
    expect(output.path, endsWith('Printable Algebra.pdf'));
    expect(await output.exists(), isTrue);
    expect(await output.length(), greaterThan(0));
  });

  test(
    'SpreadsheetExportService creates workbook sheets with paper data',
    () async {
      final output = await SpreadsheetExportService.export(
        _samplePaper(),
        _sampleTemplate(),
      );
      final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
      final names = archive.files.map((file) => file.name).toSet();
      final workbookXml = _archiveText(archive, 'xl/workbook.xml');
      final summaryXml = _archiveText(archive, 'xl/worksheets/sheet1.xml');
      final questionsXml = _archiveText(archive, 'xl/worksheets/sheet2.xml');
      final optionsXml = _archiveText(archive, 'xl/worksheets/sheet3.xml');

      expect(output.path, endsWith('.xlsx'));
      expect(names, contains('[Content_Types].xml'));
      expect(names, contains('xl/workbook.xml'));
      expect(names, contains('xl/worksheets/sheet1.xml'));
      expect(names, contains('xl/worksheets/sheet2.xml'));
      expect(names, contains('xl/worksheets/sheet3.xml'));
      expect(workbookXml, contains('Summary'));
      expect(workbookXml, contains('Questions'));
      expect(workbookXml, contains('Options'));
      expect(summaryXml, contains('Algebra Test'));
      expect(summaryXml, contains('Sample School'));
      expect(questionsXml, contains('Solve x + 2 = 5'));
      expect(questionsXml, contains('MCQ'));
      expect(optionsXml, contains('3'));
      expect(optionsXml, contains('Correct'));
    },
  );

  test(
    'PresentationExportService creates editable slides with paper data',
    () async {
      final output = await PresentationExportService.export(
        _samplePaper(),
        _sampleTemplate(),
      );
      final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
      final names = archive.files.map((file) => file.name).toSet();
      final presentationXml = _archiveText(archive, 'ppt/presentation.xml');
      final titleSlideXml = _archiveText(archive, 'ppt/slides/slide1.xml');
      final sectionSlideXml = _archiveText(archive, 'ppt/slides/slide2.xml');
      final questionSlideXml = _archiveText(archive, 'ppt/slides/slide3.xml');

      expect(output.path, endsWith('.pptx'));
      expect(names, contains('[Content_Types].xml'));
      expect(names, contains('ppt/presentation.xml'));
      expect(names, contains('ppt/slides/slide1.xml'));
      expect(names, contains('ppt/slides/slide2.xml'));
      expect(names, contains('ppt/slides/slide3.xml'));
      expect(names, contains('ppt/slideMasters/slideMaster1.xml'));
      expect(presentationXml, contains('p:sldIdLst'));
      expect(titleSlideXml, contains('Algebra Test'));
      expect(titleSlideXml, contains('Sample School'));
      expect(sectionSlideXml, contains('Section A'));
      expect(questionSlideXml, contains('Solve x + 2 = 5'));
      expect(questionSlideXml, contains('3'));
    },
  );
  test(
    'Phase 4B Word export preserves editable shapes, wrapping and layers',
    () async {
      var question = _samplePaper().sections.single.questions.single;
      question = WordShapeService.append(
        question,
        WordShapeService.create(WordShapeKind.textBox).copyWith(
          text: 'Important note',
          wrapMode: WordTextWrapMode.squareLeft,
          zIndex: 4,
        ),
      );
      question = WordShapeService.append(
        question,
        WordShapeService.create(
          WordShapeKind.arrow,
        ).copyWith(wrapMode: WordTextWrapMode.inFrontOfText, zIndex: 8),
      );
      question = WordShapeService.append(
        question,
        WordShapeService.create(
          WordShapeKind.ellipse,
        ).copyWith(wrapMode: WordTextWrapMode.behindText, zIndex: -2),
      );
      final paper = _samplePaper().copyWith(
        sections: [
          _samplePaper().sections.single.copyWith(questions: [question]),
        ],
      );

      final output = await WordExportService.export(paper, _sampleTemplate());
      final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
      final documentXml = _archiveText(archive, 'word/document.xml');

      expect(documentXml, contains('xmlns:v="urn:schemas-microsoft-com:vml"'));
      expect(documentXml, contains('edusheet_shape_'));
      expect(documentXml, contains('<v:textbox'));
      expect(documentXml, contains('Important note'));
      expect(documentXml, contains('mso-wrap-style:square'));
      expect(documentXml, contains('z-index:-251658240'));
      expect(documentXml, contains('z-index:251658248'));
      expect(documentXml, contains('endarrow="block"'));
    },
  );

  test('Phase 4B PDF export accepts wrapped and layered shapes', () async {
    var question = _samplePaper().sections.single.questions.single;
    for (final entry in <(WordShapeKind, WordTextWrapMode)>[
      (WordShapeKind.rectangle, WordTextWrapMode.squareLeft),
      (WordShapeKind.roundedRectangle, WordTextWrapMode.squareRight),
      (WordShapeKind.ellipse, WordTextWrapMode.topAndBottom),
      (WordShapeKind.arrow, WordTextWrapMode.inFrontOfText),
      (WordShapeKind.callout, WordTextWrapMode.behindText),
    ]) {
      question = WordShapeService.append(
        question,
        WordShapeService.create(entry.$1).copyWith(
          wrapMode: entry.$2,
          text: entry.$1 == WordShapeKind.callout ? 'Remember' : '',
        ),
      );
    }
    final paper = _samplePaper().copyWith(
      sections: [
        _samplePaper().sections.single.copyWith(questions: [question]),
      ],
    );

    final output = await QuestionPaperExportService.exportPdf(
      paper: paper,
      availableTemplates: [_sampleTemplate()],
    );
    expect(await output.exists(), isTrue);
    expect(await output.length(), greaterThan(0));
  });

  test(
    'Phase 4C Word export preserves vector geometry placement metadata',
    () async {
      final diagram = _phase4cGeometryDiagram();
      final layout = GeometryEmbedLayout(
        id: diagram.id,
        diagram: diagram,
        height: 240,
        widthFactor: 0.65,
        marginTop: 6,
        marginBottom: 18,
        wrapMode: GeometryEmbedWrapMode.squareLeft,
      );
      final base = _samplePaper();
      final question = base.sections.single.questions.single.copyWith(
        text: jsonEncode([
          {'insert': 'Use the diagram.\n'},
          {
            'insert': {'geometry': layout.encode()},
          },
          {'insert': '\nState the result.\n'},
        ]),
      );
      final paper = base.copyWith(
        sections: [
          base.sections.single.copyWith(questions: [question]),
        ],
      );

      final output = await WordExportService.export(paper, _sampleTemplate());
      final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
      final documentXml = _archiveText(archive, 'word/document.xml');

      expect(documentXml, contains('edusheet_geometry_${diagram.id}'));
      expect(documentXml, contains('<v:group'));
      expect(documentXml, contains('mso-wrap-style:square'));
      expect(documentXml, contains('float:left'));
      expect(documentXml, contains('endarrow="block"'));
      expect(documentXml, contains('>A<'));
      expect(documentXml, isNot(contains('[diagram]')));

      final restored = await SmartPaperDocxRoundTripService.importFromFile(
        output,
      );
      expect(restored.canRestoreExactly, isTrue);
      expect(
        geometryEmbedsFromQuillText(
          restored.paper!.sections.single.questions.single.text,
        ).single.diagram?.toJson(),
        diagram.toJson(),
      );
    },
  );

  test(
    'Phase 4C PDF export renders canonical geometry instead of placeholder',
    () async {
      final diagram = _phase4cGeometryDiagram();
      final base = _samplePaper();
      final question = base.sections.single.questions.single.copyWith(
        text: jsonEncode([
          {'insert': 'Use the construction.\n'},
          {
            'insert': {
              'geometry': GeometryEmbedLayout(
                id: diagram.id,
                diagram: diagram,
                height: 220,
                widthFactor: 0.75,
                wrapMode: GeometryEmbedWrapMode.topAndBottom,
              ).encode(),
            },
          },
          {'insert': '\nAnswer below.\n'},
        ]),
      );
      final paper = base.copyWith(
        sections: [
          base.sections.single.copyWith(questions: [question]),
        ],
      );

      final output = await QuestionPaperExportService.exportPdf(
        paper: paper,
        availableTemplates: [_sampleTemplate()],
      );
      expect(await output.exists(), isTrue);
      expect(await output.length(), greaterThan(0));
      final bytes = await output.readAsBytes();
      expect(
        utf8.decode(bytes, allowMalformed: true),
        isNot(contains('[diagram]')),
      );
    },
  );
}

Paper _advancedPaper() {
  const advanced = QuestionAdvancedContent(
    stimulus: QuestionStimulus(
      kind: QuestionStimulusKind.caseStudy,
      title: 'Rainfall case study',
      text: 'Village A received 40 mm of rain.',
    ),
    wordBank: ['increase', 'decrease', 'unchanged'],
    answerSpace: QuestionAnswerSpace(
      style: QuestionAnswerSpaceStyle.box,
      lines: 3,
    ),
  );
  return Paper(
    id: 'advanced-paper',
    title: 'Advanced Paper Blocks',
    createdAt: DateTime(2026, 8, 31),
    sections: [
      PaperSection(
        id: 'advanced-section',
        title: 'Section A',
        questions: [
          Question(
            id: 'advanced-q',
            text: 'Read the source and answer.',
            marks: 5,
            tableData: const QuestionTable(
              headers: ['Village', 'Rainfall'],
              rows: [
                ['A', '40 mm'],
                ['B', '25 mm'],
              ],
              caption: 'Observation table',
            ),
            subQuestions: [
              Question(
                id: 'advanced-part-a',
                text: 'Calculate the difference.',
                marks: 2,
              ),
            ],
            internalChoices: [
              Question(
                id: 'advanced-or-a',
                text: 'Explain the trend.',
                marks: 3,
              ),
              Question(id: 'advanced-or-b', text: 'Use a bar graph.', marks: 3),
            ],
            metadata: advanced.writeToMetadata(const {}),
          ),
        ],
      ),
    ],
  );
}

GeometryDiagram _phase4cGeometryDiagram() {
  return const GeometryDiagram(
    id: 'phase4c-export-geometry',
    points: [
      GeometryPoint(id: 'a', label: 'A', position: Offset(100, 120)),
      GeometryPoint(id: 'b', label: 'B', position: Offset(190, 120)),
      GeometryPoint(id: 'c', label: 'C', position: Offset(100, 40)),
      GeometryPoint(id: 'top', label: '', position: Offset(260, 30)),
      GeometryPoint(id: 'bottom', label: '', position: Offset(260, 190)),
      GeometryPoint(id: 'left', label: '', position: Offset(190, 110)),
      GeometryPoint(id: 'right', label: '', position: Offset(330, 110)),
      GeometryPoint(id: 'n1', label: '', position: Offset(30, 210)),
      GeometryPoint(id: 'n2', label: '', position: Offset(330, 210)),
    ],
    shapes: [
      GeometryShape(
        id: 'arrow',
        type: GeometryShapeType.arrow,
        pointIds: ['a', 'b'],
      ),
      GeometryShape(
        id: 'line',
        type: GeometryShapeType.line,
        pointIds: ['a', 'c'],
      ),
      GeometryShape(
        id: 'axes',
        type: GeometryShapeType.coordinateAxes,
        pointIds: ['top', 'bottom', 'left', 'right'],
      ),
      GeometryShape(
        id: 'number-line',
        type: GeometryShapeType.numberLine,
        pointIds: ['n1', 'n2'],
      ),
    ],
    marks: [
      GeometryMark(
        id: 'angle',
        type: GeometryMarkType.angleArc,
        pointIds: ['a', 'b', 'c'],
        position: Offset(100, 120),
      ),
    ],
  );
}

Paper _samplePaper() {
  return Paper(
    id: 'paper-1',
    title: 'Algebra Test',
    schoolName: 'Sample School',
    instruction: 'Answer carefully.',
    createdAt: DateTime.now(),
    headerFields: [
      PaperHeaderField(id: 'subject', label: 'Subject', value: 'Math'),
    ],
    sections: [
      PaperSection(
        id: 'section-a',
        title: 'Section A',
        prefix: 'A.',
        requiredCount: 1,
        questions: [
          Question(
            id: 'q1',
            text: jsonEncode([
              {'insert': 'Solve x + 2 = 5\n'},
            ]),
            type: QuestionType.mcq,
            marks: 2,
            options: [
              QuestionOption(id: 'a', text: '2'),
              QuestionOption(id: 'b', text: '3', isCorrect: true),
            ],
          ),
        ],
      ),
    ],
  );
}

PaperTemplate _sampleTemplate() {
  return PaperTemplate(
    id: 'template-1',
    name: 'Sample Template',
    type: TemplateType.school,
    primaryColor: PdfColors.black,
  );
}

String _archiveText(Archive archive, String name) {
  final file = archive.files.firstWhere((entry) => entry.name == name);
  return utf8.decode(file.content as List<int>);
}

int _occurrences(String source, String pattern) {
  if (pattern.isEmpty) return 0;
  var count = 0;
  var offset = 0;
  while (true) {
    final index = source.indexOf(pattern, offset);
    if (index < 0) return count;
    count++;
    offset = index + pattern.length;
  }
}
