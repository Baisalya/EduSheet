import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_capabilities.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/teaching_planner_screen.dart';
import 'package:edusheet/features/teaching_planner/presentation/widgets/teaching_planner_home_navigation.dart';
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
      'first-run setup and skipped dashboard have no overflow at ${size.width}x${size.height}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              teachingPlannerRepositoryProvider.overrideWithValue(
                _MemoryPlannerRepository(),
              ),
              teachingPlannerCapabilitiesProvider.overrideWithValue(
                TeachingPlannerCapabilities.free(),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(useMaterial3: true),
              home: const TeachingPlannerScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Welcome to Teaching Planner'), findsOneWidget);
        expect(find.text('Create your first class'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('planner-setup-stepper')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('planner-setup-main-card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('planner-setup-summary')),
          findsOneWidget,
        );
        expect(find.text('Board or Curriculum'), findsNothing);
        expect(find.text('Study hours per day'), findsNothing);
        expect(
          find.byKey(const ValueKey('planner-setup-create-class')),
          findsOneWidget,
        );
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(NavigationRail), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('planner-setup-skip')));
        await tester.pumpAndSettle();

        expect(find.text('Teaching Planner'), findsOneWidget);
        expect(find.text('Plan today. Teach with clarity.'), findsOneWidget);
        expect(find.text('Overall teaching progress'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('planner-home-progress-card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('planner-home-refresh')),
          findsOneWidget,
        );
        expect(find.text('Next Exam'), findsNothing);
        expect(find.text('Create Task'), findsNothing);
        expect(find.text('Quick actions'), findsOneWidget);
        expect(find.text("Today's schedule"), findsOneWidget);
        expect(find.text('At a glance'), findsOneWidget);
        expect(find.text('My classes'), findsOneWidget);
        expect(find.text('More tools'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('planner-quick-create-class')),
          findsOneWidget,
        );
        if (size.width < 720) {
          expect(
            find.byKey(const ValueKey('planner-home-navigation-bar')),
            findsOneWidget,
          );
          expect(find.byType(TeachingPlannerHomeNavigationRail), findsNothing);
        } else {
          expect(find.byType(TeachingPlannerHomeNavigationBar), findsNothing);
          expect(
            find.byKey(const ValueKey('planner-home-navigation-rail')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('today lesson opens focused lesson detail from home', (
    tester,
  ) async {
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
          plannedPeriods: 2,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      lessonPlans: [
        LessonPlan(
          id: 'today-lesson',
          classId: 'class-10',
          subjectId: 'math',
          chapterId: 'algebra',
          title: 'Today algebra',
          plannedDate: DateTime(now.year, now.month, now.day),
          plannedPeriods: 1,
          objective: 'Open lesson detail from the dashboard.',
          status: TeachingProgressStatus.planned,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teachingPlannerRepositoryProvider.overrideWithValue(
            _MemoryPlannerRepository(workspace),
          ),
          teachingPlannerCapabilitiesProvider.overrideWithValue(
            TeachingPlannerCapabilities.free(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const TeachingPlannerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final lesson = find.byKey(
      const ValueKey('planner-home-lesson-today-lesson'),
    );
    await tester.ensureVisible(lesson);
    await tester.tap(lesson);
    await tester.pumpAndSettle();

    expect(find.text('Lesson detail'), findsOneWidget);
    expect(find.text('Today algebra'), findsOneWidget);
    expect(find.text('Teaching session'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guided class creation advances to syllabus step', (
    tester,
  ) async {
    final repository = _MemoryPlannerRepository();

    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teachingPlannerRepositoryProvider.overrideWithValue(repository),
          teachingPlannerCapabilitiesProvider.overrideWithValue(
            TeachingPlannerCapabilities.free(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const TeachingPlannerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final createClass = find.byKey(
      const ValueKey('planner-setup-create-class'),
    );
    await tester.ensureVisible(createClass);
    await tester.pumpAndSettle();
    await tester.tap(createClass);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Class 10');
    await tester.enterText(find.byType(TextFormField).at(1), '2026-27');
    await tester.tap(find.byKey(const ValueKey('planner-create-class-submit')));
    await tester.pumpAndSettle();

    expect(repository.workspace.activeClassCount, 1);
    expect(find.text('Add the syllabus you actually teach'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('planner-setup-build-syllabus')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _MemoryPlannerRepository implements TeachingPlannerRepository {
  _MemoryPlannerRepository([TeachingPlannerWorkspace? initial])
    : workspace = initial ?? TeachingPlannerWorkspace.empty();

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
