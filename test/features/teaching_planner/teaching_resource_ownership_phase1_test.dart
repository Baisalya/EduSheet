import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_document_codec.dart';
import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/domain/services/teaching_planner_integrity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 8);

  test('schema 6 lesson resources migrate to generic lesson ownership', () {
    const codec = TeachingPlannerDocumentCodec();
    final workspace = codec.decode({
      'schemaVersion': 6,
      'updatedAt': now.toIso8601String(),
      'workspace': {
        'classes': [_class(now).toJson()],
        'subjects': [_subject(now).toJson()],
        'units': const [],
        'chapters': [_chapter(now).toJson()],
        'topics': const [],
        'lessonPlans': [_lesson(now).toJson()],
        'resources': [
          {
            'id': 'legacy-resource',
            'lessonPlanId': 'lesson',
            'kind': 'note',
            'role': 'teachInClass',
            'title': 'Legacy note',
            'body': 'Existing resource stays attached.',
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        ],
      },
    });

    final resource = workspace.resources.single;
    expect(resource.owner, const TeachingResourceOwner.lessonPlan('lesson'));
    expect(resource.lessonPlanId, 'lesson');
    expect(codec.encode(workspace)['schemaVersion'], 10);
    expect(
      (codec.encode(workspace)['workspace'] as Map)['resources'],
      isNotEmpty,
    );
  });

  test('service can attach a resource directly to a syllabus class', () async {
    final repository = _MemoryRepository(_workspace(now));
    final service = TeachingPlannerService(
      repository,
      idGenerator: () => 'class-resource',
      clock: () => now,
    );

    final workspace = await service.createTeachingResource(
      owner: const TeachingResourceOwner.plannerClass('class'),
      kind: TeachingResourceKind.note,
      title: 'General syllabus note',
      body: 'Applies to the complete class syllabus.',
    );

    final resource = workspace.resources.single;
    expect(resource.owner.type, TeachingResourceOwnerType.plannerClass);
    expect(resource.owner.id, 'class');
    expect(resource.lessonPlanId, isNull);
    expect(workspace.activeResourcesForClass('class'), [resource]);
    expect(workspace.activeResourcesForLesson('lesson'), isEmpty);
  });

  test('generic resource owner must point to a real planner entity', () {
    final workspace = _workspace(now).copyWith(
      resources: [
        TeachingResource(
          id: 'orphan-resource',
          owner: const TeachingResourceOwner.topic('missing-topic'),
          kind: TeachingResourceKind.note,
          title: 'Orphan',
          body: 'Should fail integrity validation.',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    expect(
      TeachingPlannerIntegrity.validate(workspace).map((issue) => issue.code),
      contains('missing_parent'),
    );
  });
}

TeachingPlannerWorkspace _workspace(DateTime now) => TeachingPlannerWorkspace(
  classes: [_class(now)],
  subjects: [_subject(now)],
  chapters: [_chapter(now)],
  lessonPlans: [_lesson(now)],
);

PlannerClass _class(DateTime now) => PlannerClass(
  id: 'class',
  name: 'Class 10',
  sortOrder: 0,
  createdAt: now,
  updatedAt: now,
);

PlannerSubject _subject(DateTime now) => PlannerSubject(
  id: 'subject',
  classId: 'class',
  name: 'Mathematics',
  sortOrder: 0,
  createdAt: now,
  updatedAt: now,
);

PlannerChapter _chapter(DateTime now) => PlannerChapter(
  id: 'chapter',
  subjectId: 'subject',
  title: 'Algebra',
  sortOrder: 0,
  plannedPeriods: 3,
  createdAt: now,
  updatedAt: now,
);

LessonPlan _lesson(DateTime now) => LessonPlan(
  id: 'lesson',
  classId: 'class',
  subjectId: 'subject',
  chapterId: 'chapter',
  title: 'Equation lesson',
  plannedDate: now,
  plannedPeriods: 1,
  objective: 'Solve equations',
  createdAt: now,
  updatedAt: now,
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
