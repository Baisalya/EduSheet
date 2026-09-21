import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:edusheet/features/teaching_planner/presentation/widgets/syllabus_attachment_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('attachment UI distinguishes managed copies and linked originals', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 9, 21);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: SyllabusAttachmentSection(
              resources: [
                TeachingResource(
                  id: 'managed',
                  owner: const TeachingResourceOwner.plannerClass('class'),
                  kind: TeachingResourceKind.file,
                  title: 'managed.pdf',
                  originalFileName: 'managed.pdf',
                  localRelativePath: 'managed/managed.pdf',
                  sizeBytes: 20,
                  createdAt: now,
                  updatedAt: now,
                ),
                TeachingResource(
                  id: 'linked',
                  owner: const TeachingResourceOwner.plannerClass('class'),
                  kind: TeachingResourceKind.file,
                  title: 'linked.docx',
                  originalFileName: 'linked.docx',
                  fileOwnership: TeachingResourceFileOwnership.linkedExternal,
                  externalFilePath: r'C:\School\linked.docx',
                  sizeBytes: 30,
                  createdAt: now,
                  updatedAt: now,
                ),
              ],
              onAddFiles: () {},
              onLinkFiles: () {},
              onOpen: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Link originals'), findsOneWidget);
    expect(find.textContaining('EduSheet copy'), findsOneWidget);
    expect(find.textContaining('Linked original'), findsOneWidget);
  });
}
