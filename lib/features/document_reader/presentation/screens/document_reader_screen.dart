import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edusheet/features/document_reader/domain/models/document_model.dart';
import 'package:edusheet/features/document_reader/domain/models/document_open_request.dart';
import 'package:edusheet/features/document_reader/presentation/providers/document_provider.dart';
import 'package:edusheet/features/document_reader/presentation/screens/file_preview_screen.dart';
import 'package:edusheet/features/guided_experience/domain/contextual_help.dart';
import 'package:edusheet/features/guided_experience/presentation/screens/user_manual_screen.dart';
import 'package:edusheet/features/guided_experience/presentation/widgets/contextual_help_prompt.dart';

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final scaffold = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        title: const Text(
          'Reader',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Reader help',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const EduSheetUserManualScreen(
                  focus: EduSheetManualSection.reader,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh documents',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(documentProvider.notifier).refreshDocuments(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildReaderHero(state, isDark),
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(child: _buildDocumentList(state)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickDocument,
        icon: const Icon(Icons.upload_file),
        label: const Text('Open file'),
      ),
    );

    if (state.allDocuments.isNotEmpty) return scaffold;

    return ContextualHelpOffer(
      suggestion: const ContextualHelpSuggestion(
        id: 'reader.open_first_file',
        screen: GuidedScreenContext.documentReader,
        title: 'Open your first document?',
        message:
            'Tap Open file and choose a PDF, Word, Excel, PowerPoint or text file. I can open the picker for you.',
        primaryLabel: 'Open file',
        minimumInactivity: Duration(minutes: 1),
        requiresIncompleteAction: true,
        suppressWhenRelatedGuideCompleted: false,
      ),
      signals: const ContextualHelpSignals(
        currentScreen: GuidedScreenContext.documentReader,
        hasIncompleteAction: true,
      ),
      onShowMe: _pickDocument,
      child: scaffold,
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

    await _openRequest(DocumentOpenRequest.fromFilePicker(path));
  }

  Future<void> _openRequest(DocumentOpenRequest request) async {
    final result = await ref
        .read(documentOpenCoordinatorProvider)
        .resolve(request);
    if (!mounted || result.duplicate) return;

    final session = result.session;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Unable to open this document.'),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilePreviewScreen(document: session.document),
      ),
    );
  }

  Widget _buildReaderHero(DocumentState state, bool isDark) {
    final scheme = Theme.of(context).colorScheme;
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
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.outlineVariant,
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
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.folder_copy, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${state.allDocuments.length} documents ready',
                    style: TextStyle(
                      color: scheme.onSurface,
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
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _ReaderBadge(label: _formatSize(totalSize)),
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

  Widget _buildSearchBar() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant,
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

  Widget _buildDocumentList(DocumentState state) {
    final scheme = Theme.of(context).colorScheme;
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
              Icon(
                Icons.search_off,
                size: 64,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.38),
              ),
              const SizedBox(height: 16),
              Text(
                'No documents found',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap Open file to preview PDF, Word, Excel, PowerPoint, or text.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
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
        return _DocumentCard(
          doc: doc,
          onTap: () => _openRequest(DocumentOpenRequest.fromReader(doc.path)),
        );
      },
    );
  }
}

class _ReaderBadge extends StatelessWidget {
  final String label;

  const _ReaderBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(
          color: isSelected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final DocumentFile doc;
  final VoidCallback onTap;

  const _DocumentCard({required this.doc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final color = _getColorForType(doc.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
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
        onTap: onTap,
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
                        color: scheme.onSurface,
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
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.primary),
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
