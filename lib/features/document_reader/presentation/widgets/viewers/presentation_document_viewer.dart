import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/services/document_file_read_service.dart';
import '../../../data/services/presentation_parser_service.dart';
import '../../../domain/models/document_model.dart';
import '../../../domain/models/presentation_model.dart';
import '../../../domain/models/presentation_animation_timeline.dart';
import '../../responsive/presentation_stage_policy.dart';

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
                            () =>
                                _zoom = math.max(0.65, _zoom - 0.1).toDouble(),
                          )
                        : null,
                    onZoomIn: _zoom < 2.4
                        ? () => setState(
                            () => _zoom = math.min(2.4, _zoom + 0.1).toDouble(),
                          )
                        : null,
                    onPresent: () => _openPresentationMode(presentation),
                  ),
                  if (presentation.slides.any(
                    (slide) => slide.hasNativeAnimations,
                  ))
                    _NativeAnimationNotice(presentation: presentation),
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

  Future<void> _openPresentationMode(
    PresentationDocument presentation, {
    int? initialIndex,
  }) async {
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => _PresentationModePage(
          presentation: presentation,
          initialIndex: initialIndex ?? _selectedIndex,
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
      _openPresentationMode(presentation, initialIndex: 0);
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
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
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
                if (!compact) const VerticalDivider(indent: 10, endIndent: 10),
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
          final viewport = Size(
            math.max(0.0, constraints.maxWidth - 32).toDouble(),
            math.max(0.0, constraints.maxHeight - 32).toDouble(),
          );
          final fitted = PresentationStagePolicy.contain(
            viewport: viewport,
            aspectRatio: presentation.aspectRatio,
          );
          final width = fitted.slideSize.width * zoom;
          final height = fitted.slideSize.height * zoom;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(width, viewport.width).toDouble(),
                height: math.max(height, viewport.height).toDouble(),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: slide.transition.duration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) =>
                        _buildSlideTransition(
                          slide.transition,
                          child,
                          animation,
                        ),
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
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
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
  final PresentationAnimationTimeline? animationTimeline;
  final int completedAnimationGroups;
  final int? activeAnimationGroupIndex;
  final Animation<double>? activeAnimationProgress;

  const _PptxSlideCanvas({
    super.key,
    required this.slide,
    required this.width,
    required this.height,
    this.compact = false,
    this.animationTimeline,
    this.completedAnimationGroups = 0,
    this.activeAnimationGroupIndex,
    this.activeAnimationProgress,
  });

  @override
  Widget build(BuildContext context) {
    final progress = activeAnimationProgress;
    if (progress != null && activeAnimationGroupIndex != null) {
      return AnimatedBuilder(
        animation: progress,
        builder: (context, _) => _buildCanvas(context, progress.value),
      );
    }
    return _buildCanvas(context, 0);
  }

  Widget _buildCanvas(BuildContext context, double activeProgress) {
    final positioned = slide.elements.where((e) => e.hasBounds).toList();
    final fallback = slide.elements.where((e) => !e.hasBounds).toList();
    final backgroundGradient = slide.backgroundGradient == null
        ? null
        : _presentationGradient(slide.backgroundGradient!);

    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: backgroundGradient == null
              ? Color(slide.backgroundColor ?? 0xFFFFFFFF)
              : null,
          gradient: backgroundGradient,
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
            // The parser emits elements in PowerPoint spTree order. Stack paints
            // in the same order, preserving the presentation's z-order.
            for (final element in positioned)
              Positioned(
                left: element.left * width,
                top: element.top * height,
                width: math.max(1.0, element.width * width).toDouble(),
                height: math.max(1.0, element.height * height).toDouble(),
                child: Transform.rotate(
                  angle: element.rotationDegrees * math.pi / 180,
                  child: _animatedElement(
                    element,
                    activeProgress: activeProgress,
                    child: _PresentationElementView(
                      element: element,
                      slideWidth: width,
                      compact: compact,
                    ),
                  ),
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
                            child: _animatedElement(
                              element,
                              activeProgress: activeProgress,
                              child: _PresentationElementView(
                                element: element,
                                slideWidth: width,
                                compact: compact,
                              ),
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

  Widget _animatedElement(
    PresentationElement element, {
    required double activeProgress,
    required Widget child,
  }) {
    final timeline = animationTimeline;
    final objectId = element.objectId;
    if (timeline == null || objectId == null || objectId.isEmpty) return child;

    final state = _presentationAnimationStateForElement(
      objectId: objectId,
      timeline: timeline,
      completedAnimationGroups: completedAnimationGroups,
      activeAnimationGroupIndex: activeAnimationGroupIndex,
      activeAnimationProgress: activeProgress,
    );
    if (!state.visible || state.opacity <= 0.001) {
      return const SizedBox.shrink();
    }

    Widget current = child;
    if (state.wipeFactor < 0.999) {
      current = ClipRect(
        clipper: _AnimationWipeClipper(
          factor: state.wipeFactor,
          direction: state.wipeDirection,
        ),
        child: current,
      );
    }
    if ((state.scale - 1).abs() > 0.001) {
      current = Transform.scale(scale: state.scale, child: current);
    }
    if (state.translation != Offset.zero) {
      current = FractionalTranslation(
        translation: state.translation,
        transformHitTests: false,
        child: current,
      );
    }
    if (state.opacity < 0.999) {
      current = Opacity(
        opacity: state.opacity.clamp(0.0, 1.0).toDouble(),
        child: current,
      );
    }
    return current;
  }
}

class _PresentationElementAnimationState {
  bool visible;
  double opacity;
  double scale = 1;
  Offset translation = Offset.zero;
  double wipeFactor = 1;
  String? wipeDirection;

  _PresentationElementAnimationState({
    required this.visible,
    required this.opacity,
  });
}

_PresentationElementAnimationState _presentationAnimationStateForElement({
  required String objectId,
  required PresentationAnimationTimeline timeline,
  required int completedAnimationGroups,
  required int? activeAnimationGroupIndex,
  required double activeAnimationProgress,
}) {
  final targeted = <ScheduledPresentationAnimation>[];
  for (final group in timeline.groups) {
    for (final animation in group.animations) {
      if (animation.step.targetObjectId == objectId &&
          animation.step.supported) {
        targeted.add(animation);
      }
    }
  }

  final firstVisualStep = targeted.isEmpty ? null : targeted.first.step;
  final startsHidden = firstVisualStep?.isEntrance == true;
  final state = _PresentationElementAnimationState(
    visible: !startsHidden,
    opacity: startsHidden ? 0 : 1,
  );

  for (final group in timeline.groups) {
    double? groupProgress;
    if (group.index < completedAnimationGroups) {
      groupProgress = 1;
    } else if (group.index == activeAnimationGroupIndex) {
      groupProgress = activeAnimationProgress.clamp(0.0, 1.0);
    }
    if (groupProgress == null) continue;

    final groupElapsedMs = group.duration.inMilliseconds * groupProgress;
    for (final scheduled in group.animations) {
      final step = scheduled.step;
      if (step.targetObjectId != objectId || !step.supported) continue;
      final startMs = scheduled.start.inMilliseconds.toDouble();
      final endMs = scheduled.end.inMilliseconds.toDouble();
      final local = endMs <= startMs
          ? (groupElapsedMs >= endMs ? 1.0 : 0.0)
          : ((groupElapsedMs - startMs) / (endMs - startMs))
                .clamp(0.0, 1.0)
                .toDouble();
      if (local <= 0) continue;
      _applyPresentationAnimationStep(state, step, local);
    }
  }
  return state;
}

void _applyPresentationAnimationStep(
  _PresentationElementAnimationState state,
  PresentationAnimationStep step,
  double progress,
) {
  final p = progress.clamp(0.0, 1.0).toDouble();
  switch (step.kind) {
    case PresentationAnimationKind.appear:
      state.visible = true;
      state.opacity = 1;
      break;
    case PresentationAnimationKind.fadeIn:
      state.visible = true;
      state.opacity = p;
      break;
    case PresentationAnimationKind.fadeOut:
      state.visible = p < 1;
      state.opacity = 1 - p;
      break;
    case PresentationAnimationKind.flyIn:
      state.visible = true;
      state.opacity = p;
      state.translation = _animationDirectionOffset(step.direction) * (1 - p);
      break;
    case PresentationAnimationKind.flyOut:
      state.visible = p < 1;
      state.opacity = 1 - p;
      state.translation = _animationDirectionOffset(step.direction) * p;
      break;
    case PresentationAnimationKind.wipeIn:
      state.visible = true;
      state.opacity = 1;
      state.wipeFactor = p;
      state.wipeDirection = step.direction;
      break;
    case PresentationAnimationKind.wipeOut:
      state.visible = p < 1;
      state.wipeFactor = 1 - p;
      state.wipeDirection = step.direction;
      break;
    case PresentationAnimationKind.zoomIn:
      state.visible = true;
      state.opacity = p;
      state.scale = 0.72 + 0.28 * p;
      break;
    case PresentationAnimationKind.zoomOut:
      state.visible = p < 1;
      state.opacity = 1 - p;
      state.scale = 1 - 0.28 * p;
      break;
    case PresentationAnimationKind.growShrink:
      state.visible = true;
      final peak = step.magnitude.clamp(0.5, 3.0).toDouble();
      state.scale = 1 + (peak - 1) * math.sin(math.pi * p);
      break;
    case PresentationAnimationKind.pulse:
      state.visible = true;
      state.scale = 1 + 0.08 * math.sin(math.pi * p);
      break;
    case PresentationAnimationKind.disappear:
      if (p > 0) {
        state.visible = false;
        state.opacity = 0;
      }
      break;
    case PresentationAnimationKind.unsupported:
      break;
  }
}

Offset _animationDirectionOffset(String? direction) {
  return switch (direction) {
    'l' || 'left' => const Offset(-0.36, 0),
    'r' || 'right' => const Offset(0.36, 0),
    'u' || 'up' || 't' => const Offset(0, -0.36),
    'd' || 'down' || 'b' => const Offset(0, 0.36),
    _ => const Offset(0, 0.28),
  };
}

class _AnimationWipeClipper extends CustomClipper<Rect> {
  final double factor;
  final String? direction;

  const _AnimationWipeClipper({required this.factor, this.direction});

  @override
  Rect getClip(Size size) {
    final amount = factor.clamp(0.0, 1.0).toDouble();
    return switch (direction) {
      'r' || 'right' =>
        Rect.fromLTWH(size.width * (1 - amount), 0, size.width * amount, size.height),
      'u' || 'up' || 't' =>
        Rect.fromLTWH(0, size.height * (1 - amount), size.width, size.height * amount),
      'd' || 'down' || 'b' =>
        Rect.fromLTWH(0, 0, size.width, size.height * amount),
      _ => Rect.fromLTWH(0, 0, size.width * amount, size.height),
    };
  }

  @override
  bool shouldReclip(covariant _AnimationWipeClipper oldClipper) {
    return oldClipper.factor != factor || oldClipper.direction != direction;
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
    final fontSize =
        (element.fontSizePoints ?? (element.bold ? 26 : 18)) * scale;
    final color = element.textColor == null
        ? Colors.black87
        : Color(element.textColor!);
    final alignment = switch (element.alignment) {
      'ctr' => TextAlign.center,
      'r' => TextAlign.right,
      'just' || 'dist' => TextAlign.justify,
      _ => TextAlign.left,
    };
    final fillGradient = element.fillGradient == null
        ? null
        : _presentationGradient(element.fillGradient!);
    final strokeWidth = element.strokeWidthPoints == null
        ? 0.0
        : math.max(0.5, element.strokeWidthPoints! * scale).toDouble();
    final cornerRadius = switch (element.shapeKind) {
      'roundRect' => math.max(4.0, slideWidth * 0.012).toDouble(),
      _ => 0.0,
    };

    final child = element.textRuns.isEmpty
        ? Text(
            element.text,
            maxLines: compact ? 3 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.clip,
            textAlign: alignment,
            style: TextStyle(
              color: color,
              fontSize: math.max(compact ? 4.0 : 8.0, fontSize).toDouble(),
              height: 1.12,
              fontFamily: _safeFontFamily(element.fontFamily),
              fontWeight: element.bold ? FontWeight.w700 : FontWeight.w400,
              fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
              decoration:
                  element.underline ? TextDecoration.underline : TextDecoration.none,
            ),
          )
        : RichText(
            maxLines: compact ? 3 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.clip,
            textAlign: alignment,
            text: TextSpan(
              children: [
                for (final run in element.textRuns)
                  TextSpan(
                    text: run.text,
                    style: TextStyle(
                      color: Color(run.color ?? element.textColor ?? 0xDE000000),
                      fontSize: math.max(
                        compact ? 4.0 : 8.0,
                        (run.fontSizePoints ?? element.fontSizePoints ?? 18) *
                            scale,
                      ).toDouble(),
                      height: 1.12,
                      fontFamily: _safeFontFamily(
                        run.fontFamily ?? element.fontFamily,
                      ),
                      fontWeight: run.bold ? FontWeight.w700 : FontWeight.w400,
                      fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
                      decoration:
                          run.underline ? TextDecoration.underline : TextDecoration.none,
                    ),
                  ),
              ],
            ),
          );

    return Container(
      padding: EdgeInsets.all(
        compact ? 1.0 : math.max(2.0, slideWidth * 0.004).toDouble(),
      ),
      decoration: BoxDecoration(
        color: fillGradient == null && element.fillColor != null
            ? Color(element.fillColor!)
            : null,
        gradient: fillGradient,
        borderRadius: BorderRadius.circular(cornerRadius),
        border: element.strokeColor == null
            ? null
            : Border.all(
                color: Color(element.strokeColor!),
                width: strokeWidth,
              ),
      ),
      alignment: switch (alignment) {
        TextAlign.center => Alignment.center,
        TextAlign.right => Alignment.centerRight,
        _ => Alignment.centerLeft,
      },
      child: child,
    );
  }
}

String? _safeFontFamily(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  // Office theme tokens are resolved by the parser. Empty/theme-only tokens
  // must not be sent to Flutter as literal font families.
  if (trimmed.startsWith('+')) return null;
  return trimmed;
}

LinearGradient _presentationGradient(PresentationGradient gradient) {
  final angle = gradient.angleDegrees * math.pi / 180;
  final x = math.cos(angle);
  final y = math.sin(angle);
  final stops = [...gradient.stops]..sort(
    (a, b) => a.position.compareTo(b.position),
  );
  if (stops.length == 1) {
    stops.add(
      PresentationGradientStop(position: 1, color: stops.single.color),
    );
  }
  return LinearGradient(
    begin: Alignment(-x, -y),
    end: Alignment(x, y),
    colors: [for (final stop in stops) Color(stop.color)],
    stops: [for (final stop in stops) stop.position],
  );
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

enum _PresentationBlankMode { none, black, white }

enum _PresentationMenuAction { toggleSlideNumber, blackScreen, whiteScreen }

class _PresentationModePageState extends State<_PresentationModePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _controlsHideDelay = Duration(seconds: 3);
  static const Duration _controlsFadeDuration = Duration(milliseconds: 180);
  static const MethodChannel _presentationModeChannel = MethodChannel(
    'edusheet/presentation_mode',
  );

  late int _index;
  late final AnimationController _objectAnimationController;
  late PresentationAnimationTimeline _animationTimeline;
  final FocusNode _focusNode = FocusNode(debugLabel: 'presentation-mode');
  Timer? _controlsHideTimer;
  bool _showControls = true;
  bool _showSlideNumber = true;
  int _completedAnimationGroups = 0;
  int? _activeAnimationGroupIndex;
  _PresentationBlankMode _blankMode = _PresentationBlankMode.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _index = widget.initialIndex
        .clamp(0, widget.presentation.slides.length - 1)
        .toInt();
    _objectAnimationController = AnimationController(vsync: this)
      ..addStatusListener(_handleAnimationStatus);
    _animationTimeline = PresentationAnimationTimeline.compile(
      widget.presentation.slides[_index].animations,
    );
    unawaited(_enterPresentationSystemUi());
    _scheduleAutomaticAnimationIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleControlsHide();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_enterPresentationSystemUi());
      _revealControls();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsHideTimer?.cancel();
    _objectAnimationController
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    _focusNode.dispose();
    unawaited(_restoreApplicationSystemUi());
    super.dispose();
  }

  Future<void> _enterPresentationSystemUi() async {
    if (!Platform.isAndroid && !Platform.isWindows) return;
    try {
      await _presentationModeChannel.invokeMethod<void>('enterImmersive');
    } on Object {
      // Presentation remains functional even if the host platform declines
      // immersive system UI (for example an unusual Android window mode).
    }
  }

  Future<void> _restoreApplicationSystemUi() async {
    if (!Platform.isAndroid && !Platform.isWindows) return;
    try {
      await _presentationModeChannel.invokeMethod<void>('exitImmersive');
    } on Object {
      // Do not let platform UI restoration interfere with route disposal.
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.presentation.slides[_index];
    final canAdvance =
        _blankMode != _PresentationBlankMode.none ||
        _completedAnimationGroups < _animationTimeline.groups.length ||
        _activeAnimationGroupIndex != null ||
        _index < widget.presentation.slides.length - 1;
    final canRetreat =
        _blankMode != _PresentationBlankMode.none ||
        _completedAnimationGroups > 0 ||
        _activeAnimationGroupIndex != null ||
        _index > 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: _handleKey,
        child: MouseRegion(
          onEnter: (_) => _revealControls(),
          onHover: (_) => _revealControls(),
          child: GestureDetector(
            key: const Key('presentation-mode-stage'),
            behavior: HitTestBehavior.opaque,
            onTap: _advance,
            onLongPress: _toggleControls,
            onSecondaryTap: _retreat,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -250) _advance();
              if (velocity > 250) _retreat();
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final metrics = PresentationStagePolicy.contain(
                        viewport: Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        ),
                        aspectRatio: widget.presentation.aspectRatio,
                      );
                      return Center(
                        child: AnimatedSwitcher(
                          duration: slide.transition.duration,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              _buildSlideTransition(
                                slide.transition,
                                child,
                                animation,
                              ),
                          child: _PptxSlideCanvas(
                            key: ValueKey('present-${slide.number}'),
                            slide: slide,
                            width: metrics.slideSize.width,
                            height: metrics.slideSize.height,
                            animationTimeline: _animationTimeline,
                            completedAnimationGroups:
                                _completedAnimationGroups,
                            activeAnimationGroupIndex:
                                _activeAnimationGroupIndex,
                            activeAnimationProgress:
                                _objectAnimationController,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_blankMode != _PresentationBlankMode.none)
                  Positioned.fill(
                    child: ColoredBox(
                      key: const Key('presentation-blank-screen'),
                      color: _blankMode == _PresentationBlankMode.black
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _PresentationControlsVisibility(
                    visible: _showControls,
                    duration: _controlsFadeDuration,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: _buildTopControls(context),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _PresentationControlsVisibility(
                    visible: _showControls,
                    duration: _controlsFadeDuration,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: _buildBottomControls(
                          canAdvance: canAdvance,
                          canRetreat: canRetreat,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final veryCompact = constraints.maxWidth < 360;
        return DecoratedBox(
          key: const Key('presentation-mode-controls'),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Exit presentation',
                  onPressed: _exitPresentation,
                  color: Colors.white,
                  icon: const Icon(Icons.close),
                ),
                if (!compact) ...[
                  const SizedBox(width: 4),
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
                ] else
                  const Spacer(),
                if (!compact && _animationTimeline.groups.isNotEmpty) ...[
                  _AnimationProgressBadge(
                    completed: _completedAnimationGroups,
                    total: _animationTimeline.groups.length,
                    active: _activeAnimationGroupIndex != null,
                  ),
                  const SizedBox(width: 8),
                ],
                if (_showSlideNumber)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: veryCompact ? 2 : 6,
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.presentation.slides.length}',
                      key: const Key('presentation-slide-number'),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: veryCompact ? 12 : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Slide overview',
                  onPressed: _showSlideOverview,
                  color: Colors.white,
                  icon: const Icon(Icons.grid_view_rounded),
                ),
                PopupMenuButton<_PresentationMenuAction>(
                  tooltip: 'Presentation options',
                  color: const Color(0xFF202124),
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onOpened: _pauseControlsHide,
                  onCanceled: _scheduleControlsHide,
                  onSelected: _handleMenuAction,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _PresentationMenuAction.toggleSlideNumber,
                      child: _PresentationMenuItem(
                        icon: _showSlideNumber
                            ? Icons.numbers
                            : Icons.numbers_outlined,
                        label: _showSlideNumber
                            ? 'Hide slide number'
                            : 'Show slide number',
                      ),
                    ),
                    const PopupMenuItem(
                      value: _PresentationMenuAction.blackScreen,
                      child: _PresentationMenuItem(
                        icon: Icons.stop_screen_share_outlined,
                        label: 'Black screen (B)',
                      ),
                    ),
                    const PopupMenuItem(
                      value: _PresentationMenuAction.whiteScreen,
                      child: _PresentationMenuItem(
                        icon: Icons.crop_square,
                        label: 'White screen (W)',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls({
    required bool canAdvance,
    required bool canRetreat,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Presentation chrome must adapt to the space it is actually allocated,
        // not the outer window MediaQuery. This matters for Android free-form,
        // split panes, resizable Windows windows and widget tests.
        final showKeyboardHelp = constraints.maxWidth >= 720;
        final navigation = _PresentationNavigationControls(
          canAdvance: canAdvance,
          canRetreat: canRetreat,
          onAdvance: _advance,
          onRetreat: _retreat,
          nextTooltip: _completedAnimationGroups <
                  _animationTimeline.groups.length
              ? 'Next animation'
              : 'Next slide',
        );

        if (!showKeyboardHelp) {
          return Align(alignment: Alignment.centerRight, child: navigation);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.52),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text(
                    'Space / → next   •   ← previous   •   B black   •   W white   •   Esc exit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            navigation,
          ],
        );
      },
    );
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed ||
        _activeAnimationGroupIndex == null ||
        !mounted) {
      return;
    }
    final finishedGroup = _activeAnimationGroupIndex!;
    setState(() {
      _completedAnimationGroups = math.max(
        _completedAnimationGroups,
        finishedGroup + 1,
      ).toInt();
      _activeAnimationGroupIndex = null;
    });
    _scheduleAutomaticAnimationIfNeeded();
  }

  void _scheduleAutomaticAnimationIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeAnimationGroupIndex != null) return;
      if (_completedAnimationGroups >= _animationTimeline.groups.length) return;
      final next = _animationTimeline.groups[_completedAnimationGroups];
      if (!next.requiresClick) _startAnimationGroup(next.index);
    });
  }

  void _startAnimationGroup(int index) {
    if (!mounted ||
        index < 0 ||
        index >= _animationTimeline.groups.length ||
        _activeAnimationGroupIndex != null) {
      return;
    }
    final group = _animationTimeline.groups[index];
    _objectAnimationController
      ..stop()
      ..duration = group.duration;
    setState(() => _activeAnimationGroupIndex = index);
    _objectAnimationController.forward(from: 0);
  }

  void _advance() {
    _scheduleControlsHide();
    if (_blankMode != _PresentationBlankMode.none) {
      setState(() => _blankMode = _PresentationBlankMode.none);
      return;
    }
    final active = _activeAnimationGroupIndex;
    if (active != null) {
      _objectAnimationController.value = 1;
      return;
    }
    if (_completedAnimationGroups < _animationTimeline.groups.length) {
      _startAnimationGroup(_completedAnimationGroups);
      return;
    }
    if (_index < widget.presentation.slides.length - 1) {
      _goToSlide(_index + 1);
    }
  }

  void _retreat() {
    _scheduleControlsHide();
    if (_blankMode != _PresentationBlankMode.none) {
      setState(() => _blankMode = _PresentationBlankMode.none);
      return;
    }
    final active = _activeAnimationGroupIndex;
    if (active != null) {
      _objectAnimationController.stop();
      _objectAnimationController.value = 0;
      setState(() {
        _activeAnimationGroupIndex = null;
        _completedAnimationGroups = active;
      });
      return;
    }
    if (_completedAnimationGroups > 0) {
      setState(() => _completedAnimationGroups--);
      return;
    }
    if (_index > 0) {
      _goToSlide(_index - 1, showFinalAnimations: true);
    }
  }

  void _goToSlide(int index, {bool showFinalAnimations = false}) {
    if (index < 0 || index >= widget.presentation.slides.length) return;
    _objectAnimationController
      ..stop()
      ..value = 0;
    final timeline = PresentationAnimationTimeline.compile(
      widget.presentation.slides[index].animations,
    );
    setState(() {
      _index = index;
      _animationTimeline = timeline;
      _activeAnimationGroupIndex = null;
      _completedAnimationGroups = showFinalAnimations
          ? timeline.groups.length
          : 0;
      _blankMode = _PresentationBlankMode.none;
    });
    if (!showFinalAnimations) _scheduleAutomaticAnimationIfNeeded();
    _scheduleControlsHide();
  }

  void _exitPresentation() {
    _controlsHideTimer?.cancel();
    Navigator.of(context).pop(_index);
  }

  void _toggleControls() {
    _controlsHideTimer?.cancel();
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleControlsHide();
  }

  void _revealControls() {
    if (!mounted) return;
    if (!_showControls) setState(() => _showControls = true);
    _scheduleControlsHide();
  }

  void _pauseControlsHide() => _controlsHideTimer?.cancel();

  void _scheduleControlsHide() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(_controlsHideDelay, () {
      if (mounted && _showControls) setState(() => _showControls = false);
    });
  }

  void _handleMenuAction(_PresentationMenuAction action) {
    switch (action) {
      case _PresentationMenuAction.toggleSlideNumber:
        setState(() => _showSlideNumber = !_showSlideNumber);
        _revealControls();
        break;
      case _PresentationMenuAction.blackScreen:
        _setBlankMode(_PresentationBlankMode.black);
        break;
      case _PresentationMenuAction.whiteScreen:
        _setBlankMode(_PresentationBlankMode.white);
        break;
    }
  }

  void _setBlankMode(_PresentationBlankMode mode) {
    setState(() {
      _blankMode = _blankMode == mode ? _PresentationBlankMode.none : mode;
    });
    _scheduleControlsHide();
  }

  Future<void> _showSlideOverview() async {
    _pauseControlsHide();
    final selected = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151515),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.76,
        child: _PresentationSlideOverview(
          presentation: widget.presentation,
          selectedIndex: _index,
        ),
      ),
    );
    if (!mounted) return;
    if (selected != null) _goToSlide(selected);
    _focusNode.requestFocus();
    _revealControls();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _exitPresentation();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.pageDown ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.keyN) {
      _advance();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.pageUp ||
        event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.keyP) {
      _retreat();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      _goToSlide(0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      _goToSlide(
        widget.presentation.slides.length - 1,
        showFinalAnimations: true,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyB) {
      _setBlankMode(_PresentationBlankMode.black);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyW) {
      _setBlankMode(_PresentationBlankMode.white);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyG) {
      unawaited(_showSlideOverview());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

class _PresentationNavigationControls extends StatelessWidget {
  final bool canAdvance;
  final bool canRetreat;
  final VoidCallback onAdvance;
  final VoidCallback onRetreat;
  final String nextTooltip;

  const _PresentationNavigationControls({
    required this.canAdvance,
    required this.canRetreat,
    required this.onAdvance,
    required this.onRetreat,
    required this.nextTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Previous animation or slide',
              onPressed: canRetreat ? onRetreat : null,
              color: Colors.white,
              disabledColor: Colors.white30,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: nextTooltip,
              onPressed: canAdvance ? onAdvance : null,
              color: Colors.white,
              disabledColor: Colors.white30,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresentationControlsVisibility extends StatelessWidget {
  final bool visible;
  final Duration duration;
  final Widget child;

  const _PresentationControlsVisibility({
    required this.visible,
    required this.duration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -0.06),
          duration: duration,
          curve: Curves.easeOut,
          child: child,
        ),
      ),
    );
  }
}

class _PresentationMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PresentationMenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

class _PresentationSlideOverview extends StatelessWidget {
  final PresentationDocument presentation;
  final int selectedIndex;

  const _PresentationSlideOverview({
    required this.presentation,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('presentation-slide-overview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Jump to slide',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close overview',
                onPressed: () => Navigator.of(context).pop(),
                color: Colors.white,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 5
                  : constraints.maxWidth >= 700
                  ? 4
                  : constraints.maxWidth >= 480
                  ? 3
                  : 2;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: presentation.aspectRatio * 0.82,
                ),
                itemCount: presentation.slides.length,
                itemBuilder: (context, index) {
                  final selected = index == selectedIndex;
                  return InkWell(
                    key: ValueKey('presentation-overview-slide-$index'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).pop(index),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF242424),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white24,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, slideConstraints) {
                                  final metrics = PresentationStagePolicy.contain(
                                    viewport: Size(
                                      slideConstraints.maxWidth,
                                      slideConstraints.maxHeight,
                                    ),
                                    aspectRatio: presentation.aspectRatio,
                                  );
                                  return Center(
                                    child: IgnorePointer(
                                      child: _PptxSlideCanvas(
                                        slide: presentation.slides[index],
                                        width: metrics.slideSize.width,
                                        height: metrics.slideSize.height,
                                        compact: true,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                                fontSize: 11,
                                fontWeight:
                                    selected ? FontWeight.w800 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AnimationProgressBadge extends StatelessWidget {
  final int completed;
  final int total;
  final bool active;

  const _AnimationProgressBadge({
    required this.completed,
    required this.total,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final current = active
        ? math.min(total, completed + 1).toInt()
        : math.min(total, completed).toInt();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          'Animation $current/$total',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _NativeAnimationNotice extends StatelessWidget {
  final PresentationDocument presentation;

  const _NativeAnimationNotice({required this.presentation});

  @override
  Widget build(BuildContext context) {
    var supported = 0;
    var unsupported = 0;
    for (final slide in presentation.slides) {
      supported += slide.animations.where((step) => step.supported).length;
      unsupported += slide.animations.where((step) => !step.supported).length;
    }
    final colorScheme = Theme.of(context).colorScheme;
    final text = supported > 0
        ? unsupported > 0
            ? 'PowerPoint animations enabled: $supported supported effects will play in Present mode; $unsupported advanced Office effects use a safe final-state fallback.'
            : 'PowerPoint animations enabled: $supported supported object effects will play in Present mode.'
        : 'This deck contains PowerPoint timing metadata. No supported object effects were found, so EduSheet keeps slide content visible instead of guessing unsupported Office animations.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: colorScheme.primary.withValues(alpha: 0.08),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
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
                isCloudUnavailable
                    ? Icons.cloud_off_outlined
                    : Icons.error_outline,
                size: 54,
                color: isCloudUnavailable
                    ? Colors.orangeAccent
                    : Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
