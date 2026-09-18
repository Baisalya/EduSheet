import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_capabilities.dart';
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
    Size(600, 900),
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
              teachingPlannerCapabilitiesProvider.overrideWithValue(
                TeachingPlannerCapabilities.free(),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(useMaterial3: true),
              home: const ProgressTrackerScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Progress & Insights'), findsWidgets);
        expect(find.text('Overall Progress'), findsOneWidget);
        expect(find.text('Subject-wise Progress'), findsOneWidget);
        expect(find.text('Backlog Alerts'), findsOneWidget);
        expect(find.text('Teaching focus'), findsOneWidget);
        expect(find.text('Advanced teaching insights'), findsOneWidget);
        // A lesson may appear in a dashboard alert and the editable progress
        // panel. The responsive contract is reachability, not global uniqueness.
        expect(find.text('Equation lesson'), findsWidgets);
        expect(find.text('Linear equations'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('lesson progress opens the shared teaching session editor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teachingPlannerRepositoryProvider.overrideWithValue(
            _MemoryRepository(workspace),
          ),
          teachingPlannerCapabilitiesProvider.overrideWithValue(
            TeachingPlannerCapabilities.free(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const ProgressTrackerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final edit = find.byTooltip('Update lesson progress');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lesson-session-save')), findsOneWidget);
    expect(find.text('Teaching session'), findsOneWidget);
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
