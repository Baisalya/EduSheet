import 'package:flutter/material.dart';

import '../../../guided_experience/guides/create_syllabus_guide.dart';
import '../../../guided_experience/presentation/widgets/guide_anchor.dart';

import '../design/teaching_planner_design_system.dart';
import 'teaching_planner_responsive_content.dart';
import 'teaching_planner_shared_components.dart';

class SyllabusStartSheet extends StatefulWidget {
  const SyllabusStartSheet({super.key});

  @override
  State<SyllabusStartSheet> createState() => _SyllabusStartSheetState();
}

class _SyllabusStartSheetState extends State<SyllabusStartSheet> {
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
    return TeachingPlannerSheetFrame(
      title: 'Create syllabus',
      subtitle:
          'Start simple with the class name. The real subject, unit, chapter and topic structure can be added next.',
      icon: Icons.account_tree_outlined,
      maxWidth: 620,
      action: FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Create and continue'),
      ),
      child: GuideAnchor(
        targetId: CreateSyllabusGuideTargets.syllabusForm,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            const TeachingPlannerSectionHeader(
              title: 'Class details',
              subtitle:
                  'Only the fields already supported by Teaching Planner are shown here.',
              icon: Icons.school_outlined,
            ),
            const SizedBox(height: TeachingPlannerDesign.space12),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Class / syllabus name',
                hintText: 'Example: Class 10',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a class or syllabus name.'
                  : null,
            ),
            const SizedBox(height: TeachingPlannerDesign.space10),
            TextFormField(
              controller: _yearController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Academic year (optional)',
                hintText: 'Example: 2026–27',
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final year = _yearController.text.trim();
    Navigator.of(context).pop(
      SyllabusStartDraft(
        name: _nameController.text.trim(),
        academicYear: year.isEmpty ? null : year,
      ),
    );
  }
}

class SyllabusStartDraft {
  final String name;
  final String? academicYear;

  const SyllabusStartDraft({required this.name, this.academicYear});
}
