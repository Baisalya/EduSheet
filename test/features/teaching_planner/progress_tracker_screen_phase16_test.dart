import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/progress_tracker_screen.dart';
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
        plannedPeriods: 3,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    topics: [
      PlannerTopic(
        id: 't',
        chapterId: 'h',
        title: 'Linear equations',
        sortOrder: 0,
        plannedPeriods: 2,
        actualPeriods: 1,
        status: TeachingProgressStatus.inProgress,
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
        topicIds: const ['t'],
        title: 'Equation lesson',
        plannedDate: DateTime.utc(2026, 9, 9),
        plannedPeriods: 2,
        actualPeriods: 1,
        objective: 'Solve equations',
        status: TeachingProgressStatus.inProgress,
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );

  for (final size in const [
    Size(360, 800),
    Size(412, 915),
    Size(900, 700),
    Size(1366, 768),
  ]) {
    testWidgets(
      'progress tracker is responsive at ${size.width}x${size.height}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
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
        expect(find.text('Progress Tracking'), findsWidgets);
        expect(find.text('Syllabus completion'), findsOneWidget);
        expect(find.text('Topic status distribution'), findsOneWidget);
        expect(find.text('Priority-wise progress'), findsOneWidget);
        expect(find.text('Quick insights'), findsOneWidget);
        // Phase 19 intentionally shows an upcoming lesson in both the dashboard
        // and the editable teaching-progress panel. The responsive contract is
        // that the lesson remains reachable, not that its title is globally unique.
        expect(find.text('Equation lesson'), findsWidgets);
        expect(find.text('Linear equations'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
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
