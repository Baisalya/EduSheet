import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_composer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mobile composer keeps authoring tools sticky and cursor-aware', (
    tester,
  ) async {
    await _pumpComposer(tester);

    expect(
      find.byKey(const ValueKey('question-mobile-authoring-tools')),
      findsOneWidget,
    );
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Math'), findsOneWidget);
    expect(find.text('Geometry'), findsOneWidget);
    expect(find.text('Format'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Redo'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('question-insertion-status')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add sheet preserves the exact rich-text insertion anchor', (
    tester,
  ) async {
    await _pumpComposer(tester);

    final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
    editor.controller.replaceText(0, 0, 'Alpha\nBeta', null);
    editor.controller.updateSelection(
      const TextSelection.collapsed(offset: 7),
      ChangeSource.local,
    );
    await tester.pump();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Insert at Line 2 · position 2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('add-content-insertion-anchor')),
      findsOneWidget,
    );

    await tester.tap(find.text('Blank line'));
    await tester.pumpAndSettle();

    expect(
      editor.controller.document.toPlainText(),
      startsWith('Alpha\nB__________eta'),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpComposer(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', 'US')],
        builder: (context, child) => MathKeyboardWrapper(child: child!),
        home: const QuestionComposerPage(
          sectionId: 'section',
          initialType: QuestionType.descriptive,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
