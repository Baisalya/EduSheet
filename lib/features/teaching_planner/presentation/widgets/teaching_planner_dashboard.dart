import 'package:flutter/material.dart';

import '../../domain/models/teaching_planner_capabilities.dart';
import '../design/teaching_planner_design_system.dart';
import '../layout/teaching_planner_breakpoints.dart';
import '../models/teaching_planner_dashboard_model.dart';
import '../navigation/teaching_planner_navigation.dart';
import '../providers/teaching_planner_provider.dart';
import 'teaching_planner_home_overview.dart';
import 'teaching_planner_home_progress.dart';
import 'teaching_planner_home_quick_actions.dart';
import 'teaching_planner_home_schedule.dart';

class TeachingPlannerDashboard extends StatelessWidget {
  const TeachingPlannerDashboard({
    super.key,
    required this.state,
    required this.capabilities,
    required this.onOpenDestination,
    required this.onOpenLesson,
    required this.onCreateClass,
    required this.onRetry,
    required this.onRefresh,
  });

  final TeachingPlannerState state;
  final TeachingPlannerCapabilities capabilities;
  final ValueChanged<TeachingPlannerDestination> onOpenDestination;
  final ValueChanged<String> onOpenLesson;
  final VoidCallback onCreateClass;
  final VoidCallback onRetry;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final model = TeachingPlannerDashboardModel.fromWorkspace(
      state.workspace,
      capabilities,
    );

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding =
              TeachingPlannerBreakpoints.horizontalPadding(
                constraints.maxWidth,
                factor: .042,
                max: 34,
              );
          final contentWidth = constraints.maxWidth - horizontalPadding * 2;
          final wideDashboard = contentWidth >= 920;

          return SingleChildScrollView(
            key: const ValueKey('planner-home-scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              TeachingPlannerDesign.space16,
              horizontalPadding,
              TeachingPlannerDesign.space40,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: TeachingPlannerDesign.contentMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TeachingPlannerHomeHeader(
                      accessLabel: model.accessLabel,
                      isLoading: state.isLoading,
                      onRefresh: onRefresh,
                    ),
                    const SizedBox(height: TeachingPlannerDesign.space20),
                    if (state.errorMessage != null) ...[
                      TeachingPlannerDashboardError(
                        message: state.errorMessage!,
                        onRetry: onRetry,
                      ),
                      const SizedBox(height: TeachingPlannerDesign.space18),
                    ],
                    TeachingPlannerProgressCard(
                      model: model,
                      onOpenProgress: () => onOpenDestination(
                        TeachingPlannerDestination.progress,
                      ),
                      onOpenCalendar: () => onOpenDestination(
                        TeachingPlannerDestination.calendar,
                      ),
                    ),
                    const SizedBox(height: TeachingPlannerDesign.space22),
                    TeachingPlannerQuickActions(
                      onCreateClass: onCreateClass,
                      onOpenDestination: onOpenDestination,
                    ),
                    const SizedBox(height: TeachingPlannerDesign.space22),
                    if (wideDashboard)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: TeachingPlannerTodaySchedule(
                              lessons: model.todayLessons,
                              onPlanLesson: () => onOpenDestination(
                                TeachingPlannerDestination.lessons,
                              ),
                              onOpenCalendar: () => onOpenDestination(
                                TeachingPlannerDestination.calendar,
                              ),
                              onOpenLesson: onOpenLesson,
                            ),
                          ),
                          const SizedBox(width: TeachingPlannerDesign.space18),
                          Expanded(
                            flex: 5,
                            child: TeachingPlannerFocusCards(
                              model: model,
                              onOpenProgress: () => onOpenDestination(
                                TeachingPlannerDestination.progress,
                              ),
                              onOpenCalendar: () => onOpenDestination(
                                TeachingPlannerDestination.calendar,
                              ),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      TeachingPlannerTodaySchedule(
                        lessons: model.todayLessons,
                        onPlanLesson: () => onOpenDestination(
                          TeachingPlannerDestination.lessons,
                        ),
                        onOpenCalendar: () => onOpenDestination(
                          TeachingPlannerDestination.calendar,
                        ),
                        onOpenLesson: onOpenLesson,
                      ),
                      const SizedBox(height: TeachingPlannerDesign.space22),
                      TeachingPlannerFocusCards(
                        model: model,
                        onOpenProgress: () => onOpenDestination(
                          TeachingPlannerDestination.progress,
                        ),
                        onOpenCalendar: () => onOpenDestination(
                          TeachingPlannerDestination.calendar,
                        ),
                      ),
                    ],
                    const SizedBox(height: TeachingPlannerDesign.space22),
                    TeachingPlannerClassesSection(
                      classes: model.classes,
                      isLoading: state.isLoading,
                      onCreateClass: onCreateClass,
                      onOpenSyllabus: () => onOpenDestination(
                        TeachingPlannerDestination.syllabus,
                      ),
                    ),
                    const SizedBox(height: TeachingPlannerDesign.space22),
                    TeachingPlannerMoreTools(
                      onOpenDestination: onOpenDestination,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
