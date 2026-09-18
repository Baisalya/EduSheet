import 'dart:io';

import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/teaching_planner/application/portable_paper_import_service.dart';
import 'package:edusheet/features/teaching_planner/data/portable_paper_asset_store.dart';
import 'package:edusheet/features/teaching_planner/data/portable_paper_snapshot.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_backup_codec.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 17);

  test('v3 embeds linked paper snapshot and paper binary assets', () async {
    final temp = await Directory.systemTemp.createTemp('edusheet-v3-export-');
    addTearDown(() => temp.delete(recursive: true));
    final logo = File('${temp.path}/school-logo.png');
    await logo.writeAsBytes([1, 2, 3, 4], flush: true);
    final paper = _paper(now, logos: [logo.path]);
    final snapshot = await PortablePaperSnapshot.capture(paper);
    final workspace = _workspaceWithPaper(now, paper.id);

    const codec = TeachingPlannerBackupCodec();
    final encoded = codec.encode(
      workspace,
      exportedAt: now,
      paperSnapshots: {paper.id: snapshot},
    );
    final decoded = codec.decodePayload(encoded);

    expect(decoded.version, 3);
    expect(decoded.paperSnapshots.keys, [paper.id]);
    expect(decoded.paperSnapshots[paper.id]!.paper.logos.single,
        startsWith(PortablePaperSnapshot.assetTokenPrefix));
    expect(
      decoded.paperSnapshots[paper.id]!.assets.values.single.bytes,
      [1, 2, 3, 4],
    );
  });

  test('question image and attachment paths are materialized on the new device', () async {
    final temp = await Directory.systemTemp.createTemp('edusheet-v3-question-assets-');
    addTearDown(() => temp.delete(recursive: true));
    final image = File('${temp.path}/question.png');
    final attachment = File('${temp.path}/diagram.jpg');
    await image.writeAsBytes([1, 9, 1], flush: true);
    await attachment.writeAsBytes([2, 8, 2], flush: true);
    final paper = Paper(
      id: 'paper-1',
      title: 'Paper with images',
      sections: [
        PaperSection(
          id: 'section',
          title: 'Section A',
          questions: [
            Question(
              id: 'question',
              text: 'Identify the diagram',
              imageUrl: image.path,
              attachments: [
                QuestionAttachment(
                  id: 'attachment',
                  kind: QuestionAttachmentKind.image,
                  path: attachment.path,
                  alternativeText: 'Diagram',
                ),
              ],
              createdAt: now,
              modifiedAt: now,
            ),
          ],
        ),
      ],
      createdAt: now,
    );
    final snapshot = await PortablePaperSnapshot.capture(paper);
    final store = PortablePaperAssetStore(
      rootResolver: () async => Directory('${temp.path}/target'),
      importDirectoryId: () => 'question-assets',
    );
    final materialized = await store.materialize(
      snapshot,
      targetPaperId: paper.id,
    );
    final restored = snapshot.restoreWithPaths(materialized.resolvedPaths);
    final question = restored.sections.single.questions.single;

    expect(question.imageUrl, isNot(image.path));
    expect(await File(question.imageUrl!).readAsBytes(), [1, 9, 1]);
    expect(question.attachments.single.path, isNot(attachment.path));
    expect(await File(question.attachments.single.path).readAsBytes(), [2, 8, 2]);
  });

  test('v3 refuses a paper link when its snapshot is missing', () {
    final workspace = _workspaceWithPaper(now, 'paper-1');
    expect(
      () => const TeachingPlannerBackupCodec().encode(workspace),
      throwsFormatException,
    );
  });

  test('v3 refuses paper snapshot ids that do not match planner links', () {
    final workspace = _workspaceWithPaper(now, 'paper-1');
    final wrong = PortablePaperSnapshot(paper: _paper(now, id: 'paper-2'));

    expect(
      () => const TeachingPlannerBackupCodec().encode(
        workspace,
        paperSnapshots: {'paper-1': wrong},
      ),
      throwsFormatException,
    );
  });

  test('v3 snapshot refuses raw device-local paper paths', () {
    expect(
      () => PortablePaperSnapshot(
        paper: _paper(now, logos: const ['/device/local/logo.png']),
      ),
      throwsFormatException,
    );
  });

  test('v3 refuses corrupted paper asset bindings', () async {
    final temp = await Directory.systemTemp.createTemp('edusheet-v3-corrupt-');
    addTearDown(() => temp.delete(recursive: true));
    final logo = File('${temp.path}/logo.png');
    await logo.writeAsBytes([9, 8, 7], flush: true);
    final snapshot = await PortablePaperSnapshot.capture(
      _paper(now, logos: [logo.path]),
    );
    final json = snapshot.toJson();
    json.remove('assets');

    expect(
      () => PortablePaperSnapshot.fromJson(json),
      throwsFormatException,
    );
  });

  test('v2 backup remains readable without embedded paper snapshot', () {
    final workspace = _workspaceWithPaper(now, 'paper-legacy');
    const codec = TeachingPlannerBackupCodec();
    final encoded = codec.encode(workspace, targetVersion: 2);
    final decoded = codec.decodePayload(encoded);

    expect(decoded.version, 2);
    expect(decoded.paperSnapshots, isEmpty);
    expect(decoded.workspace.resources.single.linkedPaperId, 'paper-legacy');
  });

  test('missing destination paper restores with original id', () async {
    final repository = _MemoryPaperRepository();
    final temp = await Directory.systemTemp.createTemp('edusheet-v3-import-');
    addTearDown(() => temp.delete(recursive: true));
    final sourceAsset = File('${temp.path}/source.png');
    await sourceAsset.writeAsBytes([3, 1, 4], flush: true);
    final paper = _paper(now, logos: [sourceAsset.path]);
    final snapshot = await PortablePaperSnapshot.capture(paper);
    final targetRoot = Directory('${temp.path}/target');
    final service = PortablePaperImportService(
      paperRepository: repository,
      assetStore: PortablePaperAssetStore(
        rootResolver: () async => targetRoot,
        importDirectoryId: () => 'import-a',
      ),
      idGenerator: () => 'unused-copy-id',
    );

    final result = await service.importSnapshots(
      workspace: _workspaceWithPaper(now, paper.id),
      snapshots: {paper.id: snapshot},
    );

    expect(result.restoredCount, 1);
    expect(result.reusedCount, 0);
    expect(result.conflictCopyCount, 0);
    expect(result.workspace.resources.single.linkedPaperId, paper.id);
    final restored = (await repository.getAllPapers()).single;
    expect(restored.id, paper.id);
    expect(restored.logos.single, isNot(sourceAsset.path));
    expect(await File(restored.logos.single).readAsBytes(), [3, 1, 4]);
  });

  test('same id and identical portable content reuses existing paper', () async {
    final temp = await Directory.systemTemp.createTemp('edusheet-v3-reuse-');
    addTearDown(() => temp.delete(recursive: true));
    final assetA = File('${temp.path}/a/logo.png');
    await assetA.parent.create(recursive: true);
    await assetA.writeAsBytes([5, 5, 5], flush: true);
    final assetB = File('${temp.path}/b/logo-copy.png');
    await assetB.parent.create(recursive: true);
    await assetB.writeAsBytes([5, 5, 5], flush: true);

    final backupPaper = _paper(now, logos: [assetA.path]);
    final existingPaper = _paper(now, logos: [assetB.path]);
    final repository = _MemoryPaperRepository([existingPaper]);
    final service = PortablePaperImportService(
      paperRepository: repository,
      assetStore: PortablePaperAssetStore(
        rootResolver: () async => Directory('${temp.path}/target'),
      ),
      idGenerator: () => 'copy-id',
    );

    final result = await service.importSnapshots(
      workspace: _workspaceWithPaper(now, backupPaper.id),
      snapshots: {
        backupPaper.id: await PortablePaperSnapshot.capture(backupPaper),
      },
    );

    expect(result.reusedCount, 1);
    expect(result.createdPaperIds, isEmpty);
    expect((await repository.getAllPapers()).single.logos.single, assetB.path);
  });

  test('same id with different content creates safe copy and remaps link', () async {
    final repository = _MemoryPaperRepository([
      _paper(now, title: 'Existing local version'),
    ]);
    final incoming = _paper(now, title: 'Incoming backup version');
    final temp = await Directory.systemTemp.createTemp('edusheet-v3-conflict-');
    addTearDown(() => temp.delete(recursive: true));
    final service = PortablePaperImportService(
      paperRepository: repository,
      assetStore: PortablePaperAssetStore(
        rootResolver: () async => Directory('${temp.path}/target'),
      ),
      idGenerator: () => 'paper-safe-copy',
    );

    final result = await service.importSnapshots(
      workspace: _workspaceWithPaper(now, incoming.id),
      snapshots: {
        incoming.id: await PortablePaperSnapshot.capture(incoming),
      },
    );

    expect(result.conflictCopyCount, 1);
    expect(result.workspace.resources.single.linkedPaperId, 'paper-safe-copy');
    final papers = await repository.getAllPapers();
    expect(papers, hasLength(2));
    expect(
      papers.firstWhere((paper) => paper.id == incoming.id).title,
      'Existing local version',
    );
    expect(
      papers.firstWhere((paper) => paper.id == 'paper-safe-copy').title,
      'Incoming backup version',
    );
  });

  test('rollback removes papers and files created by an import', () async {
    final repository = _MemoryPaperRepository();
    final temp = await Directory.systemTemp.createTemp('edusheet-v3-rollback-');
    addTearDown(() => temp.delete(recursive: true));
    final asset = File('${temp.path}/source/logo.png');
    await asset.parent.create(recursive: true);
    await asset.writeAsBytes([7, 7], flush: true);
    final incoming = _paper(now, logos: [asset.path]);
    final service = PortablePaperImportService(
      paperRepository: repository,
      assetStore: PortablePaperAssetStore(
        rootResolver: () async => Directory('${temp.path}/target'),
        importDirectoryId: () => 'rollback-dir',
      ),
    );

    final result = await service.importSnapshots(
      workspace: _workspaceWithPaper(now, incoming.id),
      snapshots: {
        incoming.id: await PortablePaperSnapshot.capture(incoming),
      },
    );
    final createdDir = result.createdAssetDirectories.single;
    expect(await Directory(createdDir).exists(), isTrue);

    await service.rollback(result);

    expect(await repository.getAllPapers(), isEmpty);
    expect(await Directory(createdDir).exists(), isFalse);
  });
}

Paper _paper(
  DateTime now, {
  String id = 'paper-1',
  String title = 'Portable Mathematics Paper',
  List<String> logos = const [],
}) =>
    Paper(
      id: id,
      title: title,
      logos: logos,
      createdAt: now,
    );

TeachingPlannerWorkspace _workspaceWithPaper(DateTime now, String paperId) =>
    TeachingPlannerWorkspace(
      classes: [
        PlannerClass(
          id: 'class-8',
          name: 'Class 8',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      resources: [
        TeachingResource(
          id: 'paper-resource',
          owner: const TeachingResourceOwner.plannerClass('class-8'),
          kind: TeachingResourceKind.paper,
          title: 'Portable Mathematics Paper',
          linkedPaperId: paperId,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

class _MemoryPaperRepository implements PaperRepository {
  _MemoryPaperRepository([Iterable<Paper> initial = const []]) {
    for (final paper in initial) {
      _papers[paper.id] = Paper.fromJson(paper.toJson());
    }
  }

  final Map<String, Paper> _papers = {};

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
