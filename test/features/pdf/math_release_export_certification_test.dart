import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/question_copy_service.dart';
import 'package:edusheet/features/paper_composer/application/question_math_validation_service.dart';
import 'package:edusheet/features/paper_composer/application/smart_paper_docx_round_trip_service.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/services/question_paper_service.dart';
import 'package:edusheet/features/pdf/services/word_export_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/math_keyboard/universal_math_booklet_corpus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('math_release_gate_');
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
    'golden universal booklet preserves formula identity through workflow',
    () {
      final paper = _releasePaper();
      final validated = const QuestionMathValidationService()
          .validateAndRepairPaper(paper)
          .safePaper;
      final restored = Paper.fromJson(
        jsonDecode(jsonEncode(validated.toJson())) as Map<String, dynamic>,
      );

      final originalExpressions = _expressions(validated);
      final restoredExpressions = _expressions(restored);

      expect(
        validated.sections.single.questions,
        hasLength(universalMathBookletCorpus.length),
      );
      expect(
        restored.sections.single.questions,
        hasLength(universalMathBookletCorpus.length),
      );
      expect(restoredExpressions, hasLength(originalExpressions.length));
      expect(
        restoredExpressions.map((expression) => expression.persistentIdentity),
        originalExpressions.map((expression) => expression.persistentIdentity),
      );

      var copyId = 0;
      final copier = QuestionCopyService(
        idFactory: () => 'release-copy-${copyId++}',
      );
      for (final question in restored.sections.single.questions) {
        final copied = copier.copyQuestion(question);
        expect(copied.id, isNot(question.id));
        expect(
          copied.mathExpressions,
          hasLength(question.mathExpressions.length),
        );
        expect(
          copied.mathExpressions.map((item) => item.latex),
          question.mathExpressions.map((item) => item.latex),
        );
        expect(
          copied.mathExpressions.map((item) => item.plainText),
          question.mathExpressions.map((item) => item.plainText),
        );
        expect(
          copied.mathExpressions.map((item) => item.id).toSet().length,
          copied.mathExpressions.length,
        );
      }
    },
  );

  test(
    'golden universal booklet produces PDF and exact-restorable DOCX',
    () async {
      final paper = _releasePaper();
      const template = PaperTemplate(
        id: 'math-release-certification',
        name: 'Math Release Certification',
        type: TemplateType.school,
      );

      final pdf = await QuestionPaperService.generateDocument(paper, template);
      final pdfBytes = await pdf.save();
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));

      final docxFile = await WordExportService.export(
        paper,
        template,
        fileNameBase: 'Math Release Certification',
      );
      expect(await docxFile.exists(), isTrue);
      expect(await docxFile.length(), greaterThan(1000));

      final archive = ZipDecoder().decodeBytes(await docxFile.readAsBytes());
      final documentXml = utf8.decode(
        archive.files
                .firstWhere((entry) => entry.name == 'word/document.xml')
                .content
            as List<int>,
      );
      expect(documentXml, contains('<m:oMath'));
      expect(
        archive.files.any(
          (entry) =>
              entry.name == SmartPaperDocxRoundTripService.customXmlPartName,
        ),
        isTrue,
      );

      final imported = await SmartPaperDocxRoundTripService.importFromFile(
        docxFile,
      );
      expect(imported.canRestoreExactly, isTrue);
      expect(imported.paper, isNotNull);
      expect(
        jsonEncode(imported.paper!.toJson()),
        jsonEncode(
          const QuestionMathValidationService()
              .validateAndRepairPaper(paper)
              .safePaper
              .toJson(),
        ),
      );

      final restoredExpressions = _expressions(imported.paper!);
      expect(restoredExpressions, hasLength(universalMathBookletCorpus.length));
      expect(
        restoredExpressions.map((expression) => expression.latex),
        universalMathBookletCorpus.map((sample) => sample.latex),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Paper _releasePaper() {
  final questions = universalMathBookletCorpus
      .map((sample) {
        return Question(
          id: 'release-${sample.id}',
          text: 'Render and interpret ${sample.title}.',
          richTextFormat: 'plain-text-v1',
          plainTextAccessibility: 'Render and interpret ${sample.title}.',
          subject: sample.subject.name,
          mathExpressions: [
            MathExpression(
              id: 'release-math-${sample.id}',
              latex: sample.latex,
              plainText: sample.plainText,
            ),
          ],
        );
      })
      .toList(growable: false);

  return Paper(
    id: 'universal-math-release-paper',
    title: 'Universal Math Release Certification',
    createdAt: DateTime.utc(2026, 9, 8),
    sections: [
      PaperSection(
        id: 'release-section',
        title: 'Universal Math Corpus',
        questions: questions,
      ),
    ],
  );
}

List<MathExpression> _expressions(Paper paper) => paper.sections
    .expand((section) => section.questions)
    .expand((question) => question.mathExpressions)
    .toList(growable: false);
