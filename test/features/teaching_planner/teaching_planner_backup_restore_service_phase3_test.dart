import 'dart:io';

import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/teaching_planner/application/portable_paper_import_service.dart';
import 'package:edusheet/features/teaching_planner/application/teaching_planner_backup_restore_service.dart';
import 'package:edusheet/features/teaching_planner/data/portable_paper_asset_store.dart';
import 'package:edusheet/features/teaching_planner/data/portable_paper_snapshot.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_backup_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_resource_file_store.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 18, 13);

  test('commits embedded planner files through the shared restore transaction', () async {
    final temp = await Directory.systemTemp.createTemp('eds-phase3-restore-');
    addTearDown(() => temp.delete(recursive: true));
    final store = TeachingResourceFileStore(rootResolver: () async => temp);
    final repository = _MemoryPaperRepository();
    final incoming = _fileResource(
      now,
      fileName: 'new-worksheet.pdf',
    );
    final payload = TeachingPlannerBackupPayload(
      workspace: TeachingPlannerWorkspace(resources: [incoming]),
      resourceFiles: const <String, List<int>>{
        'file-resource': <int>[8, 6, 7, 5],
      },
      version: 4,
    );
    TeachingPlannerWorkspace? savedWorkspace;
    final service = TeachingPlannerBackupRestoreService(
      paperRepository: repository,
      resourceFileStore: store,
    );

    final result = await service.restore(
      payload: payload,
      currentWorkspace: TeachingPlannerWorkspace.empty(),
      saveWorkspace: (workspace, _, _) async {
        savedWorkspace = workspace;
        return true;
      },
    );

    expect(result.saved, isTrue);
    final restored = savedWorkspace!.resources.single;
    expect(restored.localRelativePath, isNotNull);
    expect(restored.sizeBytes, 4);
    expect(await store.readBytes(restored.localRelativePath!), <int>[8, 6, 7, 5]);
  });

  test('save rejection rolls back papers created from embedded snapshots', () async {
    final temp = await Directory.systemTemp.createTemp('eds-phase3-paper-rollback-');
    addTearDown(() => temp.delete(recursive: true));
    final repository = _MemoryPaperRepository();
    final paper = Paper(
      id: 'portable-paper',
      originId: 'portable-paper-origin',
      revision: 2,
      updatedAt: now,
      title: 'Portable Paper',
      createdAt: now,
    );
    final resource = TeachingResource(
      id: 'paper-resource',
      owner: const TeachingResourceOwner.plannerClass('class-10'),
      kind: TeachingResourceKind.paper,
      title: 'Portable Paper',
      linkedPaperId: paper.id,
      createdAt: now,
      updatedAt: now,
    );
    final payload = TeachingPlannerBackupPayload(
      workspace: TeachingPlannerWorkspace(resources: [resource]),
      paperSnapshots: <String, PortablePaperSnapshot>{
        paper.id: PortablePaperSnapshot(paper: paper),
      },
      version: 4,
    );
    final service = TeachingPlannerBackupRestoreService(
      paperRepository: repository,
      resourceFileStore: TeachingResourceFileStore(
        rootResolver: () async => temp,
      ),
      paperImportService: PortablePaperImportService(
        paperRepository: repository,
        assetStore: PortablePaperAssetStore(
          rootResolver: () async => Directory('${temp.path}/paper-assets'),
          importDirectoryId: () => 'phase3-paper-import',
        ),
      ),
    );

    final result = await service.restore(
      payload: payload,
      currentWorkspace: TeachingPlannerWorkspace.empty(),
      saveWorkspace: (_, _, _) async => false,
    );

    expect(result.saved, isFalse);
    expect(await repository.getAllPapers(), isEmpty);
  });

  test('save rejection restores previous bytes and filename without stale files', () async {
    final temp = await Directory.systemTemp.createTemp('eds-phase3-rollback-');
    addTearDown(() => temp.delete(recursive: true));
    final store = TeachingResourceFileStore(rootResolver: () async => temp);
    final oldPath = await store.writeBytes(
      resourceId: 'file-resource',
      fileName: 'old-notes.txt',
      bytes: const <int>[1, 2, 3],
    );
    final current = _fileResource(
      now,
      fileName: 'old-notes.txt',
      localRelativePath: oldPath,
      sizeBytes: 3,
    );
    final incoming = _fileResource(
      now,
      fileName: 'replacement.pdf',
    );
    final payload = TeachingPlannerBackupPayload(
      workspace: TeachingPlannerWorkspace(resources: [incoming]),
      resourceFiles: const <String, List<int>>{
        'file-resource': <int>[9, 9, 9, 9],
      },
      version: 4,
    );
    final service = TeachingPlannerBackupRestoreService(
      paperRepository: _MemoryPaperRepository(),
      resourceFileStore: store,
    );

    final result = await service.restore(
      payload: payload,
      currentWorkspace: TeachingPlannerWorkspace(resources: [current]),
      saveWorkspace: (_, _, _) async => false,
    );

    expect(result.saved, isFalse);
    expect(await store.readBytes(oldPath), <int>[1, 2, 3]);
    final resourceDirectory = Directory('${temp.path}/file-resource');
    final entities = await resourceDirectory.list().toList();
    final files = entities.whereType<File>().toList();
    expect(files.length, 1);
    expect(files.single.path, endsWith('old-notes.txt'));
  });
}

TeachingResource _fileResource(
  DateTime now, {
  required String fileName,
  String? localRelativePath,
  int? sizeBytes,
}) {
  return TeachingResource(
    id: 'file-resource',
    owner: const TeachingResourceOwner.plannerClass('class-10'),
    kind: TeachingResourceKind.file,
    title: 'Lesson resource',
    originalFileName: fileName,
    localRelativePath: localRelativePath,
    sizeBytes: sizeBytes,
    createdAt: now,
    updatedAt: now,
  );
}

class _MemoryPaperRepository implements PaperRepository {
  final Map<String, Paper> _papers = <String, Paper>{};

  @override
  Future<List<Paper>> getAllPapers() async =>
      _papers.values.map((paper) => Paper.fromJson(paper.toJson())).toList();

  @override
  Future<void> savePaper(Paper paper) async {
    _papers[paper.id] = Paper.fromJson(paper.toJson());
  }

  @override
  Future<void> deletePaper(String id) async {
    _papers.remove(id);
  }
}
