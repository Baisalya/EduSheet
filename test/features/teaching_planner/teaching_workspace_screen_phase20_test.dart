import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/teaching_workspace_screen.dart';
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
        plannedPeriods: 2,
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
        title: 'Equation lesson',
        plannedDate: now,
        plannedPeriods: 1,
        objective: 'Solve equations',
        createdAt: now,
        updatedAt: now,
      ),
    ],
    resources: [
      TeachingResource(
        id: 'r',
        lessonPlanId: 'l',
        kind: TeachingResourceKind.note,
        title: 'Board steps',
        body: 'Explain balance method.',
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
      'teaching workspace is usable at ${size.width}x${size.height}',
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
              home: const TeachingWorkspaceScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Teaching workspace'), findsOneWidget);
        expect(find.text('Ready-to-teach desk'), findsOneWidget);
        expect(find.text('Math note'), findsOneWidget);
        expect(find.text('Geometry'), findsOneWidget);
        expect(find.text('Board steps'), findsOneWidget);
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
