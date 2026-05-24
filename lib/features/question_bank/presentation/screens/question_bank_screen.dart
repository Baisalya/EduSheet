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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: const Text(
          'Question Bank',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle_rounded),
            onPressed: () => _showRandomGenerator(context, ref),
            tooltip: 'Generate Random Paper',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'export') _exportData(context, ref);
              if (val == 'import') _importData(context, ref);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'export', child: Text('Export Data')),
              const PopupMenuItem(value: 'import', child: Text('Import Data')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search questions or tags...',
                  prefixIcon: Icon(Icons.search, color: Colors.blue),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: notifier.setSearchQuery,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Favorites'),
                  selected: state.showOnlyFavorites,
                  onSelected: (_) => notifier.toggleShowOnlyFavorites(),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  selectedColor: Colors.red.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: state.showOnlyFavorites
                        ? Colors.red
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: state.showOnlyFavorites
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: state.showOnlyFavorites
                        ? Colors.red.withValues(alpha: 0.2)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey[300]!),
                  ),
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
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No questions found.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final q = questions[index];
                      return _QuestionBankCard(q: q, notifier: notifier);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AddEditQuestionScreen(),
          ),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add),
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
      SnackBar(
        content: Text('Exported ${json.length} characters of data.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Import functionality requires file picker integration.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _QuestionBankCard extends StatelessWidget {
  final QuestionBankQuestion q;
  final QuestionBankNotifier notifier;

  const _QuestionBankCard({required this.q, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color diffColor;
    switch (q.difficulty) {
      case Difficulty.easy:
        diffColor = Colors.green;
        break;
      case Difficulty.medium:
        diffColor = Colors.orange;
        break;
      case Difficulty.hard:
        diffColor = Colors.red;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddEditQuestionScreen(question: q),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      q.question.text,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      q.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_outline_rounded,
                      color: q.isFavorite ? Colors.red : Colors.grey[400],
                      size: 20,
                    ),
                    onPressed: () => notifier.toggleFavorite(q.question.id),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(left: 8),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(
                    label: q.subject,
                    icon: Icons.subject_rounded,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    label: q.difficulty.name.toUpperCase(),
                    icon: Icons.trending_up_rounded,
                    color: diffColor,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddEditQuestionScreen(question: q),
                      ),
                    ),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.grey,
                    ),
                    onPressed: () => _confirmDelete(context),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Question?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This action cannot be undone and will remove it from the bank.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
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
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey[300]!,
        ),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint, style: const TextStyle(fontSize: 12)),
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
        items: [
          DropdownMenuItem<T>(
            value: null,
            child: Text('All $hint', style: const TextStyle(fontSize: 12)),
          ),
          ...items.map(
            (e) => DropdownMenuItem<T>(
              value: e,
              child: Text(
                labelBuilder?.call(e) ?? e.toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
