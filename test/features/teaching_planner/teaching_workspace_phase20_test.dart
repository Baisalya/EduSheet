import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_pack_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_backup_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_document_codec.dart';
import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 8);

  test('schema 5 migrates to schema 8 with an empty resource collection', () {
    const codec = TeachingPlannerDocumentCodec();
    final workspace = codec.decode({
      'schemaVersion': 5,
      'updatedAt': now.toIso8601String(),
      'workspace': const {
        'classes': [],
        'subjects': [],
        'units': [],
        'chapters': [],
        'topics': [],
        'lessonPlans': [],
      },
    });
    expect(workspace.resources, isEmpty);
    expect(codec.encode(workspace)['schemaVersion'], 10);
  });

  test(
    'resource service keeps resources attached to a stable lesson id',
    () async {
      final repository = _MemoryRepository(_workspace(now));
      var counter = 0;
      final service = TeachingPlannerService(
        repository,
        idGenerator: () => 'resource-${counter++}',
        clock: () => now,
      );
      var workspace = await service.createTeachingResource(
        lessonPlanId: 'l',
        kind: TeachingResourceKind.note,
        title: 'Quadratic formula explanation',
        body: 'x = (-b ± √(b² - 4ac)) / 2a',
      );
      expect(workspace.resources.single.lessonPlanId, 'l');
      expect(workspace.resources.single.kind, TeachingResourceKind.note);
      final id = workspace.resources.single.id;
      workspace = await service.updateTeachingResource(
        id,
        role: TeachingResourceRole.teacherOnly,
        title: 'Teacher explanation',
        body: 'Use the discriminant before solving.',
      );
      expect(workspace.resources.single.id, id);
      expect(workspace.resources.single.role, TeachingResourceRole.teacherOnly);
    },
  );

  test('teaching pack carries metadata and attached bytes across devices', () {
    final resource = TeachingResource(
      id: 'r',
      lessonPlanId: 'l',
      kind: TeachingResourceKind.file,
      title: 'Worksheet.pdf',
      originalFileName: 'Worksheet.pdf',
      mimeType: 'application/pdf',
      localRelativePath: 'r/Worksheet.pdf',
      sizeBytes: 4,
      createdAt: now,
      updatedAt: now,
    );
    const codec = TeachingPackCodec();
    final encoded = codec.encode(
      TeachingPackPayload(
        sourceLessonTitle: 'Algebra lesson',
        sourceClassName: 'Class 10',
        sourceSubjectName: 'Math',
        sourceChapterTitle: 'Algebra',
        resources: [
          TeachingPackResourcePayload(
            resource: resource,
            fileBytes: const [1, 2, 3, 4],
          ),
        ],
      ),
    );
    final decoded = codec.decode(encoded);
    expect(encoded, startsWith('${TeachingPackCodec.magicHeader}\n'));
    expect(decoded.resources.single.fileBytes, [1, 2, 3, 4]);
    expect(decoded.resources.single.resource.originalFileName, 'Worksheet.pdf');
    expect(decoded.resources.single.resource.localRelativePath, isNull);
  });

  test('full .eds backup can embed teaching attachment bytes', () {
    final workspace = _workspace(now).copyWith(
      resources: [
        TeachingResource(
          id: 'file-resource',
          lessonPlanId: 'l',
          kind: TeachingResourceKind.file,
          title: 'Photo.png',
          originalFileName: 'Photo.png',
          mimeType: 'image/png',
          localRelativePath: 'file-resource/Photo.png',
          sizeBytes: 3,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    const codec = TeachingPlannerBackupCodec();
    final encoded = codec.encode(
      workspace,
      resourceFiles: const {
        'file-resource': [7, 8, 9],
      },
    );
    final decoded = codec.decodePayload(encoded);
    expect(decoded.workspace.resources.single.id, 'file-resource');
    expect(decoded.resourceFiles['file-resource'], [7, 8, 9]);
  });

  test('invalid resource links are rejected before persistence', () {
    final service = TeachingPlannerService(
      _MemoryRepository(_workspace(now)),
      clock: () => now,
    );
    expect(
      () => service.createTeachingResource(
        lessonPlanId: 'l',
        kind: TeachingResourceKind.link,
        title: 'Bad link',
        url: 'javascript:alert(1)',
      ),
      throwsA(isA<TeachingPlannerOperationException>()),
    );
  });
}

TeachingPlannerWorkspace _workspace(DateTime now) => TeachingPlannerWorkspace(
  classes: [
    PlannerClass(
      id: 'c',
      name: 'Class 10',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    ),
  ],
  subjects: [
    PlannerSubject(
      id: 's',
      classId: 'c',
      name: 'Math',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    ),
  ],
  chapters: [
    PlannerChapter(
      id: 'h',
      subjectId: 's',
      title: 'Algebra',
      sortOrder: 0,
      plannedPeriods: 3,
      createdAt: now,
      updatedAt: now,
    ),
  ],
  lessonPlans: [
    LessonPlan(
      id: 'l',
      classId: 'c',
      subjectId: 's',
      chapterId: 'h',
      title: 'Equation lesson',
      plannedDate: now,
      plannedPeriods: 1,
      objective: 'Solve equations',
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
  Future<void> save(TeachingPlannerWorkspace workspace) async =>
      this.workspace = workspace;
  @override
  Future<TeachingPlannerWorkspace> update(
    TeachingPlannerMutation mutation,
  ) async {
    workspace = mutation(workspace);
    return workspace;
  }
}
