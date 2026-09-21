import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/application/teaching_resource_attachment_service.dart';
import 'package:edusheet/features/teaching_planner/application/teaching_resource_portability.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_pack_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_backup_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_resource_file_store.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/services/teaching_pack_export_file_saver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 21);

  test('identical managed attachments share one content-addressed blob', () async {
    final root = await Directory.systemTemp.createTemp('edusheet-phase4-dedup-');
    addTearDown(() => root.delete(recursive: true));
    final repository = _MemoryRepository(_workspace(now));
    var nextId = 0;
    final store = TeachingResourceFileStore(rootResolver: () async => root);
    final service = TeachingResourceAttachmentService(
      TeachingPlannerService(repository, clock: () => now),
      store,
      idGenerator: () => 'resource-${++nextId}',
    );
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

    await service.attachFiles(
      owner: const TeachingResourceOwner.plannerClass('class'),
      files: [TeachingAttachmentCandidate(fileName: 'first.pdf', bytes: bytes)],
    );
    final workspace = await service.attachFiles(
      owner: const TeachingResourceOwner.plannerClass('class'),
      files: [TeachingAttachmentCandidate(fileName: 'second.pdf', bytes: bytes)],
    );

    expect(workspace.resources, hasLength(2));
    expect(
      workspace.resources[0].localRelativePath,
      workspace.resources[1].localRelativePath,
    );
    expect(workspace.resources[0].contentSha256, isNotEmpty);
    expect(
      workspace.resources[0].contentSha256,
      workspace.resources[1].contentSha256,
    );

    final audit = await store.auditManagedStorage(workspace);
    expect(audit.managedReferenceCount, 2);
    expect(audit.uniqueReferencedBlobCount, 1);
    expect(audit.orphanBlobCount, 0);
    expect(audit.missingManagedFileCount, 0);
    expect(audit.corruptManagedFileCount, 0);
  });

  test('cleanup removes only unreferenced blobs and keeps shared blob', () async {
    final root = await Directory.systemTemp.createTemp('edusheet-phase4-clean-');
    addTearDown(() => root.delete(recursive: true));
    final store = TeachingResourceFileStore(rootResolver: () async => root);
    final used = await store.writeManagedBlob(
      fileName: 'used.pdf',
      bytes: const [4, 4, 4],
    );
    final orphan = await store.writeManagedBlob(
      fileName: 'orphan.pdf',
      bytes: const [9, 9, 9, 9],
    );
    final workspace = _workspace(now).copyWith(
      resources: [
        TeachingResource(
          id: 'used-a',
          owner: const TeachingResourceOwner.plannerClass('class'),
          kind: TeachingResourceKind.file,
          title: 'used.pdf',
          originalFileName: 'used.pdf',
          localRelativePath: used.relativePath,
          sizeBytes: used.sizeBytes,
          contentSha256: used.sha256Hex,
          createdAt: now,
          updatedAt: now,
        ),
        TeachingResource(
          id: 'used-b',
          owner: const TeachingResourceOwner.plannerClass('class'),
          kind: TeachingResourceKind.file,
          title: 'same-copy.pdf',
          originalFileName: 'same-copy.pdf',
          localRelativePath: used.relativePath,
          sizeBytes: used.sizeBytes,
          contentSha256: used.sha256Hex,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    final before = await store.auditManagedStorage(workspace);
    expect(before.orphanBlobCount, 1);
    final cleaned = await store.auditManagedStorage(
      workspace,
      removeOrphanBlobs: true,
    );
    expect(cleaned.orphanBlobCount, 1);
    expect(cleaned.reclaimedBytes, 4);
    expect(await store.exists(used.relativePath), isTrue);
    expect(await store.exists(orphan.relativePath), isFalse);
  });

  test('managed resource hash detects on-disk corruption', () async {
    final root = await Directory.systemTemp.createTemp('edusheet-phase4-corrupt-');
    addTearDown(() => root.delete(recursive: true));
    final store = TeachingResourceFileStore(rootResolver: () async => root);
    final blob = await store.writeManagedBlob(
      fileName: 'notes.txt',
      bytes: utf8.encode('correct'),
    );
    final resource = TeachingResource(
      id: 'resource',
      owner: const TeachingResourceOwner.plannerClass('class'),
      kind: TeachingResourceKind.file,
      title: 'notes.txt',
      originalFileName: 'notes.txt',
      localRelativePath: blob.relativePath,
      sizeBytes: blob.sizeBytes,
      contentSha256: blob.sha256Hex,
      createdAt: now,
      updatedAt: now,
    );
    final file = await store.resolve(blob.relativePath);
    await file.writeAsString('changed', flush: true);

    expect(await store.verifyResourceIntegrity(resource), isFalse);
    final audit = await store.auditManagedStorage(
      _workspace(now).copyWith(resources: [resource]),
    );
    expect(audit.corruptManagedFileCount, 1);
    expect(
      store.readResourceBytes(resource),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('planner backup attachment manifest rejects modified embedded bytes', () {
    final bytes = utf8.encode('portable attachment');
    final store = TeachingResourceFileStore(
      rootResolver: () async => Directory.systemTemp,
    );
    final hash = store.sha256ForBytes(bytes);
    final workspace = _workspace(now).copyWith(
      resources: [
        TeachingResource(
          id: 'file-1',
          owner: const TeachingResourceOwner.plannerClass('class'),
          kind: TeachingResourceKind.file,
          title: 'guide.txt',
          originalFileName: 'guide.txt',
          localRelativePath: 'blobs/aa/file.blob',
          sizeBytes: bytes.length,
          contentSha256: hash,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    final source = const TeachingPlannerBackupCodec().encode(
      workspace,
      exportedAt: now,
      resourceFiles: {'file-1': bytes},
    );
    final encoded = base64Encode(bytes);
    final tamperedBytes = utf8.encode('portable attachmenU');
    final tampered = source.replaceFirst(encoded, base64Encode(tamperedBytes));

    expect(
      () => const TeachingPlannerBackupCodec().decodePayload(tampered),
      throwsA(isA<FormatException>()),
    );
  });

  test('Teaching Pack refreshes linked-file hash and rejects tampered bytes', () {
    final linked = TeachingResource(
      id: 'linked',
      owner: const TeachingResourceOwner.plannerClass('class'),
      kind: TeachingResourceKind.file,
      title: 'lesson.pdf',
      originalFileName: 'lesson.pdf',
      fileOwnership: TeachingResourceFileOwnership.linkedExternal,
      externalFilePath: r'C:\\School\\lesson.pdf',
      sizeBytes: 1,
      contentSha256: '0000000000000000000000000000000000000000000000000000000000000000',
      createdAt: now,
      updatedAt: now,
    );
    final bytes = <int>[1, 2, 3, 4];
    final source = const TeachingPackCodec().encode(
      TeachingPackPayload(
        sourceLessonTitle: 'Lesson',
        sourceClassName: 'Class 8',
        sourceSubjectName: 'Math',
        sourceChapterTitle: 'Algebra',
        resources: [
          TeachingPackResourcePayload(resource: linked, fileBytes: bytes),
        ],
      ),
      exportedAt: now,
    );
    final decoded = const TeachingPackCodec().decode(source).resources.single;
    expect(decoded.resource.fileOwnership, TeachingResourceFileOwnership.managed);
    expect(decoded.resource.externalFilePath, isNull);
    expect(decoded.resource.sizeBytes, bytes.length);
    expect(decoded.resource.contentSha256, isNot('0000000000000000000000000000000000000000000000000000000000000000'));

    final encoded = base64Encode(bytes);
    final tampered = source.replaceFirst(encoded, base64Encode(<int>[1, 2, 3, 5]));
    expect(
      () => const TeachingPackCodec().decode(tampered),
      throwsA(isA<FormatException>()),
    );
  });


  test('portable .eds metadata refreshes linked original size and hash', () {
    final linked = TeachingResource(
      id: 'linked-eds',
      owner: const TeachingResourceOwner.plannerClass('class'),
      kind: TeachingResourceKind.file,
      title: 'worksheet.docx',
      originalFileName: 'worksheet.docx',
      fileOwnership: TeachingResourceFileOwnership.linkedExternal,
      externalFilePath: r'C:\School\worksheet.docx',
      sizeBytes: 2,
      createdAt: now,
      updatedAt: now,
    );
    final currentBytes = utf8.encode('updated linked original');
    final portable = portableTeachingResourceWorkspaceWithFiles(
      _workspace(now).copyWith(resources: [linked]),
      {'linked-eds': currentBytes},
    );
    final resource = portable.resources.single;

    expect(resource.fileOwnership, TeachingResourceFileOwnership.managed);
    expect(resource.externalFilePath, isNull);
    expect(resource.sizeBytes, currentBytes.length);
    expect(resource.contentSha256, isNotNull);
    expect(resource.contentSha256, hasLength(64));
  });


  test('Android Teaching Pack save sends UTF-8 bytes to file picker', () async {
    TeachingPackSaveDialogRequest? captured;
    var writes = 0;
    final saver = TeachingPackExportFileSaver(
      isAndroid: true,
      saveFile: (request) async {
        captured = request;
        return 'content://documents/teaching-pack';
      },
      writeTextFile: (path, source) async {
        writes++;
      },
    );

    final path = await saver.save(
      source: 'Teaching Pack – ଶିକ୍ଷା',
      fileName: 'Class8_Lesson',
      dialogTitle: 'Save Teaching Pack',
    );

    expect(path, 'content://documents/teaching-pack');
    expect(captured?.fileName, 'Class8_Lesson.edtp');
    expect(utf8.decode(captured!.bytes!), 'Teaching Pack – ଶିକ୍ଷା');
    expect(writes, 0);
  });

  test('desktop Teaching Pack save preserves path-based write flow', () async {
    TeachingPackSaveDialogRequest? captured;
    String? writtenPath;
    String? writtenSource;
    final saver = TeachingPackExportFileSaver(
      isAndroid: false,
      saveFile: (request) async {
        captured = request;
        return r'C:\School\LessonPack';
      },
      writeTextFile: (path, source) async {
        writtenPath = path;
        writtenSource = source;
      },
    );

    final path = await saver.save(
      source: 'portable pack',
      fileName: 'LessonPack.edtp',
      dialogTitle: 'Save Teaching Pack',
    );

    expect(captured?.bytes, isNull);
    expect(path, r'C:\School\LessonPack.edtp');
    expect(writtenPath, r'C:\School\LessonPack.edtp');
    expect(writtenSource, 'portable pack');
  });

  test('legacy managed path remains readable after Phase 4 store upgrade', () async {
    final root = await Directory.systemTemp.createTemp('edusheet-phase4-legacy-');
    addTearDown(() => root.delete(recursive: true));
    final legacy = File('${root.path}${Platform.pathSeparator}legacy${Platform.pathSeparator}notes.pdf');
    await legacy.parent.create(recursive: true);
    await legacy.writeAsBytes([7, 8, 9]);
    final store = TeachingResourceFileStore(rootResolver: () async => root);
    final resource = TeachingResource(
      id: 'legacy',
      owner: const TeachingResourceOwner.plannerClass('class'),
      kind: TeachingResourceKind.file,
      title: 'notes.pdf',
      originalFileName: 'notes.pdf',
      localRelativePath: 'legacy/notes.pdf',
      sizeBytes: 3,
      createdAt: now,
      updatedAt: now,
    );

    expect(await store.readResourceBytes(resource), [7, 8, 9]);
    expect(await store.verifyResourceIntegrity(resource), isTrue);
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
  Future<TeachingPlannerWorkspace> update(TeachingPlannerMutation mutation) async {
    workspace = mutation(workspace);
    return workspace;
  }
}
