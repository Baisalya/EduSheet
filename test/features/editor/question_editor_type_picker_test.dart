import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/widgets/question_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('type picker changes behavior from radio to multiple answer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: [Locale('en', 'US')],
          home: Scaffold(
            body: QuestionEditorSheet(
              sectionId: 'section',
              initialType: QuestionType.mcq,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(QuestionType.mcq.label), findsOneWidget);
    expect(find.byType(Radio<int>), findsNWidgets(4));

    await tester.tap(find.text('Change type'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search question types'),
      'multiple select',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(QuestionType.multipleSelect.label));
    await tester.pumpAndSettle();

    expect(find.text(QuestionType.multipleSelect.label), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(4));
  });
}
