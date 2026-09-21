import 'package:flutter/material.dart';

import '../../../guided_experience/guides/create_syllabus_guide.dart';
import '../../../guided_experience/presentation/widgets/guide_anchor.dart';

import '../design/teaching_planner_design_system.dart';
import '../models/teaching_planner_setup_model.dart';
import 'teaching_planner_shared_components.dart';

class TeachingPlannerFirstRunSetup extends StatelessWidget {
  const TeachingPlannerFirstRunSetup({
    super.key,
    required this.model,
    required this.isLoading,
    required this.onCreateClass,
    required this.onOpenSyllabus,
    required this.onPlanFirstLesson,
    required this.onSkip,
    required this.onRetry,
    this.errorMessage,
  });

  final TeachingPlannerSetupModel model;
  final bool isLoading;
  final VoidCallback onCreateClass;
  final VoidCallback onOpenSyllabus;
  final VoidCallback onPlanFirstLesson;
  final VoidCallback onSkip;
  final VoidCallback onRetry;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = (constraints.maxWidth * .045).clamp(16.0, 38.0);
          final wide = constraints.maxWidth >= 880;

          return SingleChildScrollView(
            key: const ValueKey('planner-setup-scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(padding, 14, padding, 34),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SetupHeader(onSkip: onSkip),
                    const SizedBox(height: TeachingPlannerDesign.space22),
                    _SetupStepper(currentStep: model.currentStep),
                    if (errorMessage != null) ...[
                      const SizedBox(height: TeachingPlannerDesign.space16),
                      _SetupError(message: errorMessage!, onRetry: onRetry),
                    ],
                    const SizedBox(height: TeachingPlannerDesign.space22),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _MainSetupCard(
                              model: model,
                              isLoading: isLoading,
                              onCreateClass: onCreateClass,
                              onOpenSyllabus: onOpenSyllabus,
                              onPlanFirstLesson: onPlanFirstLesson,
                            ),
                          ),
                          const SizedBox(width: TeachingPlannerDesign.space18),
                          Expanded(flex: 4, child: _SetupSummary(model: model)),
                        ],
                      )
                    else ...[
                      _MainSetupCard(
                        model: model,
                        isLoading: isLoading,
                        onCreateClass: onCreateClass,
                        onOpenSyllabus: onOpenSyllabus,
                        onPlanFirstLesson: onPlanFirstLesson,
                      ),
                      const SizedBox(height: TeachingPlannerDesign.space16),
                      _SetupSummary(model: model),
                    ],
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

class _SetupHeader extends StatelessWidget {
  const _SetupHeader({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = TeachingPlannerTheme.colorsOf(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colors.primarySoft,
            borderRadius: BorderRadius.circular(
              TeachingPlannerDesign.radiusMedium,
            ),
          ),
          child: Icon(Icons.school_rounded, color: colors.primary, size: 26),
        ),
        const SizedBox(width: TeachingPlannerDesign.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to Teaching Planner',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.35,
                ),
              ),
              const SizedBox(height: TeachingPlannerDesign.space2),
              Text(
                'Set up your class, syllabus and first lesson in three simple steps.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: TeachingPlannerDesign.space8),
        TextButton(
          key: const ValueKey('planner-setup-skip'),
          onPressed: onSkip,
          child: const Text('Skip for now'),
        ),
      ],
    );
  }
}

class _SetupStepper extends StatelessWidget {
  const _SetupStepper({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Your class', 'Syllabus', 'First lesson'];

    return TeachingPlannerSurfaceCard(
      key: const ValueKey('planner-setup-stepper'),
      padding: const EdgeInsets.symmetric(
        horizontal: TeachingPlannerDesign.space12,
        vertical: TeachingPlannerDesign.space14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            Expanded(
              child: _SetupStep(
                index: index,
                label: labels[index],
                completed: index < currentStep,
                active: index == currentStep,
              ),
            ),
            if (index != labels.length - 1)
              _StepConnector(active: index < currentStep),
          ],
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.index,
    required this.label,
    required this.completed,
    required this.active,
  });

  final int index;
  final String label;
  final bool completed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Column(
      children: [
        _StepCircle(index: index, completed: completed, active: active),
        const SizedBox(height: TeachingPlannerDesign.space8),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: active || completed ? colors.ink : colors.inkMuted,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 17),
      child: SizedBox(
        width: 28,
        child: AnimatedContainer(
          duration: TeachingPlannerDesign.standardMotion,
          height: 2,
          color: active ? colors.primary : colors.border,
        ),
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.index,
    required this.completed,
    required this.active,
  });

  final int index;
  final bool completed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final selected = completed || active;

    return AnimatedContainer(
      duration: TeachingPlannerDesign.standardMotion,
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? colors.primary : colors.surfaceSoft,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? colors.primary : colors.border,
          width: active ? 2 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: .2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: completed
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 19)
          : Text(
              '${index + 1}',
              style: TextStyle(
                color: selected ? Colors.white : colors.inkMuted,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}

class _MainSetupCard extends StatelessWidget {
  const _MainSetupCard({
    required this.model,
    required this.isLoading,
    required this.onCreateClass,
    required this.onOpenSyllabus,
    required this.onPlanFirstLesson,
  });

  final TeachingPlannerSetupModel model;
  final bool isLoading;
  final VoidCallback onCreateClass;
  final VoidCallback onOpenSyllabus;
  final VoidCallback onPlanFirstLesson;

  @override
  Widget build(BuildContext context) {
    final details = switch (model.stage) {
      TeachingPlannerSetupStage.classSetup => _SetupStageData(
        icon: Icons.class_rounded,
        tone: TeachingPlannerTone.primary,
        eyebrow: 'STEP 1 OF 3',
        title: 'Create your first class',
        body:
            'Start with the class you teach. Academic year is optional, and you can edit it later.',
        bullets: const [
          'Enter the class name you already use',
          'Add the academic year only if you need it',
        ],
        action: 'Create class',
        key: const ValueKey('planner-setup-create-class'),
        callback: onCreateClass,
      ),
      TeachingPlannerSetupStage.syllabus => _SetupStageData(
        icon: Icons.account_tree_rounded,
        tone: TeachingPlannerTone.teal,
        eyebrow: 'STEP 2 OF 3',
        title: 'Add the syllabus you actually teach',
        body:
            'Open your class, add a subject, then add at least one chapter. Units and topics stay optional.',
        bullets: const [
          'Add the real subject for this class',
          'Create at least one chapter to plan lessons',
        ],
        action: 'Build syllabus',
        key: const ValueKey('planner-setup-build-syllabus'),
        callback: onOpenSyllabus,
      ),
      TeachingPlannerSetupStage.firstLesson => _SetupStageData(
        icon: Icons.menu_book_rounded,
        tone: TeachingPlannerTone.purple,
        eyebrow: 'STEP 3 OF 3',
        title: 'Plan your first lesson',
        body:
            'Turn the syllabus into a real lesson with date, periods and objective. Materials and activities can be added now or later.',
        bullets: const [
          'Choose the syllabus chapter you will teach',
          'Set the date, periods and teaching objective',
        ],
        action: 'Plan first lesson',
        key: const ValueKey('planner-setup-first-lesson'),
        callback: onPlanFirstLesson,
      ),
      TeachingPlannerSetupStage.complete => _SetupStageData(
        icon: Icons.check_circle_rounded,
        tone: TeachingPlannerTone.teal,
        eyebrow: 'ALL SET',
        title: 'Your Teaching Planner is ready',
        body: 'Your class, syllabus and first lesson are connected.',
        bullets: const [
          'Your teaching structure is ready to use',
          'Continue planning from the main dashboard',
        ],
        action: 'Continue',
        key: const ValueKey('planner-setup-complete'),
        callback: onPlanFirstLesson,
      ),
    };

    final theme = Theme.of(context);
    final colors = TeachingPlannerTheme.colorsOf(context);

    return Container(
      key: const ValueKey('planner-setup-main-card'),
      padding: const EdgeInsets.all(TeachingPlannerDesign.space22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [details.tone.background(colors), colors.surface],
        ),
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusHero),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TeachingPlannerIconBadge(
                icon: details.icon,
                tone: details.tone,
                size: 54,
                iconSize: 28,
              ),
              const SizedBox(width: TeachingPlannerDesign.space14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TeachingPlannerPill(
                      label: details.eyebrow,
                      tone: details.tone,
                    ),
                    const SizedBox(height: TeachingPlannerDesign.space10),
                    Text(
                      details.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TeachingPlannerDesign.space14),
          Text(
            details.body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.inkMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: TeachingPlannerDesign.space18),
          Container(
            padding: const EdgeInsets.all(TeachingPlannerDesign.space14),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: .86),
              borderRadius: BorderRadius.circular(
                TeachingPlannerDesign.radiusLarge,
              ),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: details.bullets
                  .map(
                    (bullet) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: TeachingPlannerDesign.space6,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                            color: details.tone.foreground(colors),
                          ),
                          const SizedBox(width: TeachingPlannerDesign.space10),
                          Expanded(
                            child: Text(
                              bullet,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.ink,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: TeachingPlannerDesign.space20),
          SizedBox(
            width: double.infinity,
            child: _guideActionAnchor(
              model.stage,
              FilledButton.icon(
                key: details.key,
                onPressed: isLoading ? null : details.callback,
                icon: isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(details.icon),
                label: Text(details.action),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideActionAnchor(TeachingPlannerSetupStage stage, Widget child) {
    return switch (stage) {
      TeachingPlannerSetupStage.classSetup => GuideAnchor(
        targetId: CreateSyllabusGuideTargets.openClassSetup,
        reportPointerActivation: true,
        child: child,
      ),
      TeachingPlannerSetupStage.syllabus => GuideAnchor(
        targetId: CreateSyllabusGuideTargets.openSyllabus,
        reportPointerActivation: true,
        child: child,
      ),
      _ => child,
    };
  }
}

class _SetupStageData {
  const _SetupStageData({
    required this.icon,
    required this.tone,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.bullets,
    required this.action,
    required this.key,
    required this.callback,
  });

  final IconData icon;
  final TeachingPlannerTone tone;
  final String eyebrow;
  final String title;
  final String body;
  final List<String> bullets;
  final String action;
  final Key key;
  final VoidCallback callback;
}

class _SetupSummary extends StatelessWidget {
  const _SetupSummary({required this.model});

  final TeachingPlannerSetupModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = TeachingPlannerTheme.colorsOf(context);

    return TeachingPlannerSurfaceCard(
      key: const ValueKey('planner-setup-summary'),
      tint: true,
      tone: TeachingPlannerTone.teal,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TeachingPlannerIconBadge(
                icon: Icons.fact_check_outlined,
                tone: TeachingPlannerTone.teal,
                size: 36,
                iconSize: 19,
              ),
              const SizedBox(width: TeachingPlannerDesign.space10),
              Expanded(
                child: Text(
                  'Your setup so far',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TeachingPlannerDesign.space16),
          _SummaryRow(
            icon: Icons.class_outlined,
            label: 'Classes',
            value: model.activeClassCount,
            tone: TeachingPlannerTone.primary,
          ),
          const SizedBox(height: TeachingPlannerDesign.space10),
          _SummaryRow(
            icon: Icons.subject_rounded,
            label: 'Subjects',
            value: model.activeSubjectCount,
            tone: TeachingPlannerTone.teal,
          ),
          const SizedBox(height: TeachingPlannerDesign.space10),
          _SummaryRow(
            icon: Icons.library_books_outlined,
            label: 'Chapters',
            value: model.activeChapterCount,
            tone: TeachingPlannerTone.purple,
          ),
          const SizedBox(height: TeachingPlannerDesign.space10),
          _SummaryRow(
            icon: Icons.menu_book_outlined,
            label: 'Lessons',
            value: model.activeLessonCount,
            tone: TeachingPlannerTone.orange,
          ),
          const SizedBox(height: TeachingPlannerDesign.space16),
          Divider(color: colors.border),
          const SizedBox(height: TeachingPlannerDesign.space10),
          Text(
            'You can add units, topics, teaching materials and detailed resources after this quick setup.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.inkMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final int value;
  final TeachingPlannerTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = TeachingPlannerTheme.colorsOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TeachingPlannerDesign.space12,
        vertical: TeachingPlannerDesign.space10,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusMedium),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          TeachingPlannerIconBadge(
            icon: icon,
            tone: tone,
            size: 34,
            iconSize: 18,
          ),
          const SizedBox(width: TeachingPlannerDesign.space10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupError extends StatelessWidget {
  const _SetupError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(TeachingPlannerDesign.space14),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(
            TeachingPlannerDesign.radiusLarge,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: TeachingPlannerDesign.space10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
