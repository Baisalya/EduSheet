import 'dart:convert';
import 'dart:io';

import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/teaching_planner/application/teaching_planner_backup_export_service.dart';
import 'package:edusheet/features/teaching_planner/application/teaching_planner_backup_restore_service.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_backup_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_resource_file_store.dart';
import 'package:edusheet/features/teaching_planner/domain/models/curriculum_merge_state.dart';
import 'package:edusheet/features/teaching_planner/domain/models/offline_sync_state.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 21, 10, 30);

  test('normal planner backup still round-trips linked Saved Paper', () async {
    final temp = await Directory.systemTemp.createTemp(
      'edusheet-planner-backup-normal-',
    );
    addTearDown(() => temp.delete(recursive: true));

    final paper = Paper(
      id: 'paper-1',
      title: 'Fractions worksheet',
      createdAt: now,
    );
    final repository = _MemoryPaperRepository([paper]);
    final workspace = _workspaceWithChapter(
      now,
      resources: [
        _paperResource(
          now,
          id: 'paper-resource',
          title: 'Fractions worksheet',
          paperId: paper.id,
        ),
      ],
    );
    final service = TeachingPlannerBackupExportService(
      paperRepository: repository,
      resourceFileStore: TeachingResourceFileStore(
        rootResolver: () async => temp,
      ),
    );

    final preparation = await service.prepare(
      workspace: workspace,
      mergeState: CurriculumMergeState.empty(),
      syncState: OfflineSyncState.uninitialized(),
    );
    final source = service.encode(preparation, exportedAt: now);
    final decoded = const TeachingPlannerBackupCodec().decodePayload(source);

    expect(preparation.needsRecoveryConfirmation, isFalse);
    expect(decoded.version, TeachingPlannerBackupCodec.version);
    expect(decoded.workspace.resources.single.linkedPaperId, paper.id);
    expect(decoded.paperSnapshots.keys, contains(paper.id));
  });

  test(
    'missing linked paper requires confirmation and recovery backup restores safely without mutating source planner',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'edusheet-planner-backup-recovery-',
      );
      addTearDown(() => temp.delete(recursive: true));

      final repository = _MemoryPaperRepository();
      final missing = _paperResource(
        now,
        id: 'missing-paper-resource',
        title: 'Old algebra paper',
        paperId: 'paper-missing-from-papers-json',
      );
      final note = TeachingResource(
        id: 'note-resource',
        owner: const TeachingResourceOwner.chapter('chapter-1'),
        kind: TeachingResourceKind.note,
        title: 'Keep this planner note',
        body: 'This content must survive recovery.',
        createdAt: now,
        updatedAt: now,
      );
      final workspace = _workspaceWithChapter(now, resources: [missing, note]);
      final before = jsonEncode(workspace.toJson());
      final service = TeachingPlannerBackupExportService(
        paperRepository: repository,
        resourceFileStore: TeachingResourceFileStore(
          rootResolver: () async => temp,
        ),
      );

      final preparation = await service.prepare(
        workspace: workspace,
        mergeState: CurriculumMergeState.empty(),
        syncState: OfflineSyncState.uninitialized(),
      );

      expect(preparation.needsRecoveryConfirmation, isTrue);
      expect(preparation.missingLinkedPapers, hasLength(1));
      expect(
        preparation.missingLinkedPapers.single.linkedPaperId,
        'paper-missing-from-papers-json',
      );
      expect(jsonEncode(workspace.toJson()), before);
      expect(workspace.resources, contains(missing));
      expect(
        () => service.encode(preparation, exportedAt: now),
        throwsA(isA<MissingLinkedPapersException>()),
      );

      final source = service.encode(
        preparation,
        allowRecovery: true,
        exportedAt: now,
      );
      final payload = const TeachingPlannerBackupCodec().decodePayload(source);

      expect(payload.paperSnapshots, isEmpty);
      expect(payload.workspace.resourceById(missing.id), isNull);
      expect(payload.workspace.resourceById(note.id)?.body, note.body);
      expect(jsonEncode(workspace.toJson()), before);

      TeachingPlannerWorkspace? restoredWorkspace;
      final restoreResult = await TeachingPlannerBackupRestoreService(
        paperRepository: repository,
        resourceFileStore: TeachingResourceFileStore(
          rootResolver: () async => Directory('${temp.path}/restore'),
        ),
      ).restore(
        payload: payload,
        currentWorkspace: TeachingPlannerWorkspace.empty(),
        saveWorkspace: (restored, _, _) async {
          restoredWorkspace = restored;
          return true;
        },
      );

      expect(restoreResult.saved, isTrue);
      expect(restoredWorkspace, isNotNull);
      expect(restoredWorkspace!.resourceById(missing.id), isNull);
      expect(restoredWorkspace!.resourceById(note.id)?.body, note.body);
      expect(await repository.getAllPapers(), isEmpty);
      expect(jsonEncode(workspace.toJson()), before);
    },
  );
}

TeachingPlannerWorkspace _workspaceWithChapter(
  DateTime now, {
  required List<TeachingResource> resources,
}) {
  return TeachingPlannerWorkspace(
    classes: [
      PlannerClass(
        id: 'class-1',
        name: 'Class 8',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    subjects: [
      PlannerSubject(
        id: 'subject-1',
        classId: 'class-1',
        name: 'Mathematics',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    chapters: [
      PlannerChapter(
        id: 'chapter-1',
        subjectId: 'subject-1',
        title: 'Fractions',
        sortOrder: 0,
        plannedPeriods: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    resources: resources,
  );
}

TeachingResource _paperResource(
  DateTime now, {
  required String id,
  required String title,
  required String paperId,
}) {
  return TeachingResource(
    id: id,
    owner: const TeachingResourceOwner.chapter('chapter-1'),
    kind: TeachingResourceKind.paper,
    title: title,
    linkedPaperId: paperId,
    createdAt: now,
    updatedAt: now,
  );
}

class _MemoryPaperRepository implements PaperRepository {
  _MemoryPaperRepository([Iterable<Paper> papers = const []])
    : _papers = <String, Paper>{
        for (final paper in papers) paper.id: Paper.fromJson(paper.toJson()),
      };

  final Map<String, Paper> _papers;

  @override
  Future<List<Paper>> getAllPapers() async => _papers.values
      .map((paper) => Paper.fromJson(paper.toJson()))
      .toList(growable: false);

  @override
  Future<void> savePaper(Paper paper) async {
    _papers[paper.id] = Paper.fromJson(paper.toJson());
  }

  @override
  Future<void> deletePaper(String id) async {
    _papers.remove(id);
  }
}
