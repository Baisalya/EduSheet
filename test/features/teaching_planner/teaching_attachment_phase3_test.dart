import 'dart:io';
import 'dart:typed_data';

import 'package:edusheet/features/document_reader/data/repositories/document_repository.dart';
import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/application/teaching_resource_attachment_service.dart';
import 'package:edusheet/features/teaching_planner/application/teaching_resource_portability.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_pack_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_resource_file_store.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/services/teaching_attachment_open_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 21);

  test('legacy file resource defaults to EduSheet-managed ownership', () {
    final resource = TeachingResource.fromJson({
      'id': 'legacy-file',
      'owner': const TeachingResourceOwner.plannerClass('class').toJson(),
      'kind': 'file',
      'role': 'reference',
      'title': 'notes.pdf',
      'originalFileName': 'notes.pdf',
      'localRelativePath': 'legacy-file/notes.pdf',
      'sizeBytes': 10,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });

    expect(resource.fileOwnership, TeachingResourceFileOwnership.managed);
    expect(resource.externalFilePath, isNull);
  });

  test('linked original stays external and portable copy strips machine path', () async {
    final root = await Directory.systemTemp.createTemp('edusheet-phase3-root-');
    final externalRoot = await Directory.systemTemp.createTemp('edusheet-phase3-external-');
    addTearDown(() async {
      await root.delete(recursive: true);
      await externalRoot.delete(recursive: true);
    });
    final original = File('${externalRoot.path}/lesson.pdf');
    await original.writeAsBytes([1, 2, 3, 4]);

    final repository = _MemoryRepository(_workspace(now));
    final store = TeachingResourceFileStore(rootResolver: () async => root);
    final service = TeachingResourceAttachmentService(
      TeachingPlannerService(repository, clock: () => now),
      store,
      idGenerator: () => 'linked-resource',
    );

    final workspace = await service.attachLinkedFiles(
      owner: const TeachingResourceOwner.plannerClass('class'),
      files: [
        TeachingAttachmentCandidate(
          fileName: 'lesson.pdf',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
          sourcePath: original.path,
        ),
      ],
    );
    final resource = workspace.resources.single;
    expect(resource.fileOwnership, TeachingResourceFileOwnership.linkedExternal);
    expect(resource.externalFilePath, original.path);
    expect(resource.localRelativePath, isNull);
    expect(await store.readResourceBytes(resource), [1, 2, 3, 4]);

    final portable = portableTeachingResourceWorkspace(workspace);
    final portableResource = portable.resources.single;
    expect(portableResource.fileOwnership, TeachingResourceFileOwnership.managed);
    expect(portableResource.externalFilePath, isNull);
    expect(portableResource.localRelativePath, isNotEmpty);
  });

  test('replace linked original makes a managed copy without touching original', () async {
    final root = await Directory.systemTemp.createTemp('edusheet-phase3-managed-');
    final externalRoot = await Directory.systemTemp.createTemp('edusheet-phase3-original-');
    addTearDown(() async {
      await root.delete(recursive: true);
      await externalRoot.delete(recursive: true);
    });
    final original = File('${externalRoot.path}/original.txt');
    await original.writeAsString('original remains');
    final repository = _MemoryRepository(
      _workspace(now).copyWith(
        resources: [
          TeachingResource(
            id: 'resource',
            owner: const TeachingResourceOwner.plannerClass('class'),
            kind: TeachingResourceKind.file,
            title: 'original.txt',
            originalFileName: 'original.txt',
            mimeType: 'text/plain',
            fileOwnership: TeachingResourceFileOwnership.linkedExternal,
            externalFilePath: original.path,
            sizeBytes: await original.length(),
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    final store = TeachingResourceFileStore(rootResolver: () async => root);
    final service = TeachingResourceAttachmentService(
      TeachingPlannerService(repository, clock: () => now),
      store,
    );

    final updated = await service.replaceWithManagedCopy(
      resource: repository.workspace.resources.single,
      file: TeachingAttachmentCandidate(
        fileName: 'replacement.txt',
        bytes: Uint8List.fromList('replacement'.codeUnits),
      ),
    );
    final resource = updated.resources.single;
    expect(resource.fileOwnership, TeachingResourceFileOwnership.managed);
    expect(resource.externalFilePath, isNull);
    expect(resource.localRelativePath, isNotNull);
    expect(String.fromCharCodes(await store.readResourceBytes(resource)), 'replacement');
    expect(await original.readAsString(), 'original remains');
  });

  test('opener routes EduSheet-supported formats internally and reports missing files', () async {
    final root = await Directory.systemTemp.createTemp('edusheet-phase3-open-');
    addTearDown(() => root.delete(recursive: true));
    final store = TeachingResourceFileStore(rootResolver: () async => root);
    final coordinator = TeachingAttachmentOpenCoordinator(
      fileStore: store,
      documentRepository: DocumentRepository(),
    );

    Future<TeachingResource> managed(String id, String name, List<int> bytes) async {
      final relative = await store.writeBytes(
        resourceId: id,
        fileName: name,
        bytes: bytes,
      );
      return TeachingResource(
        id: id,
        owner: const TeachingResourceOwner.plannerClass('class'),
        kind: TeachingResourceKind.file,
        title: name,
        originalFileName: name,
        localRelativePath: relative,
        sizeBytes: bytes.length,
        createdAt: now,
        updatedAt: now,
      );
    }

    expect(
      (await coordinator.resolve(await managed('pdf', 'guide.pdf', [1]))).kind,
      TeachingAttachmentOpenKind.document,
    );
    expect(
      (await coordinator.resolve(await managed('image', 'diagram.png', [1]))).kind,
      TeachingAttachmentOpenKind.image,
    );
    expect(
      (await coordinator.resolve(await managed('eds', 'class.eds', [1]))).kind,
      TeachingAttachmentOpenKind.eds,
    );
    expect(
      (await coordinator.resolve(await managed('edtp', 'lesson.edtp', [1]))).kind,
      TeachingAttachmentOpenKind.edtp,
    );

    final missing = TeachingResource(
      id: 'missing',
      owner: const TeachingResourceOwner.plannerClass('class'),
      kind: TeachingResourceKind.file,
      title: 'missing.docx',
      originalFileName: 'missing.docx',
      localRelativePath: 'missing/missing.docx',
      createdAt: now,
      updatedAt: now,
    );
    expect(
      (await coordinator.resolve(missing)).kind,
      TeachingAttachmentOpenKind.missing,
    );
  });

  test('Teaching Pack never serializes a linked Windows path', () {
    final resource = TeachingResource(
      id: 'linked',
      owner: const TeachingResourceOwner.plannerClass('class'),
      kind: TeachingResourceKind.file,
      title: 'lesson.pdf',
      originalFileName: 'lesson.pdf',
      fileOwnership: TeachingResourceFileOwnership.linkedExternal,
      externalFilePath: r'C:\\School\\lesson.pdf',
      sizeBytes: 3,
      createdAt: now,
      updatedAt: now,
    );
    final source = const TeachingPackCodec().encode(
      TeachingPackPayload(
        sourceLessonTitle: 'Lesson',
        sourceClassName: 'Class 8',
        sourceSubjectName: 'Math',
        sourceChapterTitle: 'Algebra',
        resources: [
          TeachingPackResourcePayload(resource: resource, fileBytes: const [1, 2, 3]),
        ],
      ),
      exportedAt: now,
    );

    expect(source, isNot(contains(r'C:\\School\\lesson.pdf')));
    final decoded = const TeachingPackCodec().decode(source).resources.single.resource;
    expect(decoded.fileOwnership, TeachingResourceFileOwnership.managed);
    expect(decoded.externalFilePath, isNull);
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
