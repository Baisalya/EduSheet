import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/question_bank_model.dart';
import '../providers/question_bank_provider.dart';
import 'add_edit_question_screen.dart';
import '../widgets/random_generator_dialog.dart';

class QuestionBankScreen extends ConsumerWidget {
  const QuestionBankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(questionBankProvider);
    final notifier = ref.read(questionBankProvider.notifier);
    final questions = state.filteredQuestions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Bank'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            onPressed: () => _showRandomGenerator(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _exportData(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: () => _importData(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search questions or tags...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: notifier.setSearchQuery,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Favorites'),
                  selected: state.showOnlyFavorites,
                  onSelected: (_) => notifier.toggleShowOnlyFavorites(),
                ),
                const SizedBox(width: 8),
                _FilterDropdown<String>(
                  value: state.selectedSubject,
                  hint: 'Subject',
                  items: state.subjects,
                  onChanged: notifier.setSubject,
                ),
                const SizedBox(width: 8),
                _FilterDropdown<String>(
                  value: state.selectedChapter,
                  hint: 'Chapter',
                  items: state.chapters,
                  onChanged: notifier.setChapter,
                ),
                const SizedBox(width: 8),
                _FilterDropdown<Difficulty>(
                  value: state.selectedDifficulty,
                  hint: 'Difficulty',
                  items: Difficulty.values,
                  onChanged: notifier.setDifficulty,
                  labelBuilder: (d) => d.name.toUpperCase(),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : questions.isEmpty
                    ? const Center(child: Text('No questions found.'))
                    : ListView.builder(
                        itemCount: questions.length,
                        itemBuilder: (context, index) {
                          final q = questions[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              title: Text(
                                q.question.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text('${q.subject} > ${q.chapter} | ${q.difficulty.name.toUpperCase()}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      q.isFavorite ? Icons.favorite : Icons.favorite_border,
                                      color: q.isFavorite ? Colors.red : null,
                                    ),
                                    onPressed: () => notifier.toggleFavorite(q.question.id),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddEditQuestionScreen(question: q),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.grey),
                                    onPressed: () => _confirmDelete(context, notifier, q),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddEditQuestionScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(BuildContext context, QuestionBankNotifier notifier, QuestionBankQuestion q) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              notifier.deleteQuestion(q.question.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRandomGenerator(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const RandomGeneratorDialog(),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(questionBankRepositoryProvider);
    final json = await repo.exportToJson();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${json.length} characters of data.')),
    );
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    // In a real app, we'd use file_picker.
    // For now, let's assume we have a way to get the string.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import functionality requires file picker integration.')),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T)? labelBuilder;

  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint),
        underline: const SizedBox(),
        items: [
          DropdownMenuItem<T>(value: null, child: Text('All $hint')),
          ...items.map((e) => DropdownMenuItem<T>(
                value: e,
                child: Text(labelBuilder?.call(e) ?? e.toString()),
              )),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
