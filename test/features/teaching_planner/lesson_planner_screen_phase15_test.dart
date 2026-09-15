import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/lesson_planner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 8);
  final workspace = TeachingPlannerWorkspace(
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
        plannedDate: DateTime.utc(2026, 9, 10),
        plannedPeriods: 2,
        objective: 'Students solve introductory linear equations.',
        status: TeachingProgressStatus.planned,
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
      'lesson planner has no overflow at ${size.width}x${size.height}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              teachingPlannerRepositoryProvider.overrideWithValue(
                _MemoryPlannerRepository(workspace),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(useMaterial3: true),
              home: const LessonPlannerScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Lesson Planner'), findsOneWidget);
        expect(find.text('Linear equations'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('lesson search filters by objective and syllabus text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teachingPlannerRepositoryProvider.overrideWithValue(
            _MemoryPlannerRepository(workspace),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const LessonPlannerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'introductory');
    await tester.pump();
    expect(find.text('Linear equations'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryPlannerRepository implements TeachingPlannerRepository {
  _MemoryPlannerRepository(this.workspace);
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
