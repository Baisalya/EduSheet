import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';

import '../../domain/models/planner_class.dart';
import '../../domain/models/teaching_planner_capabilities.dart';
import 'lesson_planner_screen.dart';
import 'planner_insights_backup_screen.dart';
import 'progress_tracker_screen.dart';
import 'teaching_calendar_screen.dart';
import 'teaching_workspace_screen.dart';
import 'syllabus_manager_screen.dart';
import '../providers/teaching_planner_provider.dart';

class TeachingPlannerScreen extends ConsumerWidget {
  const TeachingPlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(teachingPlannerProvider);
    final capabilities = ref.watch(teachingPlannerCapabilitiesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teaching Planner'),
        actions: [
          IconButton(
            tooltip: 'Refresh Teaching Planner',
            onPressed: state.isLoading
                ? null
                : () => ref.read(teachingPlannerProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Create class',
        onPressed: () => _showCreateClassSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Class'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = (constraints.maxWidth * 0.045)
                .clamp(12.0, 32.0)
                .toDouble();
            final contentWidth = constraints.maxWidth - horizontalPadding * 2;
            final showSideBySide = contentWidth >= 820;

            final summary = _PlannerSummary(
              state: state,
              capabilities: capabilities,
            );
            final classes = _ClassesPanel(state: state);

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                96,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: EdgeInsets.all(contentWidth < 420 ? 16 : 22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.55,
                          ),
                        ),
                        child: Wrap(
                          spacing: 18,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: contentWidth < 420 ? 34 : 42,
                              color: colorScheme.primary,
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: showSideBySide
                                    ? 760
                                    : contentWidth - 52,
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Plan teaching around your real syllabus',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Classes and syllabus structure are stored locally with stable identities, ordered relationships and safe archival.',
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SyllabusManagerScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.account_tree_rounded),
                              label: const Text('Manage syllabus'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const LessonPlannerScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.menu_book_rounded),
                              label: const Text('Plan lessons'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ProgressTrackerScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.insights_rounded),
                              label: const Text('Track progress'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TeachingCalendarScreen(),
                                ),
                              ),
                              icon: const Icon(
                                Icons.calendar_view_week_rounded,
                              ),
                              label: const Text('Teaching calendar'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TeachingWorkspaceScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.inventory_2_outlined),
                              label: const Text('Teaching workspace'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const PlannerInsightsBackupScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.analytics_outlined),
                              label: const Text('Insights & backup'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (state.errorMessage != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: MaterialBanner(
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
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (showSideBySide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 320, child: summary),
                            const SizedBox(width: 18),
                            Expanded(child: classes),
                          ],
                        )
                      else ...[
                        summary,
                        const SizedBox(height: 18),
                        classes,
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
  }

  Future<void> _showCreateClassSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showAdaptiveModalBottomSheet<_ClassDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _CreateClassSheet(),
    );
    if (result == null || !context.mounted) return;

    final saved = await ref
        .read(teachingPlannerProvider.notifier)
        .createClass(name: result.name, academicYear: result.academicYear);
    if (!context.mounted || saved) return;
    final message = ref.read(teachingPlannerProvider).errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _PlannerSummary extends StatelessWidget {
  const _PlannerSummary({required this.state, required this.capabilities});

  final TeachingPlannerState state;
  final TeachingPlannerCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final workspace = state.workspace;
    final accessLabel = switch (capabilities.accessLevel) {
      TeachingPlannerAccessLevel.free => 'Free',
      TeachingPlannerAccessLevel.pro => 'Pro',
      TeachingPlannerAccessLevel.complimentaryPro => 'Full access',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricChip(
                  label: 'Classes',
                  value: workspace.activeClassCount.toString(),
                ),
                _MetricChip(
                  label: 'Subjects',
                  value: workspace.activeSubjectCount.toString(),
                ),
                _MetricChip(
                  label: 'Topics',
                  value: workspace.activeTopicCount.toString(),
                ),
                _MetricChip(
                  label: 'Lessons',
                  value: workspace.activeLessonPlans.length.toString(),
                ),
                _MetricChip(label: 'Access', value: accessLabel),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 10),
            const _FoundationItem(
              icon: Icons.account_tree_outlined,
              title: 'Stable syllabus hierarchy',
              subtitle: 'Class → Subject → Unit → Chapter → Topic',
            ),
            const _FoundationItem(
              icon: Icons.menu_book_outlined,
              title: 'Syllabus-linked lesson plans',
              subtitle:
                  'Objectives, periods, activities, homework and teacher notes',
            ),
            const _FoundationItem(
              icon: Icons.save_outlined,
              title: 'Safe local persistence',
              subtitle: 'Atomic save, backup recovery and schema versioning',
            ),
            const _FoundationItem(
              icon: Icons.verified_user_outlined,
              title: 'Centralized capabilities',
              subtitle:
                  'Core planning remains available without scattered gates',
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassesPanel extends StatelessWidget {
  const _ClassesPanel({required this.state});

  final TeachingPlannerState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.workspace.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 260,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final classes = state.workspace.activeClasses;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'My Classes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              classes.isEmpty
                  ? 'Create a class to establish the syllabus hierarchy.'
                  : '${classes.length} active ${classes.length == 1 ? 'class' : 'classes'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (classes.isEmpty)
              const _EmptyClasses()
            else
              ...classes.map(
                (plannerClass) => _ClassTile(
                  plannerClass: plannerClass,
                  subjectCount: state.workspace
                      .activeSubjectsForClass(plannerClass.id)
                      .length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({required this.plannerClass, required this.subjectCount});

  final PlannerClass plannerClass;
  final int subjectCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: false,
      label:
          '${plannerClass.name}, $subjectCount ${subjectCount == 1 ? 'subject' : 'subjects'}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.school_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plannerClass.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (plannerClass.academicYear != null)
                        plannerClass.academicYear!,
                      '$subjectCount ${subjectCount == 1 ? 'subject' : 'subjects'}',
                    ].join(' • '),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyClasses extends StatelessWidget {
  const _EmptyClasses();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_outlined, size: 48),
          SizedBox(height: 12),
          Text(
            'No classes yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Use the Class button to create the first real planner record.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '$label  $value',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _FoundationItem extends StatelessWidget {
  const _FoundationItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateClassSheet extends StatefulWidget {
  const _CreateClassSheet();

  @override
  State<_CreateClassSheet> createState() => _CreateClassSheetState();
}

class _CreateClassSheetState extends State<_CreateClassSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _yearController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 6, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create class',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Class name',
                  hintText: 'Class 10',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a class name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _yearController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Academic year (optional)',
                  hintText: '2026–27',
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create class'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _ClassDraft(
        name: _nameController.text.trim(),
        academicYear: _yearController.text.trim().isEmpty
            ? null
            : _yearController.text.trim(),
      ),
    );
  }
}

class _ClassDraft {
  final String name;
  final String? academicYear;

  const _ClassDraft({required this.name, this.academicYear});
}
