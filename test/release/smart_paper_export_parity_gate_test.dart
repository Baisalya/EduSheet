import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_preview_page.dart';
import 'package:edusheet/features/pdf/data/repositories/template_repository.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:edusheet/features/pdf/services/pdf_service.dart';
import 'package:edusheet/features/pdf/services/word_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:xml/xml.dart';

import '../support/smart_paper_release_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDirectory;
  late TemplateRepository templateRepository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'edusheet-release-export-',
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

  testWidgets(
    'preview exposes the same advanced semantic content used for export',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1500, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final paper = SmartPaperReleaseFixture.paper();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateRepositoryProvider.overrideWithValue(templateRepository),
          ],
          child: MaterialApp(home: PaperPreviewPage(paper: paper)),
        ),
      );
      await tester.pumpAndSettle();

      final document = find.byKey(const Key('paper-preview-document'));
      expect(document, findsOneWidget);

      // Preview formatting is allowed to compose a semantic value from multiple
      // visual tokens (for example, "A." + "Section A"). Validate the readable
      // document text rather than requiring every marker to be its own Text
      // widget.
      final previewText = _normalizeSemanticText(
        tester
            .widgetList<Text>(
              find.descendant(of: document, matching: find.byType(Text)),
            )
            .map(_textValue)
            .join(' '),
      );
      for (final marker in SmartPaperReleaseFixture.semanticMarkers) {
        final normalizedMarker = _normalizeSemanticText(marker);
        if (previewText.contains(normalizedMarker)) continue;

        // Rich question bodies are rendered by Quill/RenderEditable, not Text
        // widgets. The production preview exposes those bodies through an
        // explicit accessibility label, so validate that semantic surface rather
        // than treating a missing Text widget as lost paper content.
        expect(
          find.descendant(
            of: document,
            matching: find.bySemanticsLabel(marker),
          ),
          findsAtLeastNWidgets(1),
          reason: 'Preview lost semantic marker: $marker',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'PDF and Word exports retain the same advanced semantic markers',
    () async {
      final paper = SmartPaperReleaseFixture.paper();
      final template = SmartPaperReleaseFixture.template;

      final wordFile = await WordExportService.export(
        paper,
        template,
        fileNameBase: 'Smart Paper Release Word',
      );
      final archive = ZipDecoder().decodeBytes(await wordFile.readAsBytes());
      final wordXml = _archiveText(archive, 'word/document.xml');
      final wordText = _normalizeSemanticText(_wordPlainText(wordXml));

      final pdfFile = await PdfService.export(
        paper,
        template,
        fileNameBase: 'Smart Paper Release PDF',
      );
      final pdfDocument = sf.PdfDocument(
        inputBytes: await pdfFile.readAsBytes(),
      );
      addTearDown(pdfDocument.dispose);
      final pdfText = _normalizeSemanticText(
        sf.PdfTextExtractor(pdfDocument).extractText(),
      );

      for (final marker in SmartPaperReleaseFixture.semanticMarkers) {
        final normalizedMarker = _normalizeSemanticText(marker);
        expect(
          wordText,
          contains(normalizedMarker),
          reason: 'Word lost semantic marker: $marker',
        );
        expect(
          pdfText,
          contains(normalizedMarker),
          reason: 'PDF lost semantic marker: $marker',
        );
      }

      expect(_occurrences(wordText, 'Maximum Marks:'), 1);
      expect(wordText, isNot(contains('Assigned marks')));
      expect(pdfText, isNot(contains('Assigned marks')));
    },
  );
}

String _archiveText(Archive archive, String name) {
  final file = archive.files.firstWhere((entry) => entry.name == name);
  return utf8.decode(file.content as List<int>);
}

String _textValue(Text widget) {
  return widget.data ?? widget.textSpan?.toPlainText() ?? '';
}

String _wordPlainText(String xmlSource) {
  final document = XmlDocument.parse(xmlSource);
  return document.descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == 't')
      .map((element) => element.innerText)
      .join(' ');
}

String _normalizeSemanticText(String source) {
  return source.replaceAll(RegExp(r'\s+'), ' ').trim();
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
