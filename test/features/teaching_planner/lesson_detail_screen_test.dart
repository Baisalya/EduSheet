import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/lesson_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [
    Size(360, 800),
    Size(412, 915),
    Size(600, 900),
    Size(900, 700),
    Size(1366, 768),
  ]) {
    testWidgets(
      'lesson detail has no overflow at ${size.width}x${size.height}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_app(_MemoryRepository(_workspace())));
        await tester.pumpAndSettle();

        expect(find.text('Lesson detail'), findsOneWidget);
        expect(find.text('Linear equations'), findsOneWidget);
        expect(find.text('Teaching session'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('lesson-detail-record-session')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('teaching session saves through planner provider', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _MemoryRepository(_workspace());
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('lesson-detail-record-session')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Teaching session'), findsWidgets);

    final periods = find.byKey(const ValueKey('lesson-session-actual-periods'));
    await tester.enterText(periods, '2');
    await tester.enterText(
      find.byKey(const ValueKey('lesson-session-reflection')),
      'Students solved the practice set.',
    );
    final save = find.byKey(const ValueKey('lesson-session-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final lesson = repository.workspace.lessonPlanById('lesson-1')!;
    expect(lesson.status, TeachingProgressStatus.inProgress);
    expect(lesson.actualPeriods, 2);
    expect(lesson.reflection, 'Students solved the practice set.');
    expect(lesson.taughtAt, isNotNull);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(_MemoryRepository repository) => ProviderScope(
  overrides: [teachingPlannerRepositoryProvider.overrideWithValue(repository)],
  child: MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: const LessonDetailScreen(lessonId: 'lesson-1'),
  ),
);

TeachingPlannerWorkspace _workspace() {
  final now = DateTime.utc(2026, 9, 15);
  return TeachingPlannerWorkspace(
    classes: [
      PlannerClass(
        id: 'class-10',
        name: 'Class 10',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    subjects: [
      PlannerSubject(
        id: 'math',
        classId: 'class-10',
        name: 'Mathematics',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    chapters: [
      PlannerChapter(
        id: 'algebra',
        subjectId: 'math',
        title: 'Algebra',
        sortOrder: 0,
        plannedPeriods: 4,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    lessonPlans: [
      LessonPlan(
        id: 'lesson-1',
        classId: 'class-10',
        subjectId: 'math',
        chapterId: 'algebra',
        title: 'Linear equations',
        plannedDate: DateTime.utc(2026, 9, 16),
        plannedPeriods: 2,
        objective: 'Students solve introductory linear equations.',
        materials: 'Board and practice worksheet.',
        activities: 'Worked examples followed by guided practice.',
        homework: 'Exercise 3A, questions 1–5.',
        notes: 'Check prerequisite integer operations first.',
        status: TeachingProgressStatus.planned,
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );
}

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
