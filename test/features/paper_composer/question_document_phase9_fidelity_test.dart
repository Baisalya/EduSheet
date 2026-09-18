import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/geometry_builder/application/geometry_embed_layout.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_label.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_point.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_shape.dart';
import 'package:edusheet/features/geometry_builder/services/geometry_svg_service.dart';
import 'package:edusheet/features/paper_composer/application/paper_export_fidelity_audit.dart';
import 'package:edusheet/features/paper_composer/application/word_content_block_service.dart';
import 'package:edusheet/features/paper_composer/application/word_shape_service.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_preview_page.dart';
import 'package:edusheet/features/pdf/data/repositories/template_repository.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:edusheet/features/pdf/services/pdf_service.dart';
import 'package:edusheet/features/paper_composer/application/smart_paper_docx_round_trip_service.dart';
import 'package:edusheet/features/pdf/services/word_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDirectory;
  late TemplateRepository templateRepository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'edusheet-phase9-fidelity-',
    );
    templateRepository = TemplateRepository(
      fileResolver: () async =>
          File('${tempDirectory.path}${Platform.pathSeparator}templates.json'),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return tempDirectory.path;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('Phase 9 production audit accepts the canonical fidelity fixture', () {
    final report = PaperExportFidelityAudit.audit(_phase9Paper());

    expect(report.productionReady, isTrue);
    expect(report.blockingIssues, isEmpty);
    expect(report.warnings, isEmpty);
  });

  test('Phase 9 audit blocks malformed or unsafe printable structures', () {
    final unsafeShape = const WordShapeObject(
      id: 'duplicate-object',
      kind: WordShapeKind.geometry,
      x: 0.90,
      y: 0.90,
      width: 0.35,
      height: 0.35,
    );
    final question = Question(
      id: 'unsafe-question',
      text: '[broken-json',
      metadata: {
        WordShapeService.metadataKey: [
          unsafeShape.toJson(),
          unsafeShape.copyWith(kind: WordShapeKind.rectangle).toJson(),
        ],
        WordShapeService.metadataVersionKey: 3,
      },
    );
    final paper = Paper(
      id: 'unsafe-paper',
      title: 'Unsafe',
      createdAt: DateTime(2026, 9, 18),
      pageLayout: const PaperPageLayout(pageSize: PaperPageSize.a5),
      sections: [
        PaperSection(id: 'unsafe-section', title: 'Unsafe', questions: [question]),
      ],
    );

    final report = PaperExportFidelityAudit.audit(paper);
    final codes = report.blockingIssues.map((issue) => issue.code).toSet();

    expect(report.productionReady, isFalse);
    expect(codes, contains('malformed-rich-text'));
    expect(codes, contains('duplicate-floating-object-id'));
    expect(codes, contains('geometry-payload-missing'));
    expect(codes, contains('floating-object-outside-printable-bounds'));
  });

  test(
    'Phase 9 geometry PDF vector layer contains no Helvetica SVG text',
    () {
      final diagram = _geometry();
      final vectorOnly = GeometrySvgService().toSvg(
        diagram,
        includeText: false,
      );
      final editableSvg = GeometrySvgService().toSvg(diagram);

      expect(vectorOnly, isNot(contains('<text')));
      expect(vectorOnly, isNot(contains('font-family="Helvetica"')));
      expect(editableSvg, contains('<text'));
      expect(editableSvg, contains('हिन्दी'));
      expect(editableSvg, contains('ଓଡ଼ିଆ'));
    },
  );

  testWidgets(
    'Phase 9 preview exposes print content without editor-only chrome',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1500, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final paper = _phase9Paper();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateRepositoryProvider.overrideWithValue(templateRepository),
          ],
          child: MaterialApp(home: PaperPreviewPage(paper: paper)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('paper-preview-document')), findsOneWidget);
      expect(find.byKey(const Key('paper-page-watermark')), findsOneWidget);
      expect(find.byKey(const Key('word-page-layout-guides')), findsNothing);
      expect(
        find.byKey(const Key('paper-preview-page-break-seam')),
        findsOneWidget,
      );
      expect(find.text('Page break'), findsNothing);
      expect(find.textContaining('Geometry Studio'), findsNothing);
      expect(find.textContaining('Top & bottom'), findsNothing);
      expect(find.textContaining('Move with question'), findsNothing);
      expect(find.textContaining('Stay on this page'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Phase 9 Preview/PDF/DOCX production fixture preserves canonical content',
    () async {
      final paper = _phase9Paper();
      final template = _template();

      final pdfFile = await PdfService.export(
        paper,
        template,
        fileNameBase: 'Phase 9 Fidelity PDF',
      );
      final pdfDocument = sf.PdfDocument(inputBytes: await pdfFile.readAsBytes());
      addTearDown(pdfDocument.dispose);
      final pdfText = _normalize(
        sf.PdfTextExtractor(pdfDocument).extractText(),
      );

      expect(pdfDocument.pages.count, greaterThanOrEqualTo(2));
      expect(pdfText, contains('Unicode fidelity'));
      expect(pdfText, contains('हिन्दी'));
      expect(pdfText, contains('ଓଡ଼ିଆ'));
      expect(pdfText, contains('Floating note'));
      expect(pdfText, isNot(contains('[diagram]')));
      expect(pdfText, isNot(contains('Geometry Studio')));
      expect(pdfText, isNot(contains('Top & bottom')));
      expect(pdfText, isNot(contains('Move with question')));
      expect(pdfText, isNot(contains('Stay on this page')));

      final wordFile = await WordExportService.export(
        paper,
        template,
        fileNameBase: 'Phase 9 Fidelity Word',
      );
      final archive = ZipDecoder().decodeBytes(await wordFile.readAsBytes());
      final documentXml = _archiveText(archive, 'word/document.xml');
      final wordXmlBundle = _wordXmlBundle(archive);

      expect(documentXml, contains('Unicode fidelity'));
      expect(documentXml, contains('हिन्दी'));
      expect(documentXml, contains('ଓଡ଼ିଆ'));
      expect(documentXml, contains('Floating note'));
      expect(documentXml, contains('<w:br w:type="page"/>'));
      expect(documentXml, contains('<w:cols w:num="2"'));
      expect(documentXml, contains('<w:background w:color="FFFDF5"/>'));
      expect(documentXml, contains('edusheet_geometry_object_phase9-floating-geometry'));
      expect(documentXml, contains('mso-position-horizontal-relative:page'));
      expect(documentXml, contains('mso-position-vertical-relative:page'));
      expect(wordXmlBundle, contains('PHASE 9 DRAFT'));
      expect(wordXmlBundle, contains('PAGE'));
      expect(wordXmlBundle, isNot(contains('[diagram]')));
      expect(wordXmlBundle, isNot(contains('Geometry Studio')));
      expect(wordXmlBundle, isNot(contains('Top & bottom')));
      expect(wordXmlBundle, isNot(contains('Move with question')));
      expect(wordXmlBundle, isNot(contains('Stay on this page')));
      expect(wordXmlBundle, isNot(contains('word-page-layout-guides')));

      final restored = await SmartPaperDocxRoundTripService.importFromFile(
        wordFile,
      );
      expect(restored.canRestoreExactly, isTrue);
      expect(
        jsonEncode(restored.paper!.toJson()),
        jsonEncode(paper.toJson()),
      );
    },
  );
}

Paper _phase9Paper() {
  final diagram = _geometry();
  final embed = GeometryEmbedLayout(
    id: 'phase9-inline-geometry',
    diagram: diagram,
    height: 220,
    widthFactor: 0.72,
    marginTop: 6,
    marginBottom: 12,
    wrapMode: GeometryEmbedWrapMode.topAndBottom,
  );

  final firstQuestion = Question(
    id: 'phase9-q1',
    text: jsonEncode([
      {'insert': 'Unicode fidelity — हिन्दी गणित — ଓଡ଼ିଆ ପ୍ରଶ୍ନ.\n'},
      {
        'insert': {'geometry': embed.encode()},
      },
      {'insert': '\nUse the labelled construction and explain the result.\n'},
    ]),
    plainTextAccessibility:
        'Unicode fidelity — हिन्दी गणित — ଓଡ଼ିଆ ପ୍ରଶ୍ନ. Use the labelled construction and explain the result.',
    marks: 4,
  );

  var secondQuestion = Question(
    id: 'phase9-q2',
    text: jsonEncode([
      {'insert': 'Second page verification with √x, θ and π.\n'},
    ]),
    plainTextAccessibility: 'Second page verification with square root x theta and pi.',
    marks: 6,
  );
  secondQuestion = WordShapeService.append(
    secondQuestion,
    const WordShapeObject(
      id: 'phase9-text-box',
      kind: WordShapeKind.textBox,
      x: 0.08,
      y: 0.12,
      width: 0.34,
      height: 0.20,
      zIndex: 2,
      text: 'Floating note',
      borderVisible: true,
      fillColorArgb: 0xFFFFFFFF,
      fillOpacity: 0.25,
      padding: 8,
      wrapMode: WordTextWrapMode.inFrontOfText,
    ),
  );
  secondQuestion = WordShapeService.append(
    secondQuestion,
    WordShapeService.createGeometry(diagram).copyWith(
      id: 'phase9-floating-geometry',
      x: 0.48,
      y: 0.18,
      width: 0.44,
      height: 0.30,
      zIndex: 5,
      anchorMode: WordObjectAnchorMode.fixedOnPage,
      fixedPageIndex: 1,
    ),
  );

  final pageBreak = WordContentBlockService.pageBreak().copyWith(
    id: 'phase9-page-break',
  );

  return Paper(
    id: 'phase9-paper',
    title: 'Phase 9 Production Fidelity',
    schoolName: 'EduSheet School',
    instruction: 'Answer all questions.',
    templateId: 'phase9-template',
    headerText: 'Phase 9 Header',
    footerText: 'Phase 9 Footer',
    showPageNumbers: true,
    maximumMarks: 10,
    createdAt: DateTime(2026, 9, 18),
    pageLayout: const PaperPageLayout(
      pageSize: PaperPageSize.a4,
      orientation: PaperPageOrientation.portrait,
      margins: PaperPageMargins(
        topPoints: 36,
        rightPoints: 40,
        bottomPoints: 42,
        leftPoints: 40,
      ),
      columns: PaperPageColumns.two,
      columnSpacingPoints: 18,
      watermarkText: 'PHASE 9 DRAFT',
      watermarkOpacity: 0.10,
      pageBackgroundArgb: 0xFFFFFDF5,
      showRulers: true,
      showGrid: true,
      gridSpacingPoints: 18,
    ),
    sections: [
      PaperSection(
        id: 'phase9-section',
        title: 'Section A',
        questions: [firstQuestion, pageBreak, secondQuestion],
      ),
    ],
  );
}

GeometryDiagram _geometry() {
  return const GeometryDiagram(
    id: 'phase9-geometry',
    name: 'Unicode geometry',
    canvasSize: Size(320, 220),
    showGrid: false,
    points: [
      GeometryPoint(id: 'a', label: 'A', position: Offset(60, 170)),
      GeometryPoint(id: 'b', label: 'B', position: Offset(250, 170)),
      GeometryPoint(id: 'c', label: 'ଓ', position: Offset(155, 45)),
    ],
    shapes: [
      GeometryShape(
        id: 'triangle',
        type: GeometryShapeType.triangle,
        pointIds: ['a', 'b', 'c'],
      ),
    ],
    labels: [
      GeometryLabel(
        id: 'hindi-label',
        type: GeometryLabelType.custom,
        text: 'हिन्दी',
        position: Offset(112, 205),
        fontSize: 14,
      ),
      GeometryLabel(
        id: 'odia-label',
        type: GeometryLabelType.custom,
        text: 'ଓଡ଼ିଆ',
        position: Offset(196, 205),
        fontSize: 14,
      ),
    ],
  );
}

PaperTemplate _template() {
  return const PaperTemplate(
    id: 'phase9-template',
    name: 'Phase 9 Template',
    type: TemplateType.school,
    paperLayout: PaperLayout.standard,
    paperSize: PaperSize.a4,
    hasBorder: true,
  );
}

String _archiveText(Archive archive, String name) {
  final file = archive.files.firstWhere((entry) => entry.name == name);
  return utf8.decode(file.content as List<int>);
}

String _wordXmlBundle(Archive archive) {
  return archive.files
      .where(
        (entry) =>
            entry.name.startsWith('word/') && entry.name.endsWith('.xml'),
      )
      .map((entry) => utf8.decode(entry.content as List<int>))
      .join('\n');
}

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
