import 'dart:io';

import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:edusheet/features/document_reader/data/services/word_fidelity_document_cache.dart';
import 'package:edusheet/features/document_reader/domain/models/document_model.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import '../../responsive/document_viewport_policy.dart';
import 'word_fidelity_document_view.dart';

enum _WordViewMode { fitWidth, printLayout }

typedef WordFidelityDocumentLoader = Future<ConversionDocument> Function(File file);

class WordDocumentViewer extends StatefulWidget {
  final DocumentFile document;

  /// Optional seam for deterministic widget tests. Production callers leave
  /// this null and continue to use [DocxConversionParser.parse].
  final WordFidelityDocumentLoader? fidelityLoader;

  const WordDocumentViewer({
    super.key,
    required this.document,
    this.fidelityLoader,
  });

  @override
  State<WordDocumentViewer> createState() => _WordDocumentViewerState();
}

class _WordDocumentViewerState extends State<WordDocumentViewer> {
  final DocxSearchController _docxSearchController = DocxSearchController();
  final TextEditingController _searchTextController = TextEditingController();
  final FocusNode _viewerFocusNode = FocusNode(debugLabel: 'word-viewer');
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'word-search');

  _WordViewMode? _userViewMode;
  bool _showSearch = false;
  bool _checkingFidelity = false;
  ConversionDocument? _fidelityDocument;
  String _fidelitySearchQuery = '';
  int _fidelityMatchCount = 0;

  static final WordFidelityDocumentCache _sharedFidelityCache =
      WordFidelityDocumentCache(maxEntries: 2);

  @override
  void initState() {
    super.initState();
    _docxSearchController.addListener(_handleSearchUpdate);
    _prepareFidelityDocument();
  }

  @override
  void didUpdateWidget(covariant WordDocumentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.path != widget.document.path) {
      _fidelityDocument = null;
      _fidelitySearchQuery = '';
      _fidelityMatchCount = 0;
      _prepareFidelityDocument();
    }
  }

  Future<void> _prepareFidelityDocument() async {
    final file = File(widget.document.path);
    if (!file.existsSync()) {
      _checkingFidelity = false;
      _fidelityDocument = null;
      return;
    }

    final requestedPath = widget.document.path;
    _checkingFidelity = true;
    try {
      final loader = widget.fidelityLoader ?? DocxConversionParser.parse;
      final parsed = widget.fidelityLoader == null
          ? await _sharedFidelityCache.load(file, loader)
          : await loader(file);
      if (!mounted || widget.document.path != requestedPath) return;
      setState(() {
        _checkingFidelity = false;
        _fidelityDocument =
            WordFidelityDocumentView.shouldUseFor(parsed) ? parsed : null;
        _fidelityMatchCount = _fidelityDocument == null ||
                _fidelitySearchQuery.trim().isEmpty
            ? 0
            : WordFidelityDocumentView.countMatches(
                _fidelityDocument!,
                _fidelitySearchQuery,
              );
      });
    } catch (_) {
      if (!mounted || widget.document.path != requestedPath) return;
      // A malformed/unsupported edge case still falls back to the established
      // package renderer instead of blocking document access.
      setState(() {
        _checkingFidelity = false;
        _fidelityDocument = null;
        _fidelityMatchCount = 0;
      });
    }
  }

  @override
  void dispose() {
    _docxSearchController.removeListener(_handleSearchUpdate);
    _docxSearchController.dispose();
    _searchTextController.dispose();
    _viewerFocusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final policy = DocumentViewportPolicy(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );
        final mode = _effectiveMode(policy);
        final fidelityPage = _fidelityDocument?.sections.firstOrNull?.page;
        final fidelityPrintWidth = fidelityPage == null
            ? policy.wordPrintLayoutPageWidth
            : fidelityPage.widthPoints * (96 / 72);
        final pageWidth = mode == _WordViewMode.fitWidth
            ? policy.wordFitWidthPageWidth
            : policy.isDesktop
                ? fidelityPrintWidth
                    .clamp(1.0, policy.wordAvailableWidth)
                    .toDouble()
                : fidelityPrintWidth;

        return Focus(
          focusNode: _viewerFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Column(
            children: [
              _buildToolbar(context, policy, mode),
              if (_showSearch) _buildSearchBar(context),
              Expanded(
                child: ColoredBox(
                  color: scheme.surfaceContainerHigh,
                  child: _checkingFidelity
                      ? const Center(child: CircularProgressIndicator())
                      : _fidelityDocument != null
                          ? WordFidelityDocumentView(
                              document: _fidelityDocument!,
                              pageWidth: pageWidth,
                              searchQuery: _fidelitySearchQuery,
                            )
                          : DocxView(
                              // Use the stable path value instead of constructing
                              // a new File object on every parent rebuild.
                              path: widget.document.path,
                              key: ValueKey('docx-${widget.document.path}'),
                              searchController: _docxSearchController,
                              config: DocxViewConfig(
                                enableSearch: true,
                                enableSelection: true,
                                enableZoom: true,
                                minScale: 0.5,
                                maxScale: 3.5,
                                pageMode: DocxPageMode.continuous,
                                pageWidth: pageWidth,
                                padding: EdgeInsets.symmetric(
                                  horizontal: policy.wordHorizontalGutter,
                                  vertical: policy.wordVerticalGutter,
                                ),
                                backgroundColor: scheme.surfaceContainerHigh,
                                theme: DocxViewTheme.light(),
                              ),
                            ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _WordViewMode _effectiveMode(DocumentViewportPolicy policy) {
    return _userViewMode ??
        (policy.preferWordFitWidth
            ? _WordViewMode.fitWidth
            : _WordViewMode.printLayout);
  }

  Widget _buildToolbar(
    BuildContext context,
    DocumentViewportPolicy policy,
    _WordViewMode mode,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final resultCount = _searchResultCount;
    final currentIndex = _searchCurrentIndex;
    final resultLabel = resultCount > 0
        ? '${currentIndex + 1}/$resultCount'
        : null;

    return Material(
      color: scheme.surface,
      child: SizedBox(
        height: policy.documentToolbarHeight,
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(Icons.description_outlined, size: 19, color: scheme.primary),
            const SizedBox(width: 7),
            if (!policy.isVeryCompactToolbar)
              Text(
                'Word',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (!policy.isVeryCompactToolbar)
              const VerticalDivider(indent: 11, endIndent: 11),
            if (policy.isCompactToolbar)
              PopupMenuButton<_WordViewMode>(
                key: const ValueKey('word-view-mode-menu'),
                tooltip: 'View mode',
                initialValue: mode,
                icon: Icon(
                  mode == _WordViewMode.fitWidth
                      ? Icons.fit_screen_outlined
                      : Icons.article_outlined,
                ),
                onSelected: _setViewMode,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _WordViewMode.fitWidth,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.fit_screen_outlined),
                      title: Text('Fit width'),
                      subtitle: Text('Best for phone reading'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _WordViewMode.printLayout,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.article_outlined),
                      title: Text('Print layout'),
                      subtitle: Text('Original page-sized canvas'),
                    ),
                  ),
                ],
              )
            else ...[
              _WordModeButton(
                label: 'Fit width',
                icon: Icons.fit_screen_outlined,
                selected: mode == _WordViewMode.fitWidth,
                onPressed: () => _setViewMode(_WordViewMode.fitWidth),
              ),
              const SizedBox(width: 4),
              _WordModeButton(
                label: 'Print layout',
                icon: Icons.article_outlined,
                selected: mode == _WordViewMode.printLayout,
                onPressed: () => _setViewMode(_WordViewMode.printLayout),
              ),
            ],
            const Spacer(),
            if (resultLabel != null && !policy.isCompactToolbar)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  resultLabel,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            IconButton(
              key: const ValueKey('word-search-toggle'),
              tooltip: _showSearch ? 'Close search' : 'Search Word (Ctrl+F)',
              onPressed: _toggleSearch,
              icon: Icon(_showSearch ? Icons.search_off : Icons.search),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resultCount = _searchResultCount;
    final currentIndex = _searchCurrentIndex;

    return Material(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('word-search-field'),
                controller: _searchTextController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: _runSearch,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Find in Word document',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchTextController.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close, size: 18),
                        )
                      : null,
                ),
              ),
            ),
            if (resultCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '${currentIndex + 1}/$resultCount',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Previous match',
              onPressed: resultCount > 0 && _fidelityDocument == null
                  ? _docxSearchController.previousMatch
                  : null,
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: 'Next match',
              onPressed: resultCount > 0 && _fidelityDocument == null
                  ? _docxSearchController.nextMatch
                  : null,
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
          ],
        ),
      ),
    );
  }

  void _setViewMode(_WordViewMode mode) {
    if (_userViewMode == mode) return;
    setState(() => _userViewMode = mode);
    _viewerFocusNode.requestFocus();
  }

  void _toggleSearch() {
    if (_showSearch) {
      _clearSearch();
      setState(() => _showSearch = false);
      _viewerFocusNode.requestFocus();
      return;
    }

    setState(() => _showSearch = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _runSearch(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      _clearSearch();
      return;
    }
    if (_fidelityDocument != null) {
      final matches = WordFidelityDocumentView.countMatches(
        _fidelityDocument!,
        query,
      );
      setState(() {
        _fidelitySearchQuery = query;
        _fidelityMatchCount = matches;
      });
    } else {
      _docxSearchController.search(query);
    }
  }

  void _clearSearch() {
    _docxSearchController.clear();
    _fidelitySearchQuery = '';
    _fidelityMatchCount = 0;
    _searchTextController.clear();
    if (mounted) setState(() {});
  }

  int get _searchResultCount {
    if (_fidelityDocument == null) return _docxSearchController.matchCount;
    return _fidelityMatchCount;
  }

  int get _searchCurrentIndex {
    if (_fidelityDocument != null) return _searchResultCount > 0 ? 0 : -1;
    return _docxSearchController.currentMatchIndex;
  }

  void _handleSearchUpdate() {
    if (mounted) setState(() {});
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final controlPressed = HardwareKeyboard.instance.isControlPressed;

    if (controlPressed && key == LogicalKeyboardKey.keyF) {
      if (!_showSearch) _toggleSearch();
      return KeyEventResult.handled;
    }

    if (_showSearch) return KeyEventResult.ignored;
    return KeyEventResult.ignored;
  }
}

class _WordModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _WordModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
