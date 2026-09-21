import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:edusheet/features/document_reader/domain/models/document_model.dart';
import '../../responsive/document_viewport_policy.dart';

enum _PdfFitMode { fitWidth, fitPage, custom }

class PdfDocumentViewer extends StatefulWidget {
  final DocumentFile document;

  const PdfDocumentViewer({super.key, required this.document});

  @override
  State<PdfDocumentViewer> createState() => _PdfDocumentViewerState();
}

class _PdfDocumentViewerState extends State<PdfDocumentViewer> {
  static const double _minZoom = 1.0;
  static const double _maxZoom = 4.0;

  final PdfViewerController _controller = PdfViewerController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _viewerFocusNode = FocusNode(debugLabel: 'pdf-viewer');
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'pdf-search');

  PdfTextSearchResult? _searchResult;
  bool _showSearch = false;
  String? _error;
  int _page = 1;
  int _pageCount = 0;
  double _zoom = 1;
  _PdfFitMode _fitMode = _PdfFitMode.fitWidth;
  PdfPageLayoutMode _pageLayoutMode = PdfPageLayoutMode.continuous;

  @override
  void dispose() {
    _searchResult?.removeListener(_handleSearchUpdate);
    _searchController.dispose();
    _viewerFocusNode.dispose();
    _searchFocusNode.dispose();
    _controller.dispose();
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
        return Focus(
          focusNode: _viewerFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Column(
            children: [
              _buildToolbar(context, policy),
              if (_showSearch) _buildSearchBar(context),
              Expanded(
                child: _error == null
                    ? ColoredBox(
                        color: scheme.surfaceContainerHigh,
                        child: SfPdfViewer.file(
                          File(widget.document.path),
                          controller: _controller,
                          initialZoomLevel: 1,
                          maxZoomLevel: _maxZoom,
                          pageLayoutMode: _pageLayoutMode,
                          scrollDirection: PdfScrollDirection.vertical,
                          enableDoubleTapZooming: true,
                          canShowScrollHead: true,
                          canShowScrollStatus: true,
                          enableTextSelection: true,
                          onDocumentLoaded: (details) {
                            if (!mounted) return;
                            setState(() {
                              _error = null;
                              _pageCount = details.document.pages.count;
                              _page = _page
                                  .clamp(1, _pageCount == 0 ? 1 : _pageCount)
                                  .toInt();
                              _zoom = _controller.zoomLevel
                                  .clamp(_minZoom, _maxZoom)
                                  .toDouble();
                            });
                          },
                          onDocumentLoadFailed: (details) {
                            if (!mounted) return;
                            setState(
                              () => _error =
                                  'PDF load failed: ${details.description}',
                            );
                          },
                          onPageChanged: (details) {
                            if (!mounted) return;
                            setState(() => _page = details.newPageNumber);
                          },
                          onZoomLevelChanged: (details) {
                            if (!mounted) return;
                            final next = details.newZoomLevel
                                .clamp(_minZoom, _maxZoom)
                                .toDouble();
                            setState(() {
                              _zoom = next;
                              if (next > 1.001) {
                                _fitMode = _PdfFitMode.custom;
                              }
                            });
                          },
                        ),
                      )
                    : _PdfErrorState(
                        message: _error!,
                        onRetry: () => setState(() => _error = null),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    DocumentViewportPolicy policy,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final compact = policy.isCompactToolbar;
    final veryCompact = policy.isVeryCompactToolbar;
    final searchResult = _searchResult;
    final resultLabel = searchResult != null && searchResult.hasResult
        ? '${searchResult.currentInstanceIndex}/${searchResult.totalInstanceCount}'
        : null;

    return Material(
      color: scheme.surface,
      child: SizedBox(
        height: policy.documentToolbarHeight,
        child: Row(
          children: [
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Previous page',
              onPressed: _page > 1 ? _controller.previousPage : null,
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pageCount > 0 ? _showPageJumpDialog : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  _pageCount == 0 ? 'Page —' : '$_page / $_pageCount',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: _pageCount > 0 && _page < _pageCount
                  ? _controller.nextPage
                  : null,
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            if (!veryCompact) const VerticalDivider(indent: 10, endIndent: 10),
            if (!veryCompact)
              IconButton(
                tooltip: 'Zoom out',
                onPressed: _zoom > _minZoom
                    ? () => _setZoom(_zoom - 0.25)
                    : null,
                icon: const Icon(Icons.remove),
              ),
            if (!compact)
              SizedBox(
                width: 54,
                child: Text(
                  '${(_zoom * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            if (!veryCompact)
              IconButton(
                tooltip: 'Zoom in',
                onPressed: _zoom < _maxZoom
                    ? () => _setZoom(_zoom + 0.25)
                    : null,
                icon: const Icon(Icons.add),
              ),
            if (!compact)
              PopupMenuButton<_PdfFitMode>(
                tooltip: 'Page fit',
                icon: Icon(
                  _fitMode == _PdfFitMode.fitPage
                      ? Icons.fullscreen_outlined
                      : Icons.fit_screen_outlined,
                ),
                onSelected: (mode) {
                  if (mode == _PdfFitMode.fitPage) {
                    _applyFitPage();
                  } else {
                    _applyFitWidth();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _PdfFitMode.fitWidth,
                    child: Text('Fit width'),
                  ),
                  PopupMenuItem(
                    value: _PdfFitMode.fitPage,
                    child: Text('Fit page'),
                  ),
                ],
              ),
            if (veryCompact)
              PopupMenuButton<String>(
                tooltip: 'View options',
                icon: const Icon(Icons.fit_screen_outlined),
                onSelected: (value) {
                  if (value == 'fitWidth') {
                    _applyFitWidth();
                  } else if (value == 'fitPage') {
                    _applyFitPage();
                  } else if (value == 'in') {
                    _setZoom(_zoom + 0.25);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'fitWidth',
                    child: Text('Fit width'),
                  ),
                  PopupMenuItem(
                    value: 'fitPage',
                    child: Text('Fit page'),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'in', child: Text('Zoom in')),
                ],
              ),
            const Spacer(),
            if (resultLabel != null && !compact)
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
              tooltip: _showSearch ? 'Close search' : 'Search PDF (Ctrl+F)',
              onPressed: _toggleSearch,
              icon: Icon(_showSearch ? Icons.search_off : Icons.search),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final result = _searchResult;
    final searching = result != null && !result.isSearchCompleted;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('pdf-search-field'),
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: _runSearch,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Find in PDF',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _searchController.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close, size: 18),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Previous match',
              onPressed: result?.hasResult == true
                  ? result!.previousInstance
                  : null,
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: 'Next match',
              onPressed: result?.hasResult == true
                  ? result!.nextInstance
                  : null,
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
          ],
        ),
      ),
    );
  }

  void _setZoom(double value) {
    final next = value.clamp(_minZoom, _maxZoom).toDouble();
    _controller.zoomLevel = next;
    setState(() {
      _zoom = next;
      if (next > 1.001) _fitMode = _PdfFitMode.custom;
    });
  }

  void _applyFitWidth() {
    final currentPage = _page;
    setState(() {
      _fitMode = _PdfFitMode.fitWidth;
      _pageLayoutMode = PdfPageLayoutMode.continuous;
      _zoom = 1;
    });
    _controller.zoomLevel = 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && currentPage > 0) _controller.jumpToPage(currentPage);
    });
  }

  void _applyFitPage() {
    final currentPage = _page;
    setState(() {
      _fitMode = _PdfFitMode.fitPage;
      _pageLayoutMode = PdfPageLayoutMode.single;
      _zoom = 1;
    });
    _controller.zoomLevel = 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && currentPage > 0) _controller.jumpToPage(currentPage);
    });
  }

  void _toggleSearch() {
    if (_showSearch) {
      _clearSearch();
      setState(() => _showSearch = false);
      _viewerFocusNode.requestFocus();
    } else {
      setState(() => _showSearch = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  void _runSearch(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      _clearSearch();
      return;
    }

    _searchResult?.removeListener(_handleSearchUpdate);
    _searchResult?.clear();
    final result = _controller.searchText(query);
    result.addListener(_handleSearchUpdate);
    setState(() => _searchResult = result);
  }

  void _clearSearch() {
    _searchResult?.removeListener(_handleSearchUpdate);
    _searchResult?.clear();
    setState(() => _searchResult = null);
    _searchController.clear();
  }

  void _handleSearchUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _showPageJumpDialog() async {
    final controller = TextEditingController(text: '$_page');
    final page = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to page'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (value) {
            final parsed = int.tryParse(value);
            if (parsed != null) Navigator.of(context).pop(parsed);
          },
          decoration: InputDecoration(hintText: '1–$_pageCount'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text)),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (page != null && page >= 1 && page <= _pageCount) {
      _controller.jumpToPage(page);
    }
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

    if (key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.arrowDown) {
      _controller.nextPage();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp || key == LogicalKeyboardKey.arrowUp) {
      _controller.previousPage();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home && controlPressed) {
      _controller.firstPage();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end && controlPressed) {
      _controller.lastPage();
      return KeyEventResult.handled;
    }
    if (controlPressed && key == LogicalKeyboardKey.digit0) {
      _applyFitWidth();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.add || key == LogicalKeyboardKey.numpadAdd) {
      _setZoom(_zoom + 0.25);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      _setZoom(_zoom - 0.25);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

class _PdfErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PdfErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 58, color: Colors.redAccent),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
