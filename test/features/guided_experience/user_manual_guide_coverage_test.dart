import 'package:edusheet/features/guided_experience/domain/contextual_help.dart';
import 'package:edusheet/features/guided_experience/presentation/screens/user_manual_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('user manual exposes simple teacher tasks and safe demos', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EduSheetUserManualScreen()),
    );

    expect(find.text('EduSheet User Manual'), findsOneWidget);
    expect(find.text('Short, simple help'), findsOneWidget);
    expect(find.text('Create Paper demo'), findsOneWidget);
    expect(find.text('Planner & Syllabus demo'), findsOneWidget);
    expect(find.text('Start here'), findsOneWidget);
    expect(find.text('Create a question paper'), findsOneWidget);
    expect(find.text('Teaching Planner'), findsOneWidget);
    expect(find.text('Syllabus'), findsOneWidget);
    expect(find.text('Plan a lesson'), findsOneWidget);
    expect(find.text('Teaching files and materials'), findsOneWidget);
    expect(find.text('Open documents'), findsOneWidget);
    expect(find.text('Backup, import and share'), findsOneWidget);
    expect(find.text('Other useful Home tools'), findsOneWidget);
  });

  testWidgets('focused manual section opens first and expanded', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EduSheetUserManualScreen(focus: EduSheetManualSection.reader),
      ),
    );

    final openDocuments = find.text('Open documents');
    expect(openDocuments, findsOneWidget);
    expect(
      find.text('Home → PDF/Word Reader → Open file.'),
      findsOneWidget,
    );
  });

  test('smart helper has explicit contexts for newly covered work surfaces', () {
    expect(GuidedScreenContext.values, contains(GuidedScreenContext.home));
    expect(
      GuidedScreenContext.values,
      contains(GuidedScreenContext.teachingWorkspace),
    );
    expect(
      GuidedScreenContext.values,
      contains(GuidedScreenContext.documentReader),
    );
    expect(GuidedScreenContext.values, contains(GuidedScreenContext.settings));
  });
}
