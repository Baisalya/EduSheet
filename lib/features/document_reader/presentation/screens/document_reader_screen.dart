import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../providers/document_provider.dart';
import '../../domain/models/document_model.dart';
import 'file_preview_screen.dart';

class DocumentReaderScreen extends ConsumerStatefulWidget {
  const DocumentReaderScreen({super.key});

  @override
  ConsumerState<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends ConsumerState<DocumentReaderScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: const Text(
          'Document Reader',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(documentProvider.notifier).refreshDocuments(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(isDark),
          _buildFilterChips(),
          Expanded(
            child: _buildDocumentList(state, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => ref.read(documentProvider.notifier).setSearchQuery(val),
          decoration: InputDecoration(
            hintText: 'Search documents...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(documentProvider.notifier).setSearchQuery('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final state = ref.watch(documentProvider);
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(
            label: 'All',
            isSelected: state.selectedFilter == null,
            onTap: () => ref.read(documentProvider.notifier).setFilter(null),
          ),
          _FilterChip(
            label: 'PDF',
            isSelected: state.selectedFilter == DocumentType.pdf,
            onTap: () => ref.read(documentProvider.notifier).setFilter(DocumentType.pdf),
          ),
          _FilterChip(
            label: 'Word',
            isSelected: state.selectedFilter == DocumentType.word,
            onTap: () => ref.read(documentProvider.notifier).setFilter(DocumentType.word),
          ),
          _FilterChip(
            label: 'Excel',
            isSelected: state.selectedFilter == DocumentType.excel,
            onTap: () => ref.read(documentProvider.notifier).setFilter(DocumentType.excel),
          ),
          _FilterChip(
            label: 'PowerPoint',
            isSelected: state.selectedFilter == DocumentType.powerpoint,
            onTap: () => ref.read(documentProvider.notifier).setFilter(DocumentType.powerpoint),
          ),
          _FilterChip(
            label: 'Text',
            isSelected: state.selectedFilter == DocumentType.text,
            onTap: () => ref.read(documentProvider.notifier).setFilter(DocumentType.text),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList(DocumentState state, bool isDark) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.filteredDocuments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No documents found.',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.filteredDocuments.length,
      itemBuilder: (context, index) {
        final doc = state.filteredDocuments[index];
        return _DocumentCard(doc: doc);
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: Colors.blue.withOpacity(0.2),
        labelStyle: TextStyle(
          color: isSelected ? Colors.blue : (isDark ? Colors.white70 : Colors.black87),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? Colors.blue : (isDark ? Colors.white10 : Colors.grey.shade300),
          ),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final DocumentFile doc;
  const _DocumentCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _getColorForType(doc.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FilePreviewScreen(document: doc),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIconForType(doc.type),
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${doc.sizeString} • ${DateFormat('MMM d, yyyy').format(doc.lastModified)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white24 : Colors.black12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf;
      case DocumentType.word:
        return Icons.description;
      case DocumentType.excel:
        return Icons.table_chart;
      case DocumentType.powerpoint:
        return Icons.slideshow;
      case DocumentType.text:
        return Icons.text_snippet;
      case DocumentType.other:
        return Icons.insert_drive_file;
    }
  }

  Color _getColorForType(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Colors.redAccent;
      case DocumentType.word:
        return Colors.blue;
      case DocumentType.excel:
        return Colors.green;
      case DocumentType.powerpoint:
        return Colors.orange;
      case DocumentType.text:
        return Colors.grey;
      case DocumentType.other:
        return Colors.blueGrey;
    }
  }
}
