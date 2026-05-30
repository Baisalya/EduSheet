import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/editor_provider.dart';
import 'create_paper_screen.dart';
import '../../../pdf/services/presentation_export_service.dart';
import '../../../pdf/services/pdf_service.dart';
import '../../../pdf/services/spreadsheet_export_service.dart';
import '../../../pdf/services/word_export_service.dart';
import 'package:intl/intl.dart';

enum PaperSort { dateNewest, dateOldest, titleAZ, marksHigh, marksLow }

class SavedPapersScreen extends ConsumerStatefulWidget {
  const SavedPapersScreen({super.key});

  @override
  ConsumerState<SavedPapersScreen> createState() => _SavedPapersScreenState();
}

class _SavedPapersScreenState extends ConsumerState<SavedPapersScreen> {
  String _searchQuery = '';
  PaperSort _sortBy = PaperSort.dateNewest;

  @override
  Widget build(BuildContext context) {
    final papersAsync = ref.watch(savedPapersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: const Text(
          'Saved Papers',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<PaperSort>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (sort) => setState(() => _sortBy = sort),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: PaperSort.dateNewest,
                child: Text('Date (Newest First)'),
              ),
              const PopupMenuItem(
                value: PaperSort.dateOldest,
                child: Text('Date (Oldest First)'),
              ),
              const PopupMenuItem(
                value: PaperSort.titleAZ,
                child: Text('Title (A-Z)'),
              ),
              const PopupMenuItem(
                value: PaperSort.marksHigh,
                child: Text('Marks (High to Low)'),
              ),
              const PopupMenuItem(
                value: PaperSort.marksLow,
                child: Text('Marks (Low to High)'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by title or school...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: isDark ? Colors.white.withAlpha(13) : Colors.grey.withAlpha(13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: papersAsync.when(
              data: (papers) {
                var filtered = papers.where((p) {
                  final query = _searchQuery.toLowerCase();
                  return p.title.toLowerCase().contains(query) ||
                      p.schoolName.toLowerCase().contains(query);
                }).toList();

                // Sorting logic
                switch (_sortBy) {
                  case PaperSort.dateNewest:
                    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    break;
                  case PaperSort.dateOldest:
                    filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                    break;
                  case PaperSort.titleAZ:
                    filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
                    break;
                  case PaperSort.marksHigh:
                    filtered.sort((a, b) => b.totalMarks.compareTo(a.totalMarks));
                    break;
                  case PaperSort.marksLow:
                    filtered.sort((a, b) => a.totalMarks.compareTo(b.totalMarks));
                    break;
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty ? Icons.description_outlined : Icons.search_off,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No saved papers yet.' : 'No papers match your search.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final paper = filtered[index];
                    return _SavedPaperCard(paper: paper);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedPaperCard extends ConsumerWidget {
  final Paper paper;
  const _SavedPaperCard({required this.paper});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(paper.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          ref.read(editorStateProvider.notifier).loadPaper(paper);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePaperScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      paper.title.isEmpty ? 'Untitled Paper' : paper.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${paper.totalMarks.toStringAsFixed(0)} Marks',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                paper.schoolName,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _ActionButton(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          color: Colors.blue,
                          onPressed: () {
                            ref
                                .read(editorStateProvider.notifier)
                                .loadPaper(paper);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreatePaperScreen(),
                              ),
                            );
                          },
                        ),
                        _ActionButton(
                          icon: Icons.picture_as_pdf_outlined,
                          label: 'PDF',
                          color: Colors.redAccent,
                          onPressed: () {
                            final templates = ref.read(templateProvider).all;
                            final template = templates.firstWhere(
                              (t) => t.id == paper.templateId,
                              orElse: () => templates.first,
                            );
                            PdfService.generateAndPreview(paper, template);
                          },
                        ),
                        _ActionButton(
                          icon: Icons.description_outlined,
                          label: 'Word',
                          color: Colors.indigo,
                          onPressed: () => _saveAsWord(context, ref, paper),
                        ),
                        _ActionButton(
                          icon: Icons.table_chart_outlined,
                          label: 'Excel',
                          color: Colors.green,
                          onPressed: () => _saveAsExcel(context, ref, paper),
                        ),
                        _ActionButton(
                          icon: Icons.slideshow_outlined,
                          label: 'PPT',
                          color: Colors.deepOrange,
                          onPressed: () =>
                              _saveAsPowerPoint(context, ref, paper),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    onPressed: () => _confirmDelete(context, ref, paper),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Paper paper) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Paper?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Are you sure you want to delete "${paper.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
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

  Future<void> _saveAsWord(
    BuildContext context,
    WidgetRef ref,
    Paper paper,
  ) async {
    try {
      final templates = ref.read(templateProvider).all;
      final template = templates.firstWhere(
        (t) => t.id == paper.templateId,
        orElse: () => templates.first,
      );
      final file = await WordExportService.exportAndOpen(paper, template);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Word file saved: ${file.path}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save Word file: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveAsExcel(
    BuildContext context,
    WidgetRef ref,
    Paper paper,
  ) async {
    try {
      final templates = ref.read(templateProvider).all;
      final template = templates.firstWhere(
        (t) => t.id == paper.templateId,
        orElse: () => templates.first,
      );
      final file = await SpreadsheetExportService.exportAndOpen(
        paper,
        template,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel file saved: ${file.path}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save Excel file: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveAsPowerPoint(
    BuildContext context,
    WidgetRef ref,
    Paper paper,
  ) async {
    try {
      final templates = ref.read(templateProvider).all;
      final template = templates.firstWhere(
        (t) => t.id == paper.templateId,
        orElse: () => templates.first,
      );
      final file = await PresentationExportService.exportAndOpen(
        paper,
        template,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PowerPoint file saved: ${file.path}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save PowerPoint file: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.08),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
