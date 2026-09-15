import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_priority.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/progress_tracker_screen.dart';
import 'package:edusheet/features/teaching_planner/presentation/widgets/progress_dashboard_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 8);
  final workspace = TeachingPlannerWorkspace(
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
        plannedPeriods: 6,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    topics: [
      PlannerTopic(
        id: 't1',
        chapterId: 'h',
        title: 'Linear equations',
        sortOrder: 0,
        plannedPeriods: 2,
        actualPeriods: 2,
        priority: PlannerPriority.high,
        status: TeachingProgressStatus.completed,
        createdAt: now,
        updatedAt: now,
      ),
      PlannerTopic(
        id: 't2',
        chapterId: 'h',
        title: 'Identities',
        sortOrder: 1,
        plannedPeriods: 2,
        actualPeriods: 1,
        priority: PlannerPriority.normal,
        status: TeachingProgressStatus.inProgress,
        createdAt: now,
        updatedAt: now,
      ),
      PlannerTopic(
        id: 't3',
        chapterId: 'h',
        title: 'Polynomials',
        sortOrder: 2,
        plannedPeriods: 2,
        actualPeriods: 0,
        priority: PlannerPriority.low,
        status: TeachingProgressStatus.planned,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    lessonPlans: [
      LessonPlan(
        id: 'l1',
        classId: 'c',
        subjectId: 's',
        chapterId: 'h',
        topicIds: const ['t1'],
        title: 'Equation lesson',
        plannedDate: DateTime.utc(2026, 9, 8),
        plannedPeriods: 2,
        actualPeriods: 2,
        objective: 'Solve equations',
        status: TeachingProgressStatus.completed,
        taughtAt: DateTime.utc(2026, 9, 8),
        createdAt: now,
        updatedAt: now,
      ),
      LessonPlan(
        id: 'l2',
        classId: 'c',
        subjectId: 's',
        chapterId: 'h',
        topicIds: const ['t2'],
        title: 'Identity lesson',
        plannedDate: DateTime.utc(2026, 9, 10),
        plannedPeriods: 2,
        actualPeriods: 0,
        objective: 'Use identities',
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );

  testWidgets('phase 19 dashboard exposes visual teacher metrics', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teachingPlannerRepositoryProvider.overrideWithValue(
            _MemoryRepository(workspace),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const ProgressTrackerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnimatedProgressRing), findsWidgets);
    expect(find.text('Syllabus completion'), findsOneWidget);
    expect(find.text('Lessons taught'), findsOneWidget);
    expect(find.text('Progress over time'), findsOneWidget);
    expect(find.text('Topic status distribution'), findsOneWidget);
    expect(find.text('Priority-wise progress'), findsOneWidget);
    expect(find.text('Upcoming work (next 7 days)'), findsOneWidget);
    expect(find.text('Quick insights'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
