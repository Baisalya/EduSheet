import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_backup_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_document_codec.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 16);

  test('saved paper links are first-class syllabus resources', () async {
    final repository = _MemoryRepository(_workspace(now));
    final service = TeachingPlannerService(
      repository,
      idGenerator: () => 'paper-resource',
      clock: () => now,
    );

    final workspace = await service.createTeachingResource(
      owner: const TeachingResourceOwner.subject('subject'),
      kind: TeachingResourceKind.paper,
      role: TeachingResourceRole.reference,
      title: 'Half Yearly 2026',
      linkedPaperId: 'paper-123',
    );

    final resource = workspace.resources.single;
    expect(resource.kind, TeachingResourceKind.paper);
    expect(resource.linkedPaperId, 'paper-123');
    expect(resource.owner, const TeachingResourceOwner.subject('subject'));
    expect(
      TeachingResource.fromJson(resource.toJson()).linkedPaperId,
      'paper-123',
    );
  });

  test('same saved paper cannot be linked twice to the same syllabus item', () async {
    final repository = _MemoryRepository(_workspace(now));
    var nextId = 0;
    final service = TeachingPlannerService(
      repository,
      idGenerator: () => 'paper-resource-${nextId++}',
      clock: () => now,
    );

    await service.createTeachingResource(
      owner: const TeachingResourceOwner.subject('subject'),
      kind: TeachingResourceKind.paper,
      title: 'Unit Test',
      linkedPaperId: 'paper-1',
    );

    expect(
      () => service.createTeachingResource(
        owner: const TeachingResourceOwner.subject('subject'),
        kind: TeachingResourceKind.paper,
        title: 'Unit Test',
        linkedPaperId: 'paper-1',
      ),
      throwsA(isA<TeachingPlannerOperationException>()),
    );
  });

  test('schema 7 data migrates to schema 8', () {
    const codec = TeachingPlannerDocumentCodec();
    final workspace = codec.decode({
      'schemaVersion': 7,
      'updatedAt': now.toIso8601String(),
      'workspace': _workspace(now).toJson(),
    });

    expect(codec.encode(workspace)['schemaVersion'], 11);
  });

  test('portable v2 backup keeps paper link metadata without requiring file bytes', () {
    final workspace = _workspace(now).copyWith(
      resources: [
        TeachingResource(
          id: 'paper-resource',
          owner: const TeachingResourceOwner.subject('subject'),
          kind: TeachingResourceKind.paper,
          title: 'Revision Paper',
          linkedPaperId: 'paper-44',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    const codec = TeachingPlannerBackupCodec();
    final encoded = codec.encode(
      workspace,
      exportedAt: now,
      targetVersion: 2,
    );
    final decoded = codec.decodePayload(encoded);

    expect(decoded.resourceFiles, isEmpty);
    expect(decoded.workspace.resources.single.linkedPaperId, 'paper-44');
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
