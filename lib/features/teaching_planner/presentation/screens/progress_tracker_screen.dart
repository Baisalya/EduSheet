import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/lesson_plan.dart';
import '../../domain/models/planner_topic.dart';
import '../../domain/models/teaching_planner_capabilities.dart';
import '../../domain/models/teaching_status.dart';
import '../design/teaching_planner_design_system.dart';
import '../layout/teaching_planner_breakpoints.dart';
import '../models/progress_insights_model.dart';
import '../navigation/teaching_planner_navigation.dart';
import '../providers/teaching_planner_provider.dart';
import '../widgets/lesson_teaching_session_sheet.dart';
import '../widgets/progress_dashboard_cards.dart';
import '../widgets/progress_editor_panels.dart';
import '../widgets/teaching_planner_page_shell.dart';
import 'lesson_detail_screen.dart';

class ProgressTrackerScreen extends ConsumerStatefulWidget {
  const ProgressTrackerScreen({super.key});

  @override
  ConsumerState<ProgressTrackerScreen> createState() =>
      _ProgressTrackerScreenState();
}

class _ProgressTrackerScreenState extends ConsumerState<ProgressTrackerScreen> {
  String? _classId;
  TeachingProgressStatus? _status;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teachingPlannerProvider);
    final capabilities = ref.watch(teachingPlannerCapabilitiesProvider);
    final workspace = state.workspace;
    final classes = workspace.activeClasses;

    final lessons = workspace.activeLessonPlans.where((lesson) {
      if (_classId != null && lesson.classId != _classId) return false;
      if (_status != null && lesson.status != _status) return false;
      return true;
    }).toList();

    final topics = workspace.topics.where((topic) {
      if (topic.isArchived) return false;
      if (_status != null && topic.status != _status) return false;
      if (_classId == null) return true;
      final chapter = workspace.chapterById(topic.chapterId);
      if (chapter == null) return false;
      final subject = workspace.subjectById(chapter.subjectId);
      return subject?.classId == _classId;
    }).toList();

    final dashboard = ProgressInsightsModel.fromWorkspace(
      workspace,
      classId: _classId,
      now: DateTime.now(),
    );
    final canUseAdvanced = capabilities.allows(
      TeachingPlannerCapability.advancedDashboards,
    );

    return TeachingPlannerPageShell(
      title: 'Progress & Insights',
      currentDestination: TeachingPlannerDestination.progress,
      actions: [
        IconButton(
          tooltip: 'Refresh progress',
          onPressed: state.isLoading
              ? null
              : () => ref.read(teachingPlannerProvider.notifier).load(),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Builder(
        builder: (context) {
          final colors = TeachingPlannerTheme.colorsOf(context);
          return ColoredBox(
            color: colors.canvas,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final padding = TeachingPlannerBreakpoints.horizontalPadding(
                    constraints.maxWidth,
                  );
                  final wide =
                      constraints.maxWidth >=
                      TeachingPlannerBreakpoints.twoPane;
                  String classNameFor(String classId) =>
                      workspace.classById(classId)?.name ?? 'Class';

                  final lessonPanel = LessonProgressPanel(
                    lessons: lessons,
                    workspace: workspace,
                    onEdit: _editLessonProgress,
                  );
                  final topicPanel = TopicProgressPanel(
                    topics: topics,
                    workspace: workspace,
                    onEdit: _editTopicProgress,
                  );

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(padding, 16, padding, 52),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1380),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ProgressPageHeader(
                              className: _classId == null
                                  ? 'All classes'
                                  : classNameFor(_classId!),
                              onRefresh: state.isLoading
                                  ? null
                                  : () => ref
                                        .read(teachingPlannerProvider.notifier)
                                        .load(),
                            ),
                            const SizedBox(
                              height: TeachingPlannerDesign.space18,
                            ),
                            ProgressDashboard(
                              model: dashboard,
                              advancedEnabled: canUseAdvanced,
                              onOpenLesson: _openLessonDetail,
                            ),
                            const SizedBox(
                              height: TeachingPlannerDesign.space22,
                            ),
                            Text(
                              'Update teaching progress',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: colors.ink,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(
                              height: TeachingPlannerDesign.space4,
                            ),
                            Text(
                              'Filter the workspace, then record the real lesson and syllabus progress.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.inkMuted),
                            ),
                            const SizedBox(
                              height: TeachingPlannerDesign.space12,
                            ),
                            ProgressFilterBar(
                              classes: classes
                                  .map((item) => (item.id, item.name))
                                  .toList(),
                              classId: _classId,
                              status: _status,
                              onClassChanged: (value) =>
                                  setState(() => _classId = value),
                              onStatusChanged: (value) =>
                                  setState(() => _status = value),
                            ),
                            const SizedBox(
                              height: TeachingPlannerDesign.space14,
                            ),
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: lessonPanel),
                                  const SizedBox(
                                    width: TeachingPlannerDesign.space14,
                                  ),
                                  Expanded(child: topicPanel),
                                ],
                              )
                            else ...[
                              lessonPanel,
                              const SizedBox(
                                height: TeachingPlannerDesign.space14,
                              ),
                              topicPanel,
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _openLessonDetail(LessonPlan lesson) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonDetailScreen(lessonId: lesson.id),
      ),
    );
  }

  Future<void> _editLessonProgress(LessonPlan lesson) async {
    final draft = await showLessonTeachingSessionSheet(
      context: context,
      lesson: lesson,
    );
    if (draft == null || !mounted) return;

    final ok = await ref
        .read(teachingPlannerProvider.notifier)
        .recordLessonProgress(
          lesson.id,
          status: draft.status,
          actualPeriods: draft.actualPeriods,
          taughtAt: draft.taughtAt,
          reflection: draft.reflection,
        );
    if (!mounted || ok) return;
    _showSaveError();
  }

  Future<void> _editTopicProgress(PlannerTopic topic) async {
    final draft = await showTopicProgressSheet(context: context, topic: topic);
    if (draft == null || !mounted) return;

    final ok = await ref
        .read(teachingPlannerProvider.notifier)
        .updateTopicProgress(
          topic.id,
          status: draft.status,
          actualPeriods: draft.actualPeriods,
        );
    if (!mounted || ok) return;
    _showSaveError();
  }

  void _showSaveError() {
    final message = ref.read(teachingPlannerProvider).errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
