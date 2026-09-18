import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:edusheet/features/teaching_planner/presentation/widgets/syllabus_attachment_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Resources & Papers exposes three simple teacher actions', (tester) async {
    var create = 0;
    var attach = 0;
    var files = 0;
    final now = DateTime.utc(2026, 9, 16);
    final paper = TeachingResource(
      id: 'r1',
      owner: const TeachingResourceOwner.subject('subject'),
      kind: TeachingResourceKind.paper,
      title: 'Half Yearly 2026',
      linkedPaperId: 'paper-1',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyllabusAttachmentSection(
            resources: [paper],
            onCreatePaper: () => create++,
            onAttachSavedPaper: () => attach++,
            onAddFiles: () => files++,
            onOpen: (_) {},
            onRemove: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Resources & Papers'), findsOneWidget);
    expect(find.text('Create New Paper'), findsOneWidget);
    expect(find.text('Attach Saved Paper'), findsOneWidget);
    expect(find.text('Add files'), findsOneWidget);
    expect(find.text('Half Yearly 2026'), findsOneWidget);
    expect(find.text('EduSheet paper • Saved Papers'), findsOneWidget);

    await tester.tap(find.text('Create New Paper'));
    await tester.tap(find.text('Attach Saved Paper'));
    await tester.tap(find.text('Add files'));
    expect(create, 1);
    expect(attach, 1);
    expect(files, 1);
  });

  // Regression: legacy hosts can omit native-paper callbacks. The section should
  // still render its file attachment action while keeping paper actions disabled.
  testWidgets('paper actions stay disabled when host does not provide callbacks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyllabusAttachmentSection(
            resources: const [],
            createPaperEnabled: false,
            attachSavedPaperEnabled: false,
            onCreatePaper: () {},
            onAttachSavedPaper: () {},
            onAddFiles: () {},
            onOpen: (_) {},
            onRemove: (_) {},
          ),
        ),
      ),
    );
  
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('syllabus-create-paper-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('syllabus-attach-saved-paper-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('syllabus-add-file-button')),
          )
          .onPressed,
      isNotNull,
    );
  });
}
