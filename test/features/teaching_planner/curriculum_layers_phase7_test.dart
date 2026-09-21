import 'dart:io';

import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/data/local_teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/domain/models/curriculum_layer_policy.dart';
import 'package:edusheet/features/teaching_planner/domain/models/curriculum_merge_state.dart';
import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/presentation/models/syllabus_filter.dart';
import 'package:edusheet/features/teaching_planner/presentation/models/syllabus_node_ref.dart';
import 'package:edusheet/features/teaching_planner/presentation/widgets/syllabus_detail_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 18, 12);

  test('layer policy distinguishes official master from teacher workspace', () {
    final state = CurriculumMergeState(
      replicas: [
        _record('class', 'class-local', 'class-origin', now),
        _record('lessonPlan', 'lesson-local', 'lesson-origin', now),
      ],
    );
    final policy = CurriculumLayerPolicy(state);

    final official = policy.describe('class', 'class-local');
    final local = policy.describe('resource', 'teacher-note');

    expect(official.isOfficial, isTrue);
    expect(official.label, 'Official curriculum');
    expect(official.sourceSchool, 'ABC School');
    expect(local.isTeacherOwned, isTrue);
    expect(local.label, 'Teacher workspace');
    expect(policy.canRecordTeacherExecution('lessonPlan', 'lesson-local'), isTrue);
  });

  test('official master structure is guarded while teacher execution stays writable', () async {
    final temp = await Directory.systemTemp.createTemp('eds-phase7-layer-');
    addTearDown(() => temp.delete(recursive: true));
    final repository = LocalTeachingPlannerRepository(
      fileResolver: () async => File('${temp.path}/planner.json'),
    );
    final workspace = _workspace(now);
    final mergeState = CurriculumMergeState(
      replicas: [
        _record('class', 'class-10', 'class-origin', now),
        _record('subject', 'maths', 'subject-origin', now),
        _record('chapter', 'chapter-1', 'chapter-origin', now),
        _record('topic', 'topic-1', 'topic-origin', now),
        _record('lessonPlan', 'lesson-1', 'lesson-origin', now),
      ],
    );
    await repository.replaceWorkspaceWithMergeState(workspace, mergeState);
    final service = TeachingPlannerService(
      repository,
      idGenerator: () => 'teacher-resource',
      clock: () => now.add(const Duration(hours: 1)),
    );

    await expectLater(
      service.updateChapter(
        'chapter-1',
        title: 'Teacher changed master title',
        plannedPeriods: 6,
        priority: workspace.chapterById('chapter-1')!.priority,
      ),
      throwsA(isA<TeachingPlannerOperationException>()),
    );
    await expectLater(
      service.archiveLessonPlan('lesson-1'),
      throwsA(isA<TeachingPlannerOperationException>()),
    );

    final progressed = await service.recordLessonProgress(
      'lesson-1',
      status: TeachingProgressStatus.completed,
      actualPeriods: 2,
      reflection: 'Teacher reflection remains in the working layer.',
    );
    expect(progressed.lessonPlanById('lesson-1')?.actualPeriods, 2);
    expect(
      progressed.lessonPlanById('lesson-1')?.reflection,
      'Teacher reflection remains in the working layer.',
    );

    final withNote = await service.createTeachingResource(
      lessonPlanId: 'lesson-1',
      kind: TeachingResourceKind.note,
      title: 'My classroom note',
      body: 'Teacher-owned note',
    );
    expect(withNote.resourceById('teacher-resource')?.body, 'Teacher-owned note');

    final stored = await repository.loadCurriculumMergeSnapshot();
    expect(stored.workspace.chapterById('chapter-1')?.title, 'Quadratic Equations');
    expect(
      stored.mergeState.isOfficialLocalId('resource', 'teacher-resource'),
      isFalse,
    );
  });

  testWidgets('official syllabus surface exposes master layer and hides structure creation', (tester) async {
    final workspace = _workspace(now);
    final mergeState = CurriculumMergeState(
      replicas: [
        _record('class', 'class-10', 'class-origin', now),
        _record('subject', 'maths', 'subject-origin', now),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyllabusDetailPanel(
            workspace: workspace,
            mergeState: mergeState,
            selected: const SyllabusNodeRef.classValue('class-10'),
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
    await tester.pumpAndSettle();

    expect(find.text('Official curriculum'), findsOneWidget);
    expect(find.textContaining('Received from ABC School'), findsOneWidget);
    expect(find.text('Add subject'), findsNothing);
    final editButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Edit details'),
    );
    expect(editButton.onPressed, isNull);
  });
}

CurriculumReplicaRecord _record(
  String type,
  String localId,
  String originId,
  DateTime now,
) {
  return CurriculumReplicaRecord(
    entityType: type,
    localId: localId,
    originId: originId,
    sourceRevision: now.millisecondsSinceEpoch,
    sourceUpdatedAt: now,
    importedAt: now,
    sourcePackageOriginId: 'assignment-1',
    sourceSchool: 'ABC School',
    assignmentId: 'assignment-1',
  );
}

TeachingPlannerWorkspace _workspace(DateTime now) {
  return TeachingPlannerWorkspace(
    classes: [
      PlannerClass(
        id: 'class-10',
        name: 'Class 10',
        academicYear: '2026-27',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    subjects: [
      PlannerSubject(
        id: 'maths',
        classId: 'class-10',
        name: 'Mathematics',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    chapters: [
      PlannerChapter(
        id: 'chapter-1',
        subjectId: 'maths',
        title: 'Quadratic Equations',
        sortOrder: 0,
        plannedPeriods: 6,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    topics: [
      PlannerTopic(
        id: 'topic-1',
        chapterId: 'chapter-1',
        title: 'Roots',
        sortOrder: 0,
        plannedPeriods: 2,
        actualPeriods: 0,
        status: TeachingProgressStatus.planned,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    lessonPlans: [
      LessonPlan(
        id: 'lesson-1',
        classId: 'class-10',
        subjectId: 'maths',
        chapterId: 'chapter-1',
        topicIds: const ['topic-1'],
        title: 'Introduction to roots',
        plannedDate: now,
        plannedPeriods: 1,
        objective: 'Understand roots.',
        status: TeachingProgressStatus.planned,
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );
}
