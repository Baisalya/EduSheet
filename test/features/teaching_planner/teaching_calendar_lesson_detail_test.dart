import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_capabilities.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/teaching_calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('weekly agenda opens the shared lesson detail flow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
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
          id: 'lesson-today',
          classId: 'class-10',
          subjectId: 'math',
          chapterId: 'algebra',
          title: 'Today lesson',
          plannedDate: DateTime(now.year, now.month, now.day),
          plannedPeriods: 1,
          objective: 'Open the focused lesson detail.',
          status: TeachingProgressStatus.planned,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

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
          home: const TeachingCalendarScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final lessonCard = find.byKey(
      const ValueKey('planner-agenda-lesson-lesson-today'),
    );
    await tester.ensureVisible(lessonCard);
    await tester.tap(lessonCard);
    await tester.pumpAndSettle();

    expect(find.text('Lesson detail'), findsOneWidget);
    expect(find.text('Today lesson'), findsOneWidget);
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
