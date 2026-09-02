import 'dart:io';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/screens/create_paper_screen.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:edusheet/features/paper_composer/application/word_direct_authoring_service.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_header_layout_canvas.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('phase4a_direct_word_');
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
    imageCache.clear();
    imageCache.clearLiveImages();
    if (await tempDir.exists()) {
      for (var attempt = 0; attempt < 10; attempt++) {
        try {
          await tempDir.delete(recursive: true);
          break;
        } on FileSystemException {
          if (attempt == 9) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
    }
  });

  test('direct Word question uses section marks and remains canonical', () {
    final question = WordDirectAuthoringService.blankAssessmentQuestion(
      defaultMarks: 4,
    );

    expect(question.isWordContentBlock, isFalse);
    expect(question.type, QuestionType.descriptive);
    expect(question.marks, 4);
    expect(question.text, isEmpty);

    const first = QuestionAttachment(
      id: 'a1',
      kind: QuestionAttachmentKind.image,
      path: 'one.png',
      alternativeText: 'one',
    );
    const replacement = QuestionAttachment(
      id: 'replacement-id',
      kind: QuestionAttachmentKind.image,
      path: 'two.png',
      alternativeText: 'two',
    );

    final withImage = WordDirectAuthoringService.appendImage(question, first);
    expect(withImage.attachments.single.path, 'one.png');

    final replaced = WordDirectAuthoringService.replaceImage(
      withImage,
      first.id,
      replacement,
    );
    expect(replaced.attachments.single.path, 'two.png');
    expect(replaced.attachments.single.id, first.id);

    final removed = WordDirectAuthoringService.removeImage(replaced, first.id);
    expect(removed.attachments, isEmpty);
  });

  testWidgets(
    'Word Question action creates the question on the page directly',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: _TestApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Word'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('word-mode-add-section')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('word-ribbon-question')), findsOneWidget);
      await tester.tap(find.byKey(const Key('word-ribbon-question')));
      await tester.pumpAndSettle();

      // Phase 4A must stay on the WYSIWYG page instead of navigating to the
      // full-screen "New question" composer.
      expect(find.byKey(const Key('word-paper-document')), findsOneWidget);
      expect(find.byKey(const Key('paper-editor-mode-switch')), findsOneWidget);
      expect(find.text('New question'), findsNothing);
      expect(find.byType(QuillEditor), findsOneWidget);

      final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      editor.controller.replaceText(0, 0, 'Solve x + 2 = 5', null);
      await tester.pump();

      await tester.tap(find.text('Smart'));
      await tester.pumpAndSettle();
      expect(find.text('1 question · 1 mark'), findsOneWidget);

      await tester.tap(find.text('Word'));
      await tester.pumpAndSettle();
      final restored = tester.widget<QuillEditor>(find.byType(QuillEditor));
      expect(
        restored.controller.document.toPlainText(),
        contains('Solve x + 2 = 5'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shared header canvas renders the selected logo file', (
    tester,
  ) async {
    final logoFile = File('assets/Applogo.png').absolute;
    expect(logoFile.existsSync(), isTrue);
    final paper = Paper(
      id: 'p-logo',
      title: 'Exam',
      schoolName: 'School',
      logos: [logoFile.path],
      createdAt: DateTime.utc(2026, 9, 1),
    );
    final template = PaperTemplate(
      id: 'custom-logo-preview',
      name: 'Custom Logo Preview',
      type: TemplateType.school,
      headerLayout: HeaderLayout.custom,
      customLayout: CustomLayout(
        canvasHeight: 90,
        elements: [
          TemplateElement(
            id: 'logo',
            type: ElementType.logo,
            x: 0,
            y: 0,
            width: 60,
            height: 60,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: PaperHeaderLayoutCanvas(template: template, paper: paper),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<FileImage>());
    expect((image.image as FileImage).file.path, logoFile.path);
    expect(find.text('Add logo'), findsNothing);
    expect(tester.takeException(), isNull);

    // Keep the fixture outside the temporary path-provider directory. On
    // Windows an Image.file decoder may briefly keep its source handle open,
    // which must never turn temp-directory cleanup into a ten-minute timeout.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'editable header logo slot is a direct choose or replace target',
    (tester) async {
      final paper = Paper(
        id: 'p1',
        title: 'Exam',
        schoolName: 'School',
        createdAt: DateTime.utc(2026, 9, 1),
      );
      final template = PaperTemplate(
        id: 'custom-logo',
        name: 'Custom Logo',
        type: TemplateType.school,
        headerLayout: HeaderLayout.custom,
        customLayout: CustomLayout(
          canvasHeight: 90,
          elements: [
            TemplateElement(
              id: 'logo',
              type: ElementType.logo,
              x: 0,
              y: 0,
              width: 60,
              height: 60,
            ),
          ],
        ),
      );
      int? tappedLogoIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: PaperHeaderLayoutCanvas(
                template: template,
                paper: paper,
                editable: true,
                onLogoPressed: (index) => tappedLogoIndex = index,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final logo = find.byKey(const ValueKey('word-header-logo-0'));
      expect(logo, findsOneWidget);
      expect(find.text('Add logo'), findsOneWidget);
      await tester.tap(logo);
      await tester.pump();
      expect(tappedLogoIndex, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US')],
      builder: (context, child) => MathKeyboardWrapper(child: child!),
      home: const CreatePaperScreen(),
    );
  }
}
