import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_document_codec.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/domain/services/teaching_planner_integrity.dart';
import 'package:edusheet/features/teaching_planner/presentation/widgets/syllabus_attachment_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 22);

  test('schema 10 migrates to schema 11 for Smart Document resources', () {
    const codec = TeachingPlannerDocumentCodec();
    final encoded = codec.encode(_workspace(now), updatedAt: now);
    encoded['schemaVersion'] = 10;

    final decoded = codec.decode(encoded);

    expect(decoded.classes.single.name, 'Class 8');
    expect(codec.encode(decoded, updatedAt: now)['schemaVersion'], 11);
  });

  test('Smart Editor document is a first-class planner resource link', () async {
    final repository = _MemoryRepository(_workspace(now));
    final service = TeachingPlannerService(
      repository,
      idGenerator: () => 'smart-resource',
      clock: () => now,
    );

    final workspace = await service.createTeachingResource(
      owner: const TeachingResourceOwner.subject('subject'),
      kind: TeachingResourceKind.smartDocument,
      role: TeachingResourceRole.reference,
      title: 'Linear Equations Notes',
      linkedSmartDocumentId: 'smart-document-1',
    );

    final resource = workspace.resources.single;
    expect(resource.kind, TeachingResourceKind.smartDocument);
    expect(resource.linkedSmartDocumentId, 'smart-document-1');
    expect(resource.owner, const TeachingResourceOwner.subject('subject'));
    expect(
      TeachingResource.fromJson(resource.toJson()).linkedSmartDocumentId,
      'smart-document-1',
    );
    expect(TeachingPlannerIntegrity.validate(workspace), isEmpty);
  });

  test('same Smart Document cannot be linked twice to one syllabus node', () async {
    final repository = _MemoryRepository(_workspace(now));
    var nextId = 0;
    final service = TeachingPlannerService(
      repository,
      idGenerator: () => 'smart-resource-${nextId++}',
      clock: () => now,
    );

    await service.createTeachingResource(
      owner: const TeachingResourceOwner.subject('subject'),
      kind: TeachingResourceKind.smartDocument,
      title: 'Class Notes',
      linkedSmartDocumentId: 'smart-document-1',
    );

    await expectLater(
      service.createTeachingResource(
        owner: const TeachingResourceOwner.subject('subject'),
        kind: TeachingResourceKind.smartDocument,
        title: 'Class Notes',
        linkedSmartDocumentId: 'smart-document-1',
      ),
      throwsA(isA<TeachingPlannerOperationException>()),
    );
  });

  test('Smart Document resource requires a linked document id', () {
    final repository = _MemoryRepository(_workspace(now));
    final service = TeachingPlannerService(
      repository,
      idGenerator: () => 'smart-resource',
      clock: () => now,
    );

    expect(
      () => service.createTeachingResource(
        owner: const TeachingResourceOwner.subject('subject'),
        kind: TeachingResourceKind.smartDocument,
        title: 'Class Notes',
      ),
      throwsA(isA<TeachingPlannerOperationException>()),
    );
  });

  testWidgets('Resources & Papers exposes Smart Editor create and attach actions', (
    tester,
  ) async {
    var createSmart = 0;
    var attachSmart = 0;
    final resource = TeachingResource(
      id: 'smart-resource',
      owner: const TeachingResourceOwner.subject('subject'),
      kind: TeachingResourceKind.smartDocument,
      title: 'Linear Equations Notes',
      linkedSmartDocumentId: 'smart-document-1',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyllabusAttachmentSection(
            resources: [resource],
            onCreatePaper: () {},
            onAttachSavedPaper: () {},
            onCreateSmartDocument: () => createSmart++,
            onAttachSmartDocument: () => attachSmart++,
            onAddFiles: () {},
            onOpen: (_) {},
            onRemove: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Create Smart Document'), findsOneWidget);
    expect(find.text('Attach Smart Document'), findsOneWidget);
    expect(find.text('Linear Equations Notes'), findsOneWidget);
    expect(find.text('Smart Editor • Free-form academic document'), findsOneWidget);

    await tester.tap(find.text('Create Smart Document'));
    await tester.tap(find.text('Attach Smart Document'));
    expect(createSmart, 1);
    expect(attachSmart, 1);
  });
}

TeachingPlannerWorkspace _workspace(DateTime now) => TeachingPlannerWorkspace(
  classes: [
    PlannerClass(
      id: 'class',
      name: 'Class 8',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    ),
  ],
  subjects: [
    PlannerSubject(
      id: 'subject',
      classId: 'class',
      name: 'Mathematics',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    ),
  ],
);

class _MemoryRepository implements TeachingPlannerRepository {
  _MemoryRepository(this.workspace);

  TeachingPlannerWorkspace workspace;

  @override
  Future<TeachingPlannerWorkspace> load() async => workspace;

  @override
  Future<void> save(TeachingPlannerWorkspace workspace) async {
    this.workspace = workspace;
  }

  @override
  Future<TeachingPlannerWorkspace> update(
    TeachingPlannerMutation mutation,
  ) async {
    workspace = mutation(workspace);
    return workspace;
  }
}
