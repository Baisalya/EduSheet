import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../editor/domain/models/paper_model.dart';
import '../../domain/models/content_template.dart';
import '../../services/template_clone_service.dart';
import '../providers/content_template_provider.dart';

class QuestionTemplatePickerSheet extends ConsumerStatefulWidget {
  const QuestionTemplatePickerSheet({super.key});

  @override
  ConsumerState<QuestionTemplatePickerSheet> createState() =>
      _QuestionTemplatePickerSheetState();
}

class _QuestionTemplatePickerSheetState
    extends ConsumerState<QuestionTemplatePickerSheet> {
  String _query = '';
  String? _subject;
  QuestionType? _type;
  QuestionDifficulty? _difficulty;

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(questionTemplatesProvider);
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
        children: [
          const _SheetTitle(
            icon: Icons.content_copy_rounded,
            title: 'Question templates',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search name, class, chapter or topic',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          templates.when(
            data: (items) {
              final subjects = items
                  .map((item) => item.question.subject.trim())
                  .where((item) => item.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterDropdown<String>(
                        value: _subject,
                        hint: 'Subject',
                        values: subjects,
                        label: (value) => value,
                        onChanged: (value) => setState(() => _subject = value),
                      ),
                      const SizedBox(width: 8),
                      _FilterDropdown<QuestionType>(
                        value: _type,
                        hint: 'Type',
                        values: QuestionType.values,
                        label: (value) => value.label,
                        onChanged: (value) => setState(() => _type = value),
                      ),
                      const SizedBox(width: 8),
                      _FilterDropdown<QuestionDifficulty>(
                        value: _difficulty,
                        hint: 'Difficulty',
                        values: QuestionDifficulty.values,
                        label: (value) => value.name,
                        onChanged: (value) =>
                            setState(() => _difficulty = value),
                      ),
                      if (_subject != null || _type != null || _difficulty != null)
                        TextButton(
                          onPressed: () => setState(() {
                            _subject = null;
                            _type = null;
                            _difficulty = null;
                          }),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: templates.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _TemplateError(
                message: 'Could not load question templates.',
                onRetry: () => ref.invalidate(questionTemplatesProvider),
              ),
              data: (items) {
                final filtered = items.where(_matches).toList();
                if (filtered.isEmpty) {
                  return const _EmptyTemplates(
                    message: 'No matching question templates yet.',
                  );
                }
                return ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return Card(
                      child: ListTile(
                        minTileHeight: 64,
                        leading: const Icon(Icons.quiz_outlined),
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.question.type.label} • ${_marksLabel(item.question.marks)} marks'
                          '${item.question.subject.isEmpty ? '' : ' • ${item.question.subject}'}',
                        ),
                        onTap: () => Navigator.pop(context, item),
                        trailing: item.isBuiltIn
                            ? null
                            : PopupMenuButton<String>(
                                onSelected: (action) =>
                                    _handleAction(action, item),
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Rename / edit details'),
                                  ),
                                  PopupMenuItem(
                                    value: 'duplicate',
                                    child: Text('Duplicate'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matches(QuestionTemplate template) {
    final question = template.question;
    final query = _query.trim().toLowerCase();
    final searchable = [
      template.name,
      template.description,
      question.plainTextAccessibility,
      question.grade,
      question.subject,
      question.chapter,
      question.topic,
      ...question.tags,
    ].join(' ').toLowerCase();
    return (query.isEmpty || searchable.contains(query)) &&
        (_subject == null || question.subject == _subject) &&
        (_type == null || question.type == _type) &&
        (_difficulty == null || question.difficulty == _difficulty);
  }

  Future<void> _handleAction(
    String action,
    QuestionTemplate template,
  ) async {
    final repository = ref.read(contentTemplateRepositoryProvider);
    if (action == 'duplicate') {
      final clone = TemplateCloneService().cloneQuestion(template.question);
      await repository.saveQuestionTemplate(
        template.copyWith(
          id: const Uuid().v4(),
          name: '${template.name} copy',
          question: clone,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        ),
      );
    } else if (action == 'edit') {
      final name = await _askForName(template.name);
      if (name == null) return;
      await repository.saveQuestionTemplate(template.copyWith(name: name));
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete template?'),
          content: Text('Delete “${template.name}”? Existing papers are safe.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await repository.deleteQuestionTemplate(template.id);
      }
    }
    ref.invalidate(questionTemplatesProvider);
  }

  Future<String?> _askForName(String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Template name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.isEmpty == true ? null : result;
  }
}

class SectionTemplatePickerSheet extends ConsumerWidget {
  const SectionTemplatePickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SimpleTemplateSheet<SectionTemplate>(
      title: 'Section templates',
      icon: Icons.view_agenda_outlined,
      value: ref.watch(sectionTemplatesProvider),
      name: (item) => item.name,
      description: (item) => item.description,
    );
  }
}

class PaperBlueprintPickerSheet extends ConsumerWidget {
  const PaperBlueprintPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SimpleTemplateSheet<PaperBlueprint>(
      title: 'Start from a paper template',
      icon: Icons.dashboard_customize_outlined,
      value: ref.watch(paperBlueprintsProvider),
      name: (item) => item.name,
      description: (item) => item.description,
    );
  }
}

class _SimpleTemplateSheet<T> extends StatelessWidget {
  final String title;
  final IconData icon;
  final AsyncValue<List<T>> value;
  final String Function(T item) name;
  final String Function(T item) description;

  const _SimpleTemplateSheet({
    required this.title,
    required this.icon,
    required this.value,
    required this.name,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Column(
        children: [
          _SheetTitle(icon: icon, title: title),
          Expanded(
            child: value.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const _TemplateError(
                message: 'Could not load templates.',
              ),
              data: (items) => ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    child: ListTile(
                      minTileHeight: 64,
                      leading: Icon(icon),
                      title: Text(name(item)),
                      subtitle: Text(description(item)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(context, item),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<T> values;
  final String Function(T value) label;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.values,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<T>(
      value: value,
      hint: Text(hint),
      items: values
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(label(item)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SheetTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      trailing: IconButton(
        tooltip: 'Close',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close_rounded),
      ),
    );
  }
}

class _TemplateError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _TemplateError({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 36),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyTemplates extends StatelessWidget {
  final String message;

  const _EmptyTemplates({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

String _marksLabel(double value) {
  return value == value.truncateToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}
