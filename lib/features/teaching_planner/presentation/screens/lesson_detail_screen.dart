import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/lesson_plan.dart';
import '../../domain/models/teaching_status.dart';
import '../design/teaching_planner_design_system.dart';
import '../layout/teaching_planner_breakpoints.dart';
import '../models/lesson_detail_model.dart';
import '../providers/teaching_planner_provider.dart';
import '../widgets/lesson_detail_sections.dart';
import '../widgets/lesson_teaching_session_sheet.dart';
import 'teaching_workspace_screen.dart';

class LessonDetailScreen extends ConsumerWidget {
  const LessonDetailScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(teachingPlannerProvider);
    final lesson = state.workspace.lessonPlanById(lessonId);
    if (lesson == null || lesson.isArchived) {
      return TeachingPlannerThemeScope(
        child: Scaffold(
          appBar: AppBar(title: const Text('Lesson detail')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'This lesson is no longer available in the active planner.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final model = LessonDetailModel.fromWorkspace(state.workspace, lesson);

    return TeachingPlannerThemeScope(
      child: Builder(
        builder: (context) {
          final colors = TeachingPlannerTheme.colorsOf(context);
          return Scaffold(
            backgroundColor: colors.canvas,
            appBar: AppBar(
              title: const Text('Lesson detail'),
              actions: [
                IconButton(
                  tooltip: 'Teaching materials',
                  onPressed: () => _openMaterials(context, lesson),
                  icon: const Icon(Icons.inventory_2_outlined),
                ),
              ],
            ),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final padding = TeachingPlannerBreakpoints.horizontalPadding(
                    constraints.maxWidth,
                    factor: 0.04,
                  );
                  final wide =
                      constraints.maxWidth >= TeachingPlannerBreakpoints.wide;

                  final plan = LessonPlanSections(model: model);
                  final session = LessonTeachingSessionCard(
                    model: model,
                    onUpdate: () => _recordSession(context, ref, lesson),
                    onComplete: model.isCompleted
                        ? null
                        : () => _recordSession(
                            context,
                            ref,
                            lesson,
                            suggestedStatus: TeachingProgressStatus.completed,
                          ),
                    onMaterials: () => _openMaterials(context, lesson),
                  );

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(padding, 14, padding, 48),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: TeachingPlannerDesign.contentMaxWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LessonDetailHero(
                              model: model,
                              onRecord: () => _recordSession(
                                context,
                                ref,
                                lesson,
                                suggestedStatus:
                                    lesson.status ==
                                        TeachingProgressStatus.planned
                                    ? TeachingProgressStatus.inProgress
                                    : null,
                              ),
                            ),
                            if (state.errorMessage != null) ...[
                              const SizedBox(
                                height: TeachingPlannerDesign.space12,
                              ),
                              MaterialBanner(
                                content: Text(state.errorMessage!),
                                actions: [
                                  TextButton(
                                    onPressed: () => ref
                                        .read(teachingPlannerProvider.notifier)
                                        .load(),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(
                              height: TeachingPlannerDesign.space14,
                            ),
                            LessonProgressSummary(model: model),
                            if (model.topics.isNotEmpty) ...[
                              const SizedBox(
                                height: TeachingPlannerDesign.space14,
                              ),
                              LessonTopicChecklist(model: model),
                            ],
                            const SizedBox(
                              height: TeachingPlannerDesign.space14,
                            ),
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 7, child: plan),
                                  const SizedBox(
                                    width: TeachingPlannerDesign.space14,
                                  ),
                                  Expanded(flex: 4, child: session),
                                ],
                              )
                            else ...[
                              session,
                              const SizedBox(
                                height: TeachingPlannerDesign.space14,
                              ),
                              plan,
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

  Future<void> _recordSession(
    BuildContext context,
    WidgetRef ref,
    LessonPlan lesson, {
    TeachingProgressStatus? suggestedStatus,
  }) async {
    final draft = await showLessonTeachingSessionSheet(
      context: context,
      lesson: lesson,
      suggestedStatus: suggestedStatus,
    );
    if (draft == null || !context.mounted) return;

    final ok = await ref
        .read(teachingPlannerProvider.notifier)
        .recordLessonProgress(
          lesson.id,
          status: draft.status,
          actualPeriods: draft.actualPeriods,
          taughtAt: draft.taughtAt,
          reflection: draft.reflection,
        );
    if (!context.mounted || ok) return;

    final message = ref.read(teachingPlannerProvider).errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _openMaterials(BuildContext context, LessonPlan lesson) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TeachingWorkspaceScreen(initialLessonId: lesson.id),
      ),
    );
  }
}
