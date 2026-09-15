import 'dart:io';
import 'dart:typed_data';

import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/application/teaching_resource_attachment_service.dart';
import 'package:edusheet/features/teaching_planner/application/teaching_resource_file_metadata.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_resource_file_store.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 8);

  test('multiple attachments persist in one metadata transaction', () async {
    final root = await Directory.systemTemp.createTemp('edusheet-attachments-');
    addTearDown(() => root.delete(recursive: true));
    final repository = _CountingRepository(_workspace(now));
    final plannerService = TeachingPlannerService(repository, clock: () => now);
    final store = TeachingResourceFileStore(rootResolver: () async => root);
    var id = 0;
    final service = TeachingResourceAttachmentService(
      plannerService,
      store,
      idGenerator: () => 'resource-${id++}',
    );

    final workspace = await service.attachFiles(
      owner: const TeachingResourceOwner.plannerClass('class'),
      files: [
        TeachingAttachmentCandidate(
          fileName: 'diagram.png',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        TeachingAttachmentCandidate(
          fileName: 'lesson.pdf',
          bytes: Uint8List.fromList([4, 5, 6, 7]),
        ),
      ],
    );

    expect(repository.updateCount, 1);
    expect(workspace.resources, hasLength(2));
    expect(workspace.resources.first.owner.id, 'class');
    expect(workspace.resources.first.mimeType, 'image/png');
    expect(workspace.resources.last.mimeType, 'application/pdf');
    expect(
      await store.readBytes(workspace.resources.first.localRelativePath!),
      [1, 2, 3],
    );
  });

  test(
    'attachment files roll back when planner metadata persistence fails',
    () async {
      final root = await Directory.systemTemp.createTemp('edusheet-rollback-');
      addTearDown(() => root.delete(recursive: true));
      final plannerService = TeachingPlannerService(
        _FailingUpdateRepository(_workspace(now)),
        clock: () => now,
      );
      final store = TeachingResourceFileStore(rootResolver: () async => root);
      final service = TeachingResourceAttachmentService(
        plannerService,
        store,
        idGenerator: () => 'rollback-resource',
      );

      await expectLater(
        service.attachFiles(
          owner: const TeachingResourceOwner.plannerClass('class'),
          files: [
            TeachingAttachmentCandidate(
              fileName: 'video.mp4',
              bytes: Uint8List.fromList([9, 8, 7]),
            ),
          ],
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        await Directory('${root.path}/rollback-resource').exists(),
        isFalse,
      );
    },
  );

  test('file metadata recognizes document and media families centrally', () {
    expect(
      TeachingResourceFileMetadata.mimeTypeForFileName('notes.odt'),
      'application/vnd.oasis.opendocument.text',
    );
    expect(
      TeachingResourceFileMetadata.mimeTypeForFileName('slides.pptx'),
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    );
    expect(
      TeachingResourceFileMetadata.categoryFor(fileName: 'movie.mkv'),
      TeachingResourceFileCategory.video,
    );
  });
}

TeachingPlannerWorkspace _workspace(DateTime now) => TeachingPlannerWorkspace(
  classes: [
    PlannerClass(
      id: 'class',
      name: 'Class 10',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    ),
  ],
);

class _CountingRepository implements TeachingPlannerRepository {
  _CountingRepository(this.workspace);

  TeachingPlannerWorkspace workspace;
  int updateCount = 0;

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
    updateCount += 1;
    workspace = mutation(workspace);
    return workspace;
  }
}

class _FailingUpdateRepository implements TeachingPlannerRepository {
  _FailingUpdateRepository(this.workspace);

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
    throw StateError('simulated persistence failure');
  }
}
