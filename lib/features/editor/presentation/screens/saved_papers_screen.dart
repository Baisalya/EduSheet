import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/editor_provider.dart';
import 'create_paper_screen.dart';
import '../../../pdf/services/pdf_service.dart';

class SavedPapersScreen extends ConsumerWidget {
  const SavedPapersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final papersAsync = ref.watch(savedPapersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Papers'),
      ),
      body: papersAsync.when(
        data: (papers) => papers.isEmpty
            ? const Center(child: Text('No saved papers yet.'))
            : ListView.builder(
                itemCount: papers.length,
                itemBuilder: (context, index) {
                  final paper = papers[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(paper.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${paper.schoolName} | ${paper.totalMarks} Marks'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                            onPressed: () => PdfService.generateAndPreview(paper),
                            tooltip: 'View PDF',
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              ref.read(editorStateProvider.notifier).loadPaper(paper);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CreatePaperScreen()),
                              );
                            },
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.grey),
                            onPressed: () => _confirmDelete(context, ref, paper),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Paper paper) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Paper?'),
        content: Text('Are you sure you want to delete "${paper.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(paperRepositoryProvider).deletePaper(paper.id);
              ref.invalidate(savedPapersProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
