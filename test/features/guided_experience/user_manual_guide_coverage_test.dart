import 'package:edusheet/features/guided_experience/domain/contextual_help.dart';
import 'package:edusheet/features/guided_experience/presentation/screens/user_manual_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('user manual exposes simple teacher tasks and safe demos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: EduSheetUserManualScreen()),
    );

    expect(find.text('EduSheet User Manual'), findsOneWidget);
    expect(find.text('Short, simple help'), findsOneWidget);
    expect(find.text('Create Paper demo'), findsOneWidget);
    expect(find.text('Planner & Syllabus demo'), findsOneWidget);
    const sectionTitles = <String>[
      'Start here',
      'Create a question paper',
      'Smart Editor',
      'Teaching Planner',
      'Syllabus',
      'Plan a lesson',
      'Teaching files and materials',
      'Open documents',
      'Backup, import and share',
      'Other useful Home tools',
    ];
    for (final title in sectionTitles) {
      expect(find.text(title), findsOneWidget);
    }
    final smartEditorSection = find.text('Smart Editor');
    await tester.ensureVisible(smartEditorSection);
    await tester.tap(smartEditorSection);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Resources & Papers → Create Smart Document'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Attach Smart Document'),
      findsOneWidget,
    );

    final plannerSection = find.text('Teaching Planner');
    await tester.ensureVisible(plannerSection);
    await tester.tap(plannerSection);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('original document stays safely in Smart Editor'),
      findsOneWidget,
    );
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
