import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_unit.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/lesson_planner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 21, 8);

  test('older chapter JSON remains compatible and defaults to not started', () {
    final chapter = PlannerChapter.fromJson({
      'id': 'chapter-1',
      'subjectId': 'math',
      'title': 'Fractions',
      'sortOrder': 0,
      'plannedPeriods': 4,
      'priority': 'normal',
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });

    expect(chapter.status, TeachingProgressStatus.planned);
    expect(
      chapter
          .copyWith(status: TeachingProgressStatus.completed)
          .toJson()['status'],
      'completed',
    );
  });

  test(
    'taught lesson starts chapter progress and explicit finish completes it',
    () async {
      final repository = _MemoryPlannerRepository(_workspace(now));
      final service = TeachingPlannerService(
        repository,
        clock: () => now,
        idGenerator: () => 'new-id',
      );

      var workspace = await service.recordLessonProgress(
        'lesson-1',
        status: TeachingProgressStatus.completed,
        actualPeriods: 1,
        taughtAt: now,
      );

      expect(
        workspace.lessonPlanById('lesson-1')!.status,
        TeachingProgressStatus.completed,
      );
      expect(
        workspace.chapterById('chapter-1')!.status,
        TeachingProgressStatus.inProgress,
      );

      workspace = await service.updateChapterProgress(
        'chapter-1',
        status: TeachingProgressStatus.completed,
      );
      expect(
        workspace.chapterById('chapter-1')!.status,
        TeachingProgressStatus.completed,
      );
      expect(
        workspace.chapterById('chapter-2')!.status,
        TeachingProgressStatus.planned,
      );
    },
  );

  test('quick lesson keeps normal lesson schema with generated objective', () async {
    final repository = _MemoryPlannerRepository(_workspace(now));
    var counter = 0;
    final service = TeachingPlannerService(
      repository,
      clock: () => now,
      idGenerator: () => 'created-${counter++}',
    );

    final workspace = await service.createLessonPlan(
      classId: 'class-8',
      subjectId: 'math',
      chapterId: 'chapter-2',
      title: 'Polynomials',
      plannedDate: DateTime.utc(2026, 9, 22),
      plannedPeriods: 1,
      objective: 'Teach Polynomials.',
    );

    final created = workspace.lessonPlans.last;
    expect(created.objective, 'Teach Polynomials.');
    expect(created.chapterId, 'chapter-2');
    expect(created.status, TeachingProgressStatus.planned);
  });

  test('same teaching date can finish one chapter and start the next', () async {
    final repository = _MemoryPlannerRepository(_workspace(now));
    final service = TeachingPlannerService(
      repository,
      clock: () => now,
      idGenerator: () => 'lesson-2',
    );

    final workspace = await service.createLessonPlan(
      classId: 'class-8',
      subjectId: 'math',
      chapterId: 'chapter-2',
      title: 'Polynomials',
      plannedDate: DateTime.utc(2026, 9, 21),
      plannedPeriods: 1,
      objective: 'Start Polynomials.',
    );

    final sameDay = workspace.activeLessonPlans.where(
      (lesson) =>
          lesson.plannedDate.toUtc().year == 2026 &&
          lesson.plannedDate.toUtc().month == 9 &&
          lesson.plannedDate.toUtc().day == 21,
    );
    expect(sameDay, hasLength(2));
    expect(sameDay.map((item) => item.chapterId).toSet(), {
      'chapter-1',
      'chapter-2',
    });
  });

  testWidgets('quick planner hides optional detail form until requested', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _MemoryPlannerRepository(_workspace(now));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teachingPlannerRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const LessonPlannerScreen(
            openCreateOnStart: true,
            initialClassId: 'class-8',
            initialSubjectId: 'math',
            initialChapterId: 'chapter-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plan lesson'), findsWidgets);
    expect(find.byKey(const ValueKey('lesson-editor-date')), findsOneWidget);
    expect(find.byKey(const ValueKey('lesson-editor-periods')), findsOneWidget);
    expect(find.text('Learning objective (optional)'), findsNothing);

    final detailsToggle = find.text('Add teaching details (optional)');
    await tester.ensureVisible(detailsToggle);
    await tester.pumpAndSettle();
    await tester.tap(detailsToggle);
    await tester.pumpAndSettle();
    expect(find.text('Learning objective (optional)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one tap taught keeps chapter in progress until teacher finishes it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _MemoryPlannerRepository(_workspace(now));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teachingPlannerRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const LessonPlannerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final taughtCheckbox =
        find.byKey(const ValueKey('lesson-taught-lesson-1'));
    await tester.ensureVisible(taughtCheckbox);
    await tester.pumpAndSettle();
    await tester.tap(taughtCheckbox);
    await tester.pumpAndSettle();

    expect(
      repository.workspace.lessonPlanById('lesson-1')!.status,
      TeachingProgressStatus.completed,
    );
    expect(
      repository.workspace.chapterById('chapter-1')!.status,
      TeachingProgressStatus.inProgress,
    );
    expect(find.text('Finish chapter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

TeachingPlannerWorkspace _workspace(DateTime now) => TeachingPlannerWorkspace(
      classes: [
        PlannerClass(
          id: 'class-8',
          name: 'Class 8',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      subjects: [
        PlannerSubject(
          id: 'math',
          classId: 'class-8',
          name: 'Mathematics',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      units: [
        PlannerUnit(
          id: 'unit-1',
          subjectId: 'math',
          title: 'Algebra basics',
          sortOrder: 0,
          plannedPeriods: 5,
          createdAt: now,
          updatedAt: now,
        ),
        PlannerUnit(
          id: 'unit-2',
          subjectId: 'math',
          title: 'Advanced algebra',
          sortOrder: 1,
          plannedPeriods: 5,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      chapters: [
        PlannerChapter(
          id: 'chapter-1',
          subjectId: 'math',
          unitId: 'unit-1',
          title: 'Linear equations',
          sortOrder: 0,
          plannedPeriods: 3,
          createdAt: now,
          updatedAt: now,
        ),
        PlannerChapter(
          id: 'chapter-2',
          subjectId: 'math',
          unitId: 'unit-2',
          title: 'Polynomials',
          sortOrder: 0,
          plannedPeriods: 3,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      lessonPlans: [
        LessonPlan(
          id: 'lesson-1',
          classId: 'class-8',
          subjectId: 'math',
          chapterId: 'chapter-1',
          title: 'Linear equations',
          plannedDate: DateTime.utc(2026, 9, 21),
          plannedPeriods: 1,
          objective: 'Teach Linear equations.',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

class _MemoryPlannerRepository implements TeachingPlannerRepository {
  _MemoryPlannerRepository(this.workspace);

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
