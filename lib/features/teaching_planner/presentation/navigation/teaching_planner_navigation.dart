import 'package:flutter/material.dart';

import '../screens/lesson_planner_screen.dart';
import '../screens/planner_insights_backup_screen.dart';
import '../screens/progress_tracker_screen.dart';
import '../screens/syllabus_manager_screen.dart';
import '../screens/teaching_calendar_screen.dart';
import '../screens/teaching_workspace_screen.dart';

enum TeachingPlannerDestinationGroup { primaryWorkflow, supportingTools }

enum TeachingPlannerDestination {
  syllabus(
    id: 'syllabus',
    label: 'Manage syllabus',
    shortLabel: 'Syllabus',
    description: 'Build classes, subjects, units, chapters and topics.',
    icon: Icons.account_tree_rounded,
    group: TeachingPlannerDestinationGroup.primaryWorkflow,
  ),
  lessons(
    id: 'lessons',
    label: 'Plan lessons',
    shortLabel: 'Lessons',
    description: 'Create syllabus-linked lesson plans and teaching details.',
    icon: Icons.menu_book_rounded,
    group: TeachingPlannerDestinationGroup.primaryWorkflow,
  ),
  progress(
    id: 'progress',
    label: 'Track progress',
    shortLabel: 'Progress',
    description: 'Review syllabus and lesson completion.',
    icon: Icons.insights_rounded,
    group: TeachingPlannerDestinationGroup.primaryWorkflow,
  ),
  calendar(
    id: 'calendar',
    label: 'Weekly planner',
    shortLabel: 'Planner',
    description: 'Plan the teaching week and review period conflicts by day.',
    icon: Icons.calendar_view_week_rounded,
    group: TeachingPlannerDestinationGroup.supportingTools,
  ),
  workspace(
    id: 'workspace',
    label: 'Teaching workspace',
    shortLabel: 'Workspace',
    description: 'Open teaching resources, notes and lesson materials.',
    icon: Icons.inventory_2_outlined,
    group: TeachingPlannerDestinationGroup.supportingTools,
  ),
  insightsBackup(
    id: 'insights-backup',
    label: 'Insights & backup',
    shortLabel: 'More',
    description: 'Review planner insights and manage backup or restore.',
    icon: Icons.analytics_outlined,
    group: TeachingPlannerDestinationGroup.supportingTools,
  );

  const TeachingPlannerDestination({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.description,
    required this.icon,
    required this.group,
  });

  final String id;
  final String label;
  final String shortLabel;
  final String description;
  final IconData icon;
  final TeachingPlannerDestinationGroup group;

  static List<TeachingPlannerDestination> get primaryWorkflow => values
      .where(
        (destination) =>
            destination.group ==
            TeachingPlannerDestinationGroup.primaryWorkflow,
      )
      .toList(growable: false);

  static List<TeachingPlannerDestination> get supportingTools => values
      .where(
        (destination) =>
            destination.group ==
            TeachingPlannerDestinationGroup.supportingTools,
      )
      .toList(growable: false);
}

abstract final class TeachingPlannerNavigation {
  static Route<void> routeFor(TeachingPlannerDestination destination) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: 'teaching-planner/${destination.id}'),
      builder: (_) => screenFor(destination),
    );
  }

  static Widget screenFor(TeachingPlannerDestination destination) {
    return switch (destination) {
      TeachingPlannerDestination.syllabus => const SyllabusManagerScreen(),
      TeachingPlannerDestination.lessons => const LessonPlannerScreen(),
      TeachingPlannerDestination.progress => const ProgressTrackerScreen(),
      TeachingPlannerDestination.calendar => const TeachingCalendarScreen(),
      TeachingPlannerDestination.workspace => const TeachingWorkspaceScreen(),
      TeachingPlannerDestination.insightsBackup =>
        const PlannerInsightsBackupScreen(),
    };
  }

  static Future<void> open(
    BuildContext context,
    TeachingPlannerDestination destination,
  ) async {
    await Navigator.of(context).push<void>(routeFor(destination));
  }

  static Future<void> openSyllabus(
    BuildContext context, {
    String? initialClassId,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'teaching-planner/syllabus/setup'),
        builder: (_) => SyllabusManagerScreen(
          initialClassId: initialClassId,
          guidedSetup: true,
        ),
      ),
    );
  }

  static Future<void> openLessons(
    BuildContext context, {
    bool createImmediately = false,
    bool returnAfterCreate = false,
    String? initialClassId,
    String? initialSubjectId,
    String? initialChapterId,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'teaching-planner/lessons/setup'),
        builder: (_) => LessonPlannerScreen(
          openCreateOnStart: createImmediately,
          returnAfterInitialCreate: returnAfterCreate,
          initialClassId: initialClassId,
          initialSubjectId: initialSubjectId,
          initialChapterId: initialChapterId,
        ),
      ),
    );
  }
}
