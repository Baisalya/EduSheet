import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/services/document_file_read_service.dart';
import '../../../data/services/presentation_parser_service.dart';
import '../../../domain/models/document_model.dart';
import '../../../domain/models/presentation_model.dart';

class PresentationDocumentViewer extends StatefulWidget {
  final DocumentFile document;
  final PresentationParserService? parserService;

  const PresentationDocumentViewer({
    super.key,
    required this.document,
    this.parserService,
  });

  @override
  State<PresentationDocumentViewer> createState() =>
      _PresentationDocumentViewerState();
}

class _PresentationDocumentViewerState
    extends State<PresentationDocumentViewer> {
  late final PresentationParserService _parserService;
  late Future<PresentationDocument> _future;
  final FocusNode _focusNode = FocusNode(debugLabel: 'presentation-viewer');
  int _selectedIndex = 0;
  double _zoom = 1;

  @override
  void initState() {
    super.initState();
    _parserService = widget.parserService ?? PresentationParserService();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant PresentationDocumentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.path != widget.document.path) {
      _selectedIndex = 0;
      _future = _load();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<PresentationDocument> _load() =>
      _parserService.load(File(widget.document.path));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PresentationDocument>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _PresentationLoadingState();
        }
        if (snapshot.hasError) {
          return _PresentationErrorState(
            error: snapshot.error,
            document: widget.document,
            onRetry: _retry,
          );
        }
        final presentation = snapshot.data!;
        if (presentation.slides.isEmpty) {
          return const Center(child: Text('No readable slides found.'));
        }
        if (_selectedIndex >= presentation.slides.length) _selectedIndex = 0;

        return Focus(
          autofocus: true,
          focusNode: _focusNode,
          onKeyEvent: (node, event) => _handleKeyEvent(event, presentation),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showSidebar = constraints.maxWidth >= 900;
              return Column(
                children: [
                  _PresentationToolbar(
                    index: _selectedIndex,
                    slideCount: presentation.slides.length,
                    zoom: _zoom,
                    onPrevious: _selectedIndex > 0
                        ? () => _select(_selectedIndex - 1)
                        : null,
                    onNext: _selectedIndex < presentation.slides.length - 1
                        ? () => _select(_selectedIndex + 1)
                        : null,
                    onZoomOut: _zoom > 0.65
                        ? () => setState(
                            () => _zoom = math.max(0.65, _zoom - 0.1).toDouble(),
                          )
                        : null,
                    onZoomIn: _zoom < 2.4
                        ? () => setState(
                            () => _zoom = math.min(2.4, _zoom + 0.1).toDouble(),
                          )
                        : null,
                    onPresent: () => _openPresentationMode(presentation),
                  ),
                  if (presentation.slides.any((slide) => slide.hasNativeAnimations))
                    const _NativeAnimationNotice(),
                  Expanded(
                    child: Row(
                      children: [
                        if (showSidebar)
                          SizedBox(
                            width: 190,
                            child: _SlideThumbnailRail(
                              presentation: presentation,
                              selectedIndex: _selectedIndex,
                              onSelected: _select,
                            ),
                          ),
                        if (showSidebar) const VerticalDivider(width: 1),
                        Expanded(
                          child: _PresentationStage(
                            presentation: presentation,
                            selectedIndex: _selectedIndex,
                            zoom: _zoom,
                            onPrevious: _selectedIndex > 0
                                ? () => _select(_selectedIndex - 1)
                                : null,
                            onNext:
                                _selectedIndex < presentation.slides.length - 1
                                ? () => _select(_selectedIndex + 1)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _retry() {
    final nextLoad = Completer<PresentationDocument>();

    setState(() {
      _future = nextLoad.future;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || nextLoad.isCompleted) return;
      try {
        final result = await _load();
        if (!mounted || nextLoad.isCompleted) return;
        nextLoad.complete(result);
      } catch (error, stackTrace) {
        if (!mounted || nextLoad.isCompleted) return;
        nextLoad.completeError(error, stackTrace);
      }
    });
  }

  void _select(int index) => setState(() => _selectedIndex = index);

  Future<void> _openPresentationMode(PresentationDocument presentation) async {
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => _PresentationModePage(
          presentation: presentation,
          initialIndex: _selectedIndex,
          title: widget.document.name,
        ),
      ),
    );
    if (result != null && mounted) setState(() => _selectedIndex = result);
    _focusNode.requestFocus();
  }

  KeyEventResult _handleKeyEvent(
    KeyEvent event,
    PresentationDocument presentation,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      if (_selectedIndex > 0) _select(_selectedIndex - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.pageDown ||
        event.logicalKey == LogicalKeyboardKey.space) {
      if (_selectedIndex < presentation.slides.length - 1) {
        _select(_selectedIndex + 1);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      _select(0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      _select(presentation.slides.length - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f5) {
      _openPresentationMode(presentation);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

class _PresentationToolbar extends StatelessWidget {
  final int index;
  final int slideCount;
  final double zoom;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomIn;
  final VoidCallback onPresent;

  const _PresentationToolbar({
    required this.index,
    required this.slideCount,
    required this.zoom,
    required this.onPrevious,
    required this.onNext,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onPresent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1B1F26) : Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use the toolbar's real allocation instead of the window MediaQuery.
          // This keeps compact mode correct inside Android free-form windows,
          // split panes, tests, and other nested/resizable containers.
          final compact = constraints.maxWidth < 650;
          final veryCompact = constraints.maxWidth < 360;

          return SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Previous slide',
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${index + 1} / $slideCount',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                IconButton(
                  tooltip: 'Next slide',
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                ),
                if (!compact)
                  const VerticalDivider(indent: 10, endIndent: 10),
                if (!compact)
                  IconButton(
                    tooltip: 'Zoom out',
                    onPressed: onZoomOut,
                    icon: const Icon(Icons.remove),
                  ),
                if (!compact)
                  Text(
                    '${(zoom * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                if (!compact)
                  IconButton(
                    tooltip: 'Zoom in',
                    onPressed: onZoomIn,
                    icon: const Icon(Icons.add),
                  ),
                const Spacer(),
                if (veryCompact)
                  FilledButton(
                    onPressed: onPresent,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('Play'),
                  )
                else
                  FilledButton.icon(
                    onPressed: onPresent,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(compact ? 'Play' : 'Present'),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PresentationStage extends StatelessWidget {
  final PresentationDocument presentation;
  final int selectedIndex;
  final double zoom;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _PresentationStage({
    required this.presentation,
    required this.selectedIndex,
    required this.zoom,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final slide = presentation.slides[selectedIndex];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -250) onNext?.call();
        if (velocity > 250) onPrevious?.call();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = math.max(280.0, constraints.maxWidth - 32).toDouble();
          final maxHeight = math.max(200.0, constraints.maxHeight - 32).toDouble();
          final ratio = presentation.aspectRatio;
          var width = math.min(maxWidth, maxHeight * ratio).toDouble() * zoom;
          var height = width / ratio;
          if (height < 160) {
            height = 160;
            width = height * ratio;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(width, maxWidth).toDouble(),
                height: math.max(height, maxHeight).toDouble(),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: slide.transition.duration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) =>
                        _buildSlideTransition(slide.transition, child, animation),
                    child: _PptxSlideCanvas(
                      key: ValueKey('slide-${slide.number}'),
                      slide: slide,
                      width: width,
                      height: height,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SlideThumbnailRail extends StatelessWidget {
  final PresentationDocument presentation;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _SlideThumbnailRail({
    required this.presentation,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: presentation.slides.length,
      itemBuilder: (context, index) {
        final selected = index == selectedIndex;
        final width = 160.0;
        final height = width / presentation.aspectRatio;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSelected(index),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? Colors.deepOrange : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  IgnorePointer(
                    child: _PptxSlideCanvas(
                      slide: presentation.slides[index],
                      width: width,
                      height: height,
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PptxSlideCanvas extends StatelessWidget {
  final PresentationSlide slide;
  final double width;
  final double height;
  final bool compact;

  const _PptxSlideCanvas({
    super.key,
    required this.slide,
    required this.width,
    required this.height,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = slide.backgroundColor == null
        ? Colors.white
        : Color(slide.backgroundColor!);
    final positioned = slide.elements.where((e) => e.hasBounds).toList();
    final fallback = slide.elements.where((e) => !e.hasBounds).toList();

    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(compact ? 4 : 8),
          boxShadow: compact
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final element in positioned)
              Positioned(
                left: element.left * width,
                top: element.top * height,
                width: math.max(1.0, element.width * width).toDouble(),
                height: math.max(1.0, element.height * height).toDouble(),
                child: _PresentationElementView(
                  element: element,
                  slideWidth: width,
                  compact: compact,
                ),
              ),
            if (fallback.isNotEmpty)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(width * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final element in fallback.take(compact ? 3 : 8))
                        Flexible(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: width * 0.012),
                            child: _PresentationElementView(
                              element: element,
                              slideWidth: width,
                              compact: compact,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresentationElementView extends StatelessWidget {
  final PresentationElement element;
  final double slideWidth;
  final bool compact;

  const _PresentationElementView({
    required this.element,
    required this.slideWidth,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    if (element.type == PresentationElementType.image &&
        element.imageBytes != null) {
      return Image.memory(
        element.imageBytes!,
        fit: BoxFit.contain,
        filterQuality: compact ? FilterQuality.low : FilterQuality.medium,
        gaplessPlayback: true,
      );
    }

    final scale = slideWidth / 960;
    final fontSize = (element.fontSizePoints ?? (element.bold ? 26 : 18)) * scale;
    final color = element.textColor == null
        ? Colors.black87
        : Color(element.textColor!);
    final alignment = switch (element.alignment) {
      'ctr' => TextAlign.center,
      'r' => TextAlign.right,
      'just' => TextAlign.justify,
      _ => TextAlign.left,
    };

    return Container(
      padding: EdgeInsets.all(
        compact ? 1.0 : math.max(2.0, slideWidth * 0.004).toDouble(),
      ),
      color: element.fillColor == null
          ? Colors.transparent
          : Color(element.fillColor!),
      alignment: switch (alignment) {
        TextAlign.center => Alignment.center,
        TextAlign.right => Alignment.centerRight,
        _ => Alignment.centerLeft,
      },
      child: Text(
        element.text,
        maxLines: compact ? 3 : null,
        overflow: compact ? TextOverflow.ellipsis : TextOverflow.clip,
        textAlign: alignment,
        style: TextStyle(
          color: color,
          fontSize: math.max(compact ? 4.0 : 8.0, fontSize).toDouble(),
          height: 1.12,
          fontWeight: element.bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}

Widget _buildSlideTransition(
  PresentationTransition transition,
  Widget child,
  Animation<double> animation,
) {
  switch (transition.kind) {
    case PresentationTransitionKind.push:
    case PresentationTransitionKind.cover:
    case PresentationTransitionKind.uncover:
      final fromRight = transition.direction != 'r';
      return SlideTransition(
        position: Tween<Offset>(
          begin: Offset(fromRight ? 0.12 : -0.12, 0),
          end: Offset.zero,
        ).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      );
    case PresentationTransitionKind.wipe:
    case PresentationTransitionKind.split:
      return ScaleTransition(
        alignment: Alignment.centerLeft,
        scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      );
    case PresentationTransitionKind.zoom:
      return ScaleTransition(
        scale: Tween<double>(begin: 0.88, end: 1).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      );
    case PresentationTransitionKind.fade:
    case PresentationTransitionKind.none:
      return FadeTransition(opacity: animation, child: child);
  }
}

class _PresentationModePage extends StatefulWidget {
  final PresentationDocument presentation;
  final int initialIndex;
  final String title;

  const _PresentationModePage({
    required this.presentation,
    required this.initialIndex,
    required this.title,
  });

  @override
  State<_PresentationModePage> createState() => _PresentationModePageState();
}

class _PresentationModePageState extends State<_PresentationModePage> {
  late int _index;
  final FocusNode _focusNode = FocusNode(debugLabel: 'presentation-mode');
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.presentation.slides[_index];
    return Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          focusNode: _focusNode,
          onKeyEvent: _handleKey,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _showControls = !_showControls),
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -250) _next();
              if (velocity > 250) _previous();
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final ratio = widget.presentation.aspectRatio;
                      final width = math.min(
                        constraints.maxWidth,
                        constraints.maxHeight * ratio,
                      ).toDouble();
                      final height = width / ratio;
                      return Center(
                        child: AnimatedSwitcher(
                          duration: slide.transition.duration,
                          transitionBuilder: (child, animation) =>
                              _buildSlideTransition(
                                slide.transition,
                                child,
                                animation,
                              ),
                          child: _PptxSlideCanvas(
                            key: ValueKey('present-${slide.number}'),
                            slide: slide,
                            width: width,
                            height: height,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_showControls)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: SafeArea(
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Exit presentation',
                            onPressed: () => Navigator.of(context).pop(_index),
                            icon: const Icon(Icons.close),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${_index + 1} / ${widget.presentation.slides.length}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_showControls)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: SafeArea(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            onPressed: _index > 0 ? _previous : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          const SizedBox(width: 18),
                          IconButton.filledTonal(
                            onPressed: _index < widget.presentation.slides.length - 1
                                ? _next
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
    );
  }

  void _next() {
    if (_index < widget.presentation.slides.length - 1) {
      setState(() => _index++);
    }
  }

  void _previous() {
    if (_index > 0) setState(() => _index--);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop(_index);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.pageDown ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _next();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      _previous();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

class _NativeAnimationNotice extends StatelessWidget {
  const _NativeAnimationNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: Colors.deepOrange.withValues(alpha: 0.12),
      child: const Text(
        'This deck contains native PowerPoint object animations. EduSheet preserves the slide and supported slide transitions, but does not execute every Office animation sequence.',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PresentationLoadingState extends StatelessWidget {
  const _PresentationLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('Preparing slides…'),
        ],
      ),
    );
  }
}

class _PresentationErrorState extends StatelessWidget {
  final Object? error;
  final DocumentFile document;
  final VoidCallback onRetry;

  const _PresentationErrorState({
    required this.error,
    required this.document,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final currentError = error;
    final readError = currentError is DocumentFileReadException
        ? currentError
        : null;
    final isCloudUnavailable =
        readError?.kind == DocumentFileReadFailure.cloudProviderUnavailable;

    final title = isCloudUnavailable
        ? 'OneDrive file is not available offline'
        : 'Unable to read this presentation';
    final message = isCloudUnavailable
        ? 'Windows can see this PPTX placeholder, but OneDrive is not currently providing the file contents. Start OneDrive or make the file available offline, then retry.'
        : readError?.message ??
              'The presentation could not be decoded. The file may be unavailable, incomplete, or damaged.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCloudUnavailable ? Icons.cloud_off_outlined : Icons.error_outline,
                size: 54,
                color: isCloudUnavailable ? Colors.orangeAccent : Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (isCloudUnavailable) ...[
                const SizedBox(height: 12),
                Text(
                  'File: ${document.path}',
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tip: in File Explorer, right-click the file and choose “Always keep on this device”, or start OneDrive and wait for the file to finish downloading.',
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
