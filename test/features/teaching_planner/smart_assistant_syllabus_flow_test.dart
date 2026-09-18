import 'package:edusheet/features/guided_experience/application/smart_work_activity_controller.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/syllabus_manager_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 9, 16);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Show Me opens subject form for the focused class', (tester) async {
    final workspace = TeachingPlannerWorkspace(
      classes: [
        PlannerClass(
          id: 'class-8',
          name: 'Class 8',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    await _pumpSyllabus(tester, workspace);

    expect(find.text('Add a subject to Class 8?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('smart-work-assistant-show-me')));
    await tester.pumpAndSettle();

    expect(find.text('Subject details'), findsOneWidget);
    expect(find.text('Subject name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guided syllabus setup does not show a second assistant layer', (tester) async {
    final workspace = TeachingPlannerWorkspace(
      classes: [
        PlannerClass(
          id: 'class-8',
          name: 'Class 8',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    await _pumpSyllabus(tester, workspace, guidedSetup: true);

    expect(find.text('Smart Work Assistant'), findsNothing);
    expect(find.text('Add a subject to Class 8?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Show Me opens chapter form for the focused subject', (tester) async {
    final workspace = TeachingPlannerWorkspace(
      classes: [
        PlannerClass(
          id: 'class-8',
          name: 'Class 8',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      subjects: [
        PlannerSubject(
          id: 'math',
          classId: 'class-8',
          name: 'Mathematics',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    await _pumpSyllabus(tester, workspace);

    expect(find.text('Add a chapter to Mathematics?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('smart-work-assistant-show-me')));
    await tester.pumpAndSettle();

    expect(find.text('Chapter details'), findsOneWidget);
    expect(find.text('Chapter title'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpSyllabus(
  WidgetTester tester,
  TeachingPlannerWorkspace workspace, {
  bool guidedSetup = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(412, 915));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        teachingPlannerRepositoryProvider.overrideWithValue(
          _MemoryPlannerRepository(workspace),
        ),
        smartWorkActivityControllerProvider.overrideWith(
          (ref) => SmartWorkActivityController(
            now: DateTime.now().subtract(const Duration(minutes: 2)),
          ),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: SyllabusManagerScreen(
          initialClassId: 'class-8',
          guidedSetup: guidedSetup,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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
