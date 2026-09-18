import 'package:flutter/material.dart';

import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';

import '../../../guided_experience/guides/create_syllabus_guide.dart';
import '../../../guided_experience/presentation/widgets/guide_anchor.dart';

import '../design/teaching_planner_design_system.dart';
import 'teaching_planner_shared_components.dart';

class PlannerClassDraft {
  const PlannerClassDraft({required this.name, this.academicYear});

  final String name;
  final String? academicYear;
}

Future<PlannerClassDraft?> showCreatePlannerClassSheet(BuildContext context) {
  return showAdaptiveModalBottomSheet<PlannerClassDraft>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const TeachingPlannerThemeScope(
      child: CreatePlannerClassSheet(),
    ),
  );
}

class CreatePlannerClassSheet extends StatefulWidget {
  const CreatePlannerClassSheet({super.key});

  @override
  State<CreatePlannerClassSheet> createState() =>
      _CreatePlannerClassSheetState();
}

class _CreatePlannerClassSheetState extends State<CreatePlannerClassSheet> {
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
    final theme = Theme.of(context);
    final colors = TeachingPlannerTheme.colorsOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        TeachingPlannerDesign.space20,
        TeachingPlannerDesign.space6,
        TeachingPlannerDesign.space20,
        TeachingPlannerDesign.space20 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: GuideAnchor(
            targetId: CreateSyllabusGuideTargets.classForm,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TeachingPlannerIconBadge(
                      icon: Icons.class_rounded,
                      tone: TeachingPlannerTone.primary,
                      size: 48,
                      iconSize: 25,
                    ),
                    const SizedBox(width: TeachingPlannerDesign.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create class',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colors.ink,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.3,
                            ),
                          ),
                          const SizedBox(height: TeachingPlannerDesign.space4),
                          Text(
                            'Add only the class details Teaching Planner already uses.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TeachingPlannerDesign.space20),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Class name',
                    hintText: 'Class 10',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a class name.'
                      : null,
                ),
                const SizedBox(height: TeachingPlannerDesign.space12),
                TextFormField(
                  controller: _yearController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Academic year (optional)',
                    hintText: '2026–27',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: TeachingPlannerDesign.space12),
                Container(
                  padding: const EdgeInsets.all(TeachingPlannerDesign.space12),
                  decoration: BoxDecoration(
                    color: colors.tealSoft,
                    borderRadius: BorderRadius.circular(
                      TeachingPlannerDesign.radiusMedium,
                    ),
                    border: Border.all(
                      color: colors.teal.withValues(alpha: .16),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: colors.teal,
                      ),
                      const SizedBox(width: TeachingPlannerDesign.space10),
                      Expanded(
                        child: Text(
                          'You can edit these class details later from your syllabus workspace.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.inkMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: TeachingPlannerDesign.space18),
                FilledButton.icon(
                  key: const ValueKey('planner-create-class-submit'),
                  onPressed: _submit,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create class'),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      PlannerClassDraft(
        name: _nameController.text.trim(),
        academicYear: _yearController.text.trim().isEmpty
            ? null
            : _yearController.text.trim(),
      ),
    );
  }
}
