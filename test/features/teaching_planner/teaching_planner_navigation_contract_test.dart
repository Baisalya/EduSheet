import 'package:edusheet/features/teaching_planner/presentation/navigation/teaching_planner_navigation.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/lesson_planner_screen.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/planner_insights_backup_screen.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/progress_tracker_screen.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/syllabus_manager_screen.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/teaching_calendar_screen.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/teaching_workspace_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teaching planner destination ids remain unique and stable', () {
    expect(
      TeachingPlannerDestination.values.map((destination) => destination.id),
      const [
        'syllabus',
        'lessons',
        'progress',
        'calendar',
        'workspace',
        'insights-backup',
      ],
    );

    expect(
      TeachingPlannerDestination.values
          .map((destination) => destination.id)
          .toSet()
          .length,
      TeachingPlannerDestination.values.length,
    );
  });

  test('primary workflow is separated from supporting tools', () {
    expect(TeachingPlannerDestination.primaryWorkflow, const [
      TeachingPlannerDestination.syllabus,
      TeachingPlannerDestination.lessons,
      TeachingPlannerDestination.progress,
    ]);
    expect(TeachingPlannerDestination.supportingTools, const [
      TeachingPlannerDestination.calendar,
      TeachingPlannerDestination.workspace,
      TeachingPlannerDestination.insightsBackup,
    ]);
  });

  test('navigation contract maps to existing feature screens', () {
    expect(
      TeachingPlannerNavigation.screenFor(TeachingPlannerDestination.syllabus),
      isA<SyllabusManagerScreen>(),
    );
    expect(
      TeachingPlannerNavigation.screenFor(TeachingPlannerDestination.lessons),
      isA<LessonPlannerScreen>(),
    );
    expect(
      TeachingPlannerNavigation.screenFor(TeachingPlannerDestination.progress),
      isA<ProgressTrackerScreen>(),
    );
    expect(
      TeachingPlannerNavigation.screenFor(TeachingPlannerDestination.calendar),
      isA<TeachingCalendarScreen>(),
    );
    expect(
      TeachingPlannerNavigation.screenFor(TeachingPlannerDestination.workspace),
      isA<TeachingWorkspaceScreen>(),
    );
    expect(
      TeachingPlannerNavigation.screenFor(
        TeachingPlannerDestination.insightsBackup,
      ),
      isA<PlannerInsightsBackupScreen>(),
    );
  });
}
