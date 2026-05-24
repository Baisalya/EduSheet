import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/models/document_model.dart';
import '../providers/document_provider.dart';
import 'file_preview_screen.dart';

class DocumentReaderScreen extends ConsumerStatefulWidget {
  const DocumentReaderScreen({super.key});

  @override
  ConsumerState<DocumentReaderScreen> createState() =>
      _DocumentReaderScreenState();
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
          'Reader',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(documentProvider.notifier).refreshDocuments(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildReaderHero(state, isDark),
          _buildSearchBar(isDark),
          _buildFilterChips(),
          Expanded(child: _buildDocumentList(state, isDark)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickDocument,
        icon: const Icon(Icons.upload_file),
        label: const Text('Open file'),
      ),
    );
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'rtf',
        'odt',
        'xls',
        'xlsx',
        'csv',
        'ods',
        'ppt',
        'pptx',
        'odp',
        'txt',
      ],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    final repo = ref.read(documentRepositoryProvider);
    final document = await repo.getDocumentFromFilePath(path);
    if (!mounted) return;

    if (document == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This file type is not supported yet.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilePreviewScreen(document: document),
      ),
    );
  }

  Widget _buildReaderHero(DocumentState state, bool isDark) {
    final counts = <DocumentType, int>{};
    for (final doc in state.allDocuments) {
      counts.update(doc.type, (value) => value + 1, ifAbsent: () => 1);
    }
    final totalSize = state.allDocuments.fold<int>(
      0,
      (sum, doc) => sum + doc.size,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1F26) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.folder_copy, color: Colors.blue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${state.allDocuments.length} documents ready',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_countText(counts[DocumentType.pdf] ?? 0, 'PDF')} | '
                    '${_countText(counts[DocumentType.word] ?? 0, 'Word')} | '
                    '${_countText(counts[DocumentType.excel] ?? 0, 'Excel')} | '
                    '${_countText(counts[DocumentType.powerpoint] ?? 0, 'PPT')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _ReaderBadge(label: _formatSize(totalSize), isDark: isDark),
          ],
        ),
      ),
    );
  }

  String _countText(int count, String label) => '$count $label';

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade200,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) =>
              ref.read(documentProvider.notifier).setSearchQuery(val),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final state = ref.watch(documentProvider);
    return SizedBox(
      height: 46,
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
            onTap: () =>
                ref.read(documentProvider.notifier).setFilter(DocumentType.pdf),
          ),
          _FilterChip(
            label: 'Word',
            isSelected: state.selectedFilter == DocumentType.word,
            onTap: () => ref
                .read(documentProvider.notifier)
                .setFilter(DocumentType.word),
          ),
          _FilterChip(
            label: 'Excel',
            isSelected: state.selectedFilter == DocumentType.excel,
            onTap: () => ref
                .read(documentProvider.notifier)
                .setFilter(DocumentType.excel),
          ),
          _FilterChip(
            label: 'PowerPoint',
            isSelected: state.selectedFilter == DocumentType.powerpoint,
            onTap: () => ref
                .read(documentProvider.notifier)
                .setFilter(DocumentType.powerpoint),
          ),
          _FilterChip(
            label: 'Text',
            isSelected: state.selectedFilter == DocumentType.text,
            onTap: () => ref
                .read(documentProvider.notifier)
                .setFilter(DocumentType.text),
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
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No documents found',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap Open file to preview PDF, Word, Excel, PowerPoint, or text.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: state.filteredDocuments.length,
      itemBuilder: (context, index) {
        final doc = state.filteredDocuments[index];
        return _DocumentCard(doc: doc);
      },
    );
  }
}

class _ReaderBadge extends StatelessWidget {
  final String label;
  final bool isDark;

  const _ReaderBadge({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.blue.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.blue.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
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
        selectedColor: Colors.blue.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: isSelected
              ? Colors.blue
              : (isDark ? Colors.white70 : Colors.black87),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected
                ? Colors.blue
                : (isDark ? Colors.white10 : Colors.grey.shade300),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.035),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getIconForType(doc.type), color: color, size: 24),
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
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _InfoPill(
                          text: doc.extension
                              .replaceFirst('.', '')
                              .toUpperCase(),
                          color: color,
                          isDark: isDark,
                        ),
                        Text(
                          '${doc.sizeString} | ${DateFormat('MMM d, yyyy').format(doc.lastModified)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey[600],
                          ),
                        ),
                      ],
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
        return Colors.deepOrange;
      case DocumentType.text:
        return Colors.blueGrey;
      case DocumentType.other:
        return Colors.blueGrey;
    }
  }
}

class _InfoPill extends StatelessWidget {
  final String text;
  final Color color;
  final bool isDark;

  const _InfoPill({
    required this.text,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
