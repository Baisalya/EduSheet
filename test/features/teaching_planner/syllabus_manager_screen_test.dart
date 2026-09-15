import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_priority.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_unit.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_capabilities.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/syllabus_manager_screen.dart';
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
        id: 'unit-1',
        subjectId: 'math',
        title: 'Number Systems',
        sortOrder: 0,
        plannedPeriods: 10,
        priority: PlannerPriority.high,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    chapters: [
      PlannerChapter(
        id: 'chapter-1',
        subjectId: 'math',
        unitId: 'unit-1',
        title: 'Real Numbers',
        sortOrder: 0,
        plannedPeriods: 6,
        priority: PlannerPriority.high,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    topics: [
      PlannerTopic(
        id: 'topic-1',
        chapterId: 'chapter-1',
        title: 'Euclid Division Lemma',
        sortOrder: 0,
        plannedPeriods: 2,
        priority: PlannerPriority.high,
        actualPeriods: 0,
        status: TeachingProgressStatus.planned,
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );

  for (final size in const [
    Size(320, 520),
    Size(360, 800),
    Size(412, 915),
    Size(600, 480),
    Size(900, 700),
    Size(1366, 768),
  ]) {
    testWidgets(
      'adaptive syllabus editor has no overflow at ${size.width}x${size.height}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_app(workspace));
        await tester.pumpAndSettle();

        expect(find.text('Syllabus Manager'), findsOneWidget);
        expect(find.text('Create syllabus'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('create syllabus starts with only name and academic year', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(TeachingPlannerWorkspace.empty()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create syllabus').first);
    await tester.pumpAndSettle();

    expect(find.text('Class / syllabus name'), findsOneWidget);
    expect(find.text('Academic year (optional)'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Class 8');
    await tester.enterText(find.byType(TextFormField).at(1), '2026-27');
    await tester.tap(find.text('Create and continue'));
    await tester.pumpAndSettle();

    expect(find.text('Class 8'), findsWidgets);
    expect(
      find.byKey(const ValueKey('syllabus-subjects-section')),
      findsOneWidget,
    );
    expect(find.text('Add subject'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact editor drills down one syllabus level at a time', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(workspace));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Class 10').first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('syllabus-subjects-section')),
      findsOneWidget,
    );
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Number Systems'), findsNothing);

    await tester.tap(find.text('Mathematics'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('syllabus-units-section')),
      findsOneWidget,
    );
    expect(find.text('Number Systems'), findsOneWidget);
    expect(find.text('Real Numbers'), findsNothing);

    await tester.tap(find.text('Number Systems'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('syllabus-chapters-section')),
      findsOneWidget,
    );
    expect(find.text('Real Numbers'), findsOneWidget);
    expect(find.text('Euclid Division Lemma'), findsNothing);

    await tester.tap(find.text('Real Numbers'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('syllabus-topics-section')),
      findsOneWidget,
    );
    expect(find.text('Euclid Division Lemma'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search exposes deeply nested content without manual drilling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(workspace));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Euclid');
    await tester.pumpAndSettle();

    expect(find.text('Euclid Division Lemma'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'high-priority filter keeps matching nested syllabus content visible',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_app(workspace));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'High priority'));
      await tester.pumpAndSettle();

      expect(find.text('Euclid Division Lemma'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(TeachingPlannerWorkspace workspace) {
  return ProviderScope(
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
      home: const SyllabusManagerScreen(),
    ),
  );
}

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
