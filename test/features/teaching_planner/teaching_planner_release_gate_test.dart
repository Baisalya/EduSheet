import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_priority.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_unit.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_capabilities.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/navigation/teaching_planner_navigation.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/teaching_planner/presentation/widgets/teaching_planner_home_navigation.dart';
import 'package:edusheet/features/teaching_planner/presentation/widgets/teaching_planner_page_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release viewport contract', () {
    for (final entry in const <(Size, bool)>[
      (Size(360, 800), false),
      (Size(719, 600), false),
      (Size(720, 600), true),
      (Size(800, 360), false),
      (Size(1366, 768), true),
    ]) {
      final size = entry.$1;
      final expectsRail = entry.$2;

      testWidgets('global shell is stable at ${size.width}x${size.height}', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: TeachingPlannerPageShell(
              title: 'Release gate',
              currentDestination: TeachingPlannerDestination.progress,
              body: SingleChildScrollView(
                child: SizedBox(height: 900, child: Text('Release body')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        if (expectsRail) {
          expect(
            find.byType(TeachingPlannerAdaptiveNavigationRail),
            findsOneWidget,
          );
          expect(
            find.byType(TeachingPlannerAdaptiveNavigationBar),
            findsNothing,
          );
        } else {
          expect(
            find.byType(TeachingPlannerAdaptiveNavigationBar),
            findsOneWidget,
          );
          expect(
            find.byType(TeachingPlannerAdaptiveNavigationRail),
            findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('top-level destination compatibility', () {
    final workspace = _releaseWorkspace();

    for (final size in const <Size>[
      Size(360, 800),
      Size(800, 360),
      Size(1366, 768),
    ]) {
      for (final destination in TeachingPlannerDestination.values) {
        testWidgets(
          '${destination.id} renders safely at ${size.width}x${size.height}',
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
                    TeachingPlannerCapabilities.pro(),
                  ),
                ],
                child: MaterialApp(
                  theme: ThemeData(useMaterial3: true),
                  home: TeachingPlannerNavigation.screenFor(destination),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}

TeachingPlannerWorkspace _releaseWorkspace() {
  final now = DateTime.utc(2026, 9, 15, 8);
  final tomorrow = now.add(const Duration(days: 1));

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
        id: 'math',
        classId: 'class-10',
        name: 'Mathematics',
        code: 'MATH',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    units: [
      PlannerUnit(
        id: 'algebra-unit',
        subjectId: 'math',
        title: 'Algebra',
        sortOrder: 0,
        plannedPeriods: 8,
        priority: PlannerPriority.high,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    chapters: [
      PlannerChapter(
        id: 'linear-equations',
        subjectId: 'math',
        unitId: 'algebra-unit',
        title: 'Linear Equations',
        sortOrder: 0,
        plannedPeriods: 4,
        priority: PlannerPriority.high,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    topics: [
      PlannerTopic(
        id: 'one-variable',
        chapterId: 'linear-equations',
        title: 'Equations in one variable',
        sortOrder: 0,
        plannedPeriods: 2,
        priority: PlannerPriority.high,
        actualPeriods: 2,
        status: TeachingProgressStatus.completed,
        createdAt: now,
        updatedAt: now,
      ),
      PlannerTopic(
        id: 'word-problems',
        chapterId: 'linear-equations',
        title: 'Word problems',
        sortOrder: 1,
        plannedPeriods: 2,
        priority: PlannerPriority.normal,
        actualPeriods: 0,
        status: TeachingProgressStatus.planned,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    lessonPlans: [
      LessonPlan(
        id: 'completed-lesson',
        classId: 'class-10',
        subjectId: 'math',
        chapterId: 'linear-equations',
        topicIds: const ['one-variable'],
        title: 'Solving equations',
        plannedDate: now.subtract(const Duration(days: 1)),
        plannedPeriods: 1,
        startPeriod: 2,
        objective: 'Solve linear equations in one variable.',
        materials: 'Board examples',
        activities: 'Guided practice',
        homework: 'Exercise 2A',
        notes: 'Check sign changes.',
        status: TeachingProgressStatus.completed,
        actualPeriods: 1,
        taughtAt: now.subtract(const Duration(days: 1)),
        reflection: 'Class completed the planned examples.',
        createdAt: now,
        updatedAt: now,
      ),
      LessonPlan(
        id: 'planned-lesson',
        classId: 'class-10',
        subjectId: 'math',
        chapterId: 'linear-equations',
        topicIds: const ['word-problems'],
        title: 'Equation word problems',
        plannedDate: tomorrow,
        plannedPeriods: 2,
        startPeriod: 3,
        objective: 'Translate word problems into equations.',
        status: TeachingProgressStatus.planned,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    resources: [
      TeachingResource(
        id: 'lesson-note',
        lessonPlanId: 'planned-lesson',
        kind: TeachingResourceKind.note,
        title: 'Worked examples',
        body: 'Use two examples before independent practice.',
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
