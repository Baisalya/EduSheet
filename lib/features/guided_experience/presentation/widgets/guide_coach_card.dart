import 'package:flutter/material.dart';

import '../../domain/guide_definition.dart';

class GuideCoachCard extends StatelessWidget {
  const GuideCoachCard({
    super.key,
    required this.step,
    required this.stepNumber,
    required this.totalSteps,
    required this.isFirstStep,
    required this.isLastStep,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
    required this.onStop,
    this.targetAvailable = true,
  });

  final GuideStep step;
  final int stepNumber;
  final int totalSteps;
  final bool isFirstStep;
  final bool isLastStep;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onStop;
  final bool targetAvailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requiresRealAction = step.advanceMode != GuideAdvanceMode.manual;

    return Semantics(
      container: true,
      label: 'Guide step $stepNumber of $totalSteps',
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step $stepNumber of $totalSteps',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Stop guide',
                    child: IconButton(
                      onPressed: onStop,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(step.message, style: theme.textTheme.bodyMedium),
              if (requiresRealAction) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        !targetAvailable
                            ? 'Waiting for this control to become available.'
                            : step.advanceMode == GuideAdvanceMode.targetActivated
                            ? 'Use the highlighted control to continue.'
                            : 'Complete the required action to continue.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (step.allowSkip)
                    TextButton(onPressed: onSkip, child: const Text('Skip')),
                  if (step.allowBack && !isFirstStep)
                    OutlinedButton(
                      onPressed: onBack,
                      child: const Text('Back'),
                    ),
                  if (!requiresRealAction)
                    FilledButton(
                      onPressed: onNext,
                      child: Text(isLastStep ? 'Done' : 'Next'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
