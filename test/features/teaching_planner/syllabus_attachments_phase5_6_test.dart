import 'dart:io';
import 'dart:typed_data';

import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/application/teaching_resource_attachment_service.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_backup_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_resource_file_store.dart';
import 'package:edusheet/features/teaching_planner/domain/models/curriculum_merge_state.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_unit.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/models/syllabus_filter.dart';
import 'package:edusheet/features/teaching_planner/presentation/models/syllabus_node_ref.dart';
import 'package:edusheet/features/teaching_planner/presentation/services/syllabus_attachment_controller.dart';
import 'package:edusheet/features/teaching_planner/presentation/services/teaching_resource_file_picker.dart';
import 'package:edusheet/features/teaching_planner/presentation/widgets/syllabus_detail_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 9);

  test('portable .eds preserves syllabus attachment owners and exact bytes', () {
    final workspace = _workspace(now).copyWith(
      resources: [
        _fileResource(
          id: 'class-image',
          owner: const TeachingResourceOwner.plannerClass('class'),
          fileName: 'class-photo.png',
          mimeType: 'image/png',
          size: 3,
          now: now,
        ),
        _fileResource(
          id: 'subject-pdf',
          owner: const TeachingResourceOwner.subject('subject'),
          fileName: 'subject-notes.pdf',
          mimeType: 'application/pdf',
          size: 4,
          now: now,
        ),
        _fileResource(
          id: 'unit-document',
          owner: const TeachingResourceOwner.unit('unit'),
          fileName: 'unit-plan.docx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          size: 5,
          now: now,
        ),
        _fileResource(
          id: 'chapter-video',
          owner: const TeachingResourceOwner.chapter('chapter'),
          fileName: 'chapter-demo.mp4',
          mimeType: 'video/mp4',
          size: 6,
          now: now,
        ),
        _fileResource(
          id: 'topic-slides',
          owner: const TeachingResourceOwner.topic('topic'),
          fileName: 'topic-slides.pptx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          size: 2,
          now: now,
        ),
      ],
    );
    const resourceFiles = <String, List<int>>{
      'class-image': [1, 2, 3],
      'subject-pdf': [4, 5, 6, 7],
      'unit-document': [8, 9, 10, 11, 12],
      'chapter-video': [13, 14, 15, 16, 17, 18],
      'topic-slides': [19, 20],
    };

    const codec = TeachingPlannerBackupCodec();
    final encoded = codec.encode(
      workspace,
      exportedAt: now,
      resourceFiles: resourceFiles,
    );
    final decoded = codec.decodePayload(encoded);

    expect(encoded, startsWith('EDUSHEET/4\n'));
    expect(decoded.resourceFiles, resourceFiles);
    expect(
      decoded.workspace.resourceById('class-image')!.owner,
      const TeachingResourceOwner.plannerClass('class'),
    );
    expect(
      decoded.workspace.resourceById('subject-pdf')!.owner,
      const TeachingResourceOwner.subject('subject'),
    );
    expect(
      decoded.workspace.resourceById('unit-document')!.owner,
      const TeachingResourceOwner.unit('unit'),
    );
    expect(
      decoded.workspace.resourceById('chapter-video')!.owner,
      const TeachingResourceOwner.chapter('chapter'),
    );
    expect(
      decoded.workspace.resourceById('topic-slides')!.owner,
      const TeachingResourceOwner.topic('topic'),
    );
  });

  test('portable .eds refuses to omit any planner file attachment bytes', () {
    final workspace = _workspace(now).copyWith(
      resources: [
        _fileResource(
          id: 'required-file',
          owner: const TeachingResourceOwner.topic('topic'),
          fileName: 'required.pdf',
          mimeType: 'application/pdf',
          size: 3,
          now: now,
        ),
      ],
    );

    expect(
      () => const TeachingPlannerBackupCodec().encode(workspace),
      throwsA(isA<FormatException>()),
    );
  });

  testWidgets('every syllabus entity detail exposes its own attachment section', (
    tester,
  ) async {
    final workspace = _workspace(now).copyWith(
      resources: [
        _fileResource(
          id: 'class-file',
          owner: const TeachingResourceOwner.plannerClass('class'),
          fileName: 'class.png',
          mimeType: 'image/png',
          size: 1,
          now: now,
        ),
        _fileResource(
          id: 'subject-file',
          owner: const TeachingResourceOwner.subject('subject'),
          fileName: 'subject.pdf',
          mimeType: 'application/pdf',
          size: 1,
          now: now,
        ),
        _fileResource(
          id: 'unit-file',
          owner: const TeachingResourceOwner.unit('unit'),
          fileName: 'unit.docx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          size: 1,
          now: now,
        ),
        _fileResource(
          id: 'chapter-file',
          owner: const TeachingResourceOwner.chapter('chapter'),
          fileName: 'chapter.mp4',
          mimeType: 'video/mp4',
          size: 1,
          now: now,
        ),
        _fileResource(
          id: 'topic-file',
          owner: const TeachingResourceOwner.topic('topic'),
          fileName: 'topic.pptx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          size: 1,
          now: now,
        ),
      ],
    );

    final cases = <(SyllabusNodeRef, String)>[
      (const SyllabusNodeRef.classValue('class'), 'class.png'),
      (
        const SyllabusNodeRef.subject(classId: 'class', subjectId: 'subject'),
        'subject.pdf',
      ),
      (
        const SyllabusNodeRef.unit(
          classId: 'class',
          subjectId: 'subject',
          unitId: 'unit',
        ),
        'unit.docx',
      ),
      (
        const SyllabusNodeRef.chapter(
          classId: 'class',
          subjectId: 'subject',
          unitId: 'unit',
          chapterId: 'chapter',
        ),
        'chapter.mp4',
      ),
      (
        const SyllabusNodeRef.topic(
          classId: 'class',
          subjectId: 'subject',
          unitId: 'unit',
          chapterId: 'chapter',
          topicId: 'topic',
        ),
        'topic.pptx',
      ),
    ];

    for (final item in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyllabusDetailPanel(
              workspace: workspace,
              mergeState: CurriculumMergeState.empty(),
              selected: item.$1,
              query: '',
              filter: SyllabusFilter.all,
              reorderEnabled: true,
              onSelected: (_) {},
              onEdit: (_) {},
              onArchive: (_) {},
              onAddAttachments: (_) {},
              onOpenAttachment: (_) {},
              onRemoveAttachment: (_) {},
              onCreateSubject: (_) {},
              onCreateUnit: (_) {},
              onCreateChapter: (_, _) {},
              onCreateTopic: (_) {},
              onReorderSubjects: (_, _) {},
              onReorderUnits: (_, _) {},
              onReorderChapters: (_, _, _) {},
              onReorderTopics: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await _scrollDetailToAttachments(tester);

      expect(
        find.byKey(const ValueKey('syllabus-attachments-section')),
        findsOneWidget,
      );
      expect(find.text(item.$2), findsOneWidget);
      expect(find.text('Add files'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('attachment section remains usable in 320x520 free-form layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final workspace = _workspace(now).copyWith(
      resources: [
        _fileResource(
          id: 'narrow-file',
          owner: const TeachingResourceOwner.plannerClass('class'),
          fileName: 'wide-name-for-a-class-attachment-document.pdf',
          mimeType: 'application/pdf',
          size: 4096,
          now: now,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyllabusDetailPanel(
            workspace: workspace,
            mergeState: CurriculumMergeState.empty(),
            selected: const SyllabusNodeRef.classValue('class'),
            query: '',
            filter: SyllabusFilter.all,
            reorderEnabled: true,
            onSelected: (_) {},
            onEdit: (_) {},
            onArchive: (_) {},
            onAddAttachments: (_) {},
            onOpenAttachment: (_) {},
            onRemoveAttachment: (_) {},
            onCreateSubject: (_) {},
            onCreateUnit: (_) {},
            onCreateChapter: (_, _) {},
            onCreateTopic: (_) {},
            onReorderSubjects: (_, _) {},
            onReorderUnits: (_, _) {},
            onReorderChapters: (_, _, _) {},
            onReorderTopics: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await _scrollDetailToAttachments(tester);

    expect(find.text('Add files'), findsOneWidget);
    expect(
      find.text('wide-name-for-a-class-attachment-document.pdf'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('syllabus attachment controller stores a private file copy', () async {
    final root = await Directory.systemTemp.createTemp(
      'edusheet-syllabus-controller-',
    );
    addTearDown(() => root.delete(recursive: true));
    final repository = _MemoryRepository(_workspace(now));
    final store = TeachingResourceFileStore(rootResolver: () async => root);
    final plannerService = TeachingPlannerService(repository);
    final attachmentService = TeachingResourceAttachmentService(
      plannerService,
      store,
      idGenerator: () => 'private-copy-resource',
    );
    final picker = _FakePicker([
      TeachingAttachmentCandidate(
        fileName: 'diagram.png',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
    ]);
    final controller = SyllabusAttachmentController(
      picker: picker,
      attachFiles: ({required owner, required files}) async {
        await attachmentService.attachFiles(owner: owner, files: files);
        return true;
      },
      archiveResource: (_) async => true,
    );

    final result = await controller.addFiles(
      const SyllabusNodeRef.classValue('class'),
    );

    expect(result.success, isTrue);
    expect(result.cancelled, isFalse);
    expect(picker.pickCount, 1);
    final resource = repository.workspace
        .activeResourcesForClass('class')
        .single;
    expect(resource.id, 'private-copy-resource');
    expect(resource.owner, const TeachingResourceOwner.plannerClass('class'));
    expect(resource.mimeType, 'image/png');
    expect(await store.readBytes(resource.localRelativePath!), [1, 2, 3, 4]);
  });
}

Future<void> _scrollDetailToAttachments(WidgetTester tester) async {
  final target = find.byKey(const ValueKey('syllabus-attachments-section'));
  final list = find.byType(ListView).first;

  for (var attempt = 0; attempt < 8 && target.evaluate().isEmpty; attempt++) {
    expect(list, findsOneWidget);
    await tester.drag(list, const Offset(0, -260));
    await tester.pump();
  }

  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
}

TeachingResource _fileResource({
  required String id,
  required TeachingResourceOwner owner,
  required String fileName,
  required String mimeType,
  required int size,
  required DateTime now,
}) {
  return TeachingResource(
    id: id,
    owner: owner,
    kind: TeachingResourceKind.file,
    title: fileName,
    originalFileName: fileName,
    mimeType: mimeType,
    localRelativePath: '$id/$fileName',
    sizeBytes: size,
    createdAt: now,
    updatedAt: now,
  );
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
  units: [
    PlannerUnit(
      id: 'unit',
      subjectId: 'subject',
      title: 'Algebra',
      sortOrder: 0,
      plannedPeriods: 5,
      createdAt: now,
      updatedAt: now,
    ),
  ],
  chapters: [
    PlannerChapter(
      id: 'chapter',
      subjectId: 'subject',
      unitId: 'unit',
      title: 'Equations',
      sortOrder: 0,
      plannedPeriods: 3,
      createdAt: now,
      updatedAt: now,
    ),
  ],
  topics: [
    PlannerTopic(
      id: 'topic',
      chapterId: 'chapter',
      title: 'Linear equations',
      sortOrder: 0,
      plannedPeriods: 1,
      actualPeriods: 0,
      status: TeachingProgressStatus.planned,
      createdAt: now,
      updatedAt: now,
    ),
  ],
);

class _FakePicker extends TeachingResourceFilePicker {
  _FakePicker(this.files);

  final List<TeachingAttachmentCandidate> files;
  int pickCount = 0;

  @override
  Future<List<TeachingAttachmentCandidate>> pickFiles({
    String dialogTitle = 'Add teaching material',
    bool allowMultiple = true,
    bool readBytes = true,
  }) async {
    pickCount += 1;
    return files;
  }
}

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
