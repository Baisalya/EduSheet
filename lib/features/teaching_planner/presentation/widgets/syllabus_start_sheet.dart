import 'package:flutter/material.dart';

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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create syllabus',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Start simple. Give this class syllabus a name and optionally an academic year. You can add the structure next.',
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Class / syllabus name',
                  hintText: 'Example: Class 10',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a class or syllabus name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _yearController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Academic year (optional)',
                  hintText: 'Example: 2026–27',
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Create and continue'),
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
