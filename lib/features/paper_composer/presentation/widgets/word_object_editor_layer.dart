import 'package:edusheet/features/paper_composer/application/word_object_manipulation_service.dart';
import 'package:edusheet/features/paper_composer/application/word_pagination_service.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/word_shape_preview.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive floating-object layer for Word Mode.
///
/// The child remains the normal document-flow surface. Shapes/text boxes are a
/// separate overlay, so free positioning never turns editor selection chrome
/// into printable content. Selection is deliberately transient in this widget.
class WordObjectEditorLayer extends StatefulWidget {
  final List<WordShapeObject> shapes;
  final Widget child;
  final ValueChanged<List<WordShapeObject>> onShapesChanged;
  final bool compact;

  /// Input modality is intentionally separate from responsive layout.
  ///
  /// A narrow Windows window can use the compact visual layout while keeping
  /// desktop mouse/keyboard semantics. Direct widget tests keep the legacy
  /// `!compact` default unless an explicit modality is supplied.
  final bool? desktopInteractions;
  final int ownerPageIndex;
  final Future<void> Function(WordShapeObject shape)? onEditGeometry;

  const WordObjectEditorLayer({
    super.key,
    required this.shapes,
    required this.child,
    required this.onShapesChanged,
    required this.compact,
    this.desktopInteractions,
    this.ownerPageIndex = 0,
    this.onEditGeometry,
  });

  @override
  State<WordObjectEditorLayer> createState() => _WordObjectEditorLayerState();
}

class _WordObjectEditorLayerState extends State<WordObjectEditorLayer> {
  late final FocusNode _focusNode;
  final Set<String> _selectedIds = <String>{};
  String? _hoveredId;
  double? _verticalGuide;
  double? _horizontalGuide;
  List<WordShapeObject> _clipboard = const [];
  String? _desktopPointerObjectId;
  Offset? _desktopPointerDownPosition;
  bool _desktopPointerMoved = false;
  String? _lastDesktopClickObjectId;
  Duration? _lastDesktopClickTime;
  Offset? _lastDesktopClickPosition;

  static const Duration _desktopDoubleClickWindow = Duration(
    milliseconds: 500,
  );
  static const double _desktopClickMovementTolerance = 6.0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'WordObjectEditorLayer');
  }

  @override
  void didUpdateWidget(covariant WordObjectEditorLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final liveIds = widget.shapes.map((item) => item.id).toSet();
    _selectedIds.removeWhere((id) => !liveIds.contains(id));
    if (_hoveredId != null && !liveIds.contains(_hoveredId)) {
      _hoveredId = null;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  List<WordShapeObject> get _selectedShapes => widget.shapes
      .where((item) => _selectedIds.contains(item.id))
      .toList(growable: false);

  WordShapeObject? get _singleSelected =>
      _selectedIds.length == 1 ? _selectedShapes.firstOrNull : null;

  bool get _usesDesktopInteractions =>
      widget.desktopInteractions ?? !widget.compact;

  @override
  Widget build(BuildContext context) {
    if (widget.shapes.isEmpty) return widget.child;
    final minHeight = widget.compact ? 210.0 : 250.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          focusNode: _focusNode,
          onKeyEvent: _onKeyEvent,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: widget.child,
                ),
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final height = constraints.maxHeight;
                      final ordered = [...widget.shapes]
                        ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
                      return Stack(
                        key: const Key('word-object-editor-layer'),
                        clipBehavior: Clip.none,
                        children: [
                          if (_verticalGuide != null)
                            Positioned(
                              left: (_verticalGuide! * width)
                                  .clamp(0.0, width)
                                  .toDouble(),
                              top: 0,
                              bottom: 0,
                              child: IgnorePointer(
                                child: Container(
                                  key: const Key('word-object-vertical-guide'),
                                  width: 1,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.72),
                                ),
                              ),
                            ),
                          if (_horizontalGuide != null)
                            Positioned(
                              top: (_horizontalGuide! * height)
                                  .clamp(0.0, height)
                                  .toDouble(),
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: Container(
                                  key: const Key('word-object-horizontal-guide'),
                                  height: 1,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.72),
                                ),
                              ),
                            ),
                          for (final shape in ordered)
                            _buildShape(context, shape, width, height),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_selectedIds.isNotEmpty) ...[
          const SizedBox(height: 6),
          _buildSelectionToolbar(context),
        ],
      ],
    );
  }

  Widget _buildShape(
    BuildContext context,
    WordShapeObject shape,
    double canvasWidth,
    double canvasHeight,
  ) {
    final selected = _selectedIds.contains(shape.id);
    final hovered = _hoveredId == shape.id;
    final touchInteractions = !_usesDesktopInteractions;
    final width = (shape.width * canvasWidth)
        .clamp(touchInteractions ? 48.0 : 34.0, canvasWidth)
        .toDouble();
    final height = (shape.height * canvasHeight)
        .clamp(touchInteractions ? 48.0 : 24.0, canvasHeight)
        .toDouble();
    // Keep stored coordinates visible as authored. Legacy/imported objects
    // that exceed printable bounds are warned instead of silently clamped.
    final left = shape.x * canvasWidth;
    final top = shape.y * canvasHeight;
    final theme = Theme.of(context);
    final editGeometry = widget.onEditGeometry;
    final handleSize = touchInteractions ? 40.0 : 22.0;

    return Positioned(
      key: ValueKey('word-object-${shape.id}'),
      left: left,
      top: top,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: _usesDesktopInteractions && !shape.locked
            ? SystemMouseCursors.move
            : SystemMouseCursors.basic,
        onEnter: _usesDesktopInteractions
            ? (_) => setState(() => _hoveredId = shape.id)
            : null,
        onExit: _usesDesktopInteractions
            ? (_) {
                if (_hoveredId == shape.id) {
                  setState(() => _hoveredId = null);
                }
              }
            : null,
        child: Semantics(
          container: true,
          selected: selected,
          label: '${shape.kind.label}${shape.locked ? ', locked' : ''}',
          child: Listener(
            behavior: HitTestBehavior.translucent,
        // Desktop selection stays outside the gesture arena so floating text
        // boxes and geometry select immediately. Double-click editing is also
        // tracked here without Flutter's DoubleTapGestureRecognizer, avoiding
        // delayed selection and pending timer state in deterministic tests.
        onPointerDown: _usesDesktopInteractions
            ? (event) => _handleDesktopPointerDown(shape, event)
            : null,
        onPointerMove: _usesDesktopInteractions
            ? (event) => _handleDesktopPointerMove(shape, event)
            : null,
        onPointerUp: _usesDesktopInteractions
            ? (event) => _handleDesktopPointerUp(
                  context,
                  shape,
                  event,
                  editGeometry,
                )
            : null,
        onPointerCancel: _usesDesktopInteractions
            ? (_) => _resetDesktopPointerTracking()
            : null,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          // Compact/mobile mode uses tap-to-select and the toolbar Edit action,
          // leaving long-press free for multi-selection.
          onTap: _usesDesktopInteractions
              ? null
              : () => _select(shape.id, additive: false),
          onLongPress: _usesDesktopInteractions
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  _addToSelection(shape.id);
                },
          onPanStart: shape.locked
              ? null
              : (_) {
                  _focusNode.requestFocus();
                  if (!_selectedIds.contains(shape.id)) {
                    _select(shape.id, additive: false);
                  }
                },
          onPanUpdate: shape.locked
              ? null
              : (details) {
                  final current = widget.shapes
                      .where((item) => item.id == shape.id)
                      .firstOrNull;
                  if (current == null) return;
                  if (_selectedIds.length > 1) {
                    widget.onShapesChanged(
                      WordObjectManipulationService.moveSelection(
                        widget.shapes,
                        _selectedIds,
                        deltaX: details.delta.dx / canvasWidth,
                        deltaY: details.delta.dy / canvasHeight,
                      ),
                    );
                    _clearGuides();
                    return;
                  }
                  final siblings = widget.shapes.where(
                    (item) => item.id != current.id,
                  );
                  final result = WordObjectManipulationService.moveWithSnap(
                    current,
                    deltaX: details.delta.dx / canvasWidth,
                    deltaY: details.delta.dy / canvasHeight,
                    siblings: siblings,
                  );
                  _replaceSingle(result.object);
                  if (mounted) {
                    setState(() {
                      _verticalGuide = result.verticalGuide;
                      _horizontalGuide = result.horizontalGuide;
                    });
                  }
                },
          onPanEnd: shape.locked ? null : (_) => _clearGuides(),
          onPanCancel: shape.locked ? null : _clearGuides,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: selected
                        ? Border.all(
                            color: shape.locked
                                ? theme.colorScheme.tertiary
                                : theme.colorScheme.primary,
                            width: 1.5,
                          )
                        : hovered && _usesDesktopInteractions
                        ? Border.all(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.35),
                            width: 1,
                          )
                        : null,
                  ),
                  child: WordShapeVisual(shape: shape),
                ),
              ),
              if (selected && shape.locked)
                Positioned(
                  top: touchInteractions ? 4 : -10,
                  right: touchInteractions ? 4 : -10,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.tertiary),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          Icons.lock_rounded,
                          key: ValueKey(
                            'word-object-lock-indicator-${shape.id}',
                          ),
                          size: touchInteractions ? 16 : 13,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              if (selected && !shape.locked)
                Positioned(
                  right: touchInteractions ? 2 : -handleSize / 2,
                  bottom: touchInteractions ? 2 : -handleSize / 2,
                  width: handleSize,
                  height: handleSize,
                  child: GestureDetector(
                    key: ValueKey('word-object-resize-${shape.id}'),
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => _focusNode.requestFocus(),
                    onPanUpdate: (details) {
                      final current = widget.shapes
                          .where((item) => item.id == shape.id)
                          .firstOrNull;
                      if (current == null) return;
                      _replaceSingle(
                        WordObjectManipulationService.resizeBottomRight(
                          current,
                          deltaWidth: details.delta.dx / canvasWidth,
                          deltaHeight: details.delta.dy / canvasHeight,
                        ),
                      );
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.primary),
                      ),
                      child: Icon(
                        Icons.open_in_full_rounded,
                        size: touchInteractions ? 18 : 13,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildSelectionToolbar(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selectedShapes;
    final single = _singleSelected;
    final textObject = single?.isTextContainer == true ? single : null;
    final geometryObject = single?.isGeometryObject == true ? single : null;
    final editGeometry = widget.onEditGeometry;
    final fixedObject = single?.isFixedOnPage == true ? single : null;
    final pageMismatch =
        fixedObject != null && fixedObject.fixedPageIndex != widget.ownerPageIndex;
    final allLocked = selected.isNotEmpty && selected.every((item) => item.locked);
    final hasOverflow = selected.any((item) => item.exceedsNormalizedBounds);

    if (widget.compact) {
      return _buildCompactSelectionToolbar(
        context,
        selected: selected,
        single: single,
        textObject: textObject,
        geometryObject: geometryObject,
        allLocked: allLocked,
        hasOverflow: hasOverflow,
        pageMismatch: pageMismatch,
      );
    }

    return Material(
      key: const Key('word-object-selection-toolbar'),
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Wrap(
          spacing: 2,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.select_all_rounded, size: 16),
              label: Text(
                selected.length == 1 ? single!.kind.label : '${selected.length} objects',
              ),
            ),
            if (single != null)
              PopupMenuButton<WordTextWrapMode>(
                key: ValueKey('word-object-wrap-${single.id}'),
                tooltip: 'Text wrapping',
                onSelected: (mode) {
                  var updated = single.copyWith(wrapMode: mode);
                  if (mode == WordTextWrapMode.squareLeft) {
                    updated = updated.copyWith(x: 0.02);
                  } else if (mode == WordTextWrapMode.squareRight) {
                    updated = updated.copyWith(
                      x: (0.98 - updated.width).clamp(0.0, 0.92).toDouble(),
                    );
                  }
                  _replaceSingle(updated);
                },
                itemBuilder: (context) => [
                  for (final mode in WordTextWrapMode.values)
                    PopupMenuItem(value: mode, child: Text(mode.label)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wrap_text_rounded, size: 17),
                      const SizedBox(width: 4),
                      Text(single.wrapMode.label),
                    ],
                  ),
                ),
              ),
            if (single != null)
              PopupMenuButton<WordObjectAnchorMode>(
                key: ValueKey('word-object-anchor-${single.id}'),
                tooltip: 'Object anchoring',
                onSelected: (mode) => _replaceSingle(
                  WordPaginationService.setAnchorMode(
                    single,
                    mode,
                    ownerPageIndex: widget.ownerPageIndex,
                  ),
                ),
                itemBuilder: (context) => [
                  for (final mode in WordObjectAnchorMode.values)
                    PopupMenuItem(value: mode, child: Text(mode.label)),
                ],
                icon: Icon(
                  single.isFixedOnPage
                      ? Icons.push_pin_rounded
                      : Icons.anchor_rounded,
                  size: 19,
                ),
              ),
            if (fixedObject != null)
              Chip(
                key: ValueKey('word-object-fixed-page-${fixedObject.id}'),
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  pageMismatch
                      ? Icons.warning_amber_rounded
                      : Icons.description_outlined,
                  size: 15,
                  color: pageMismatch ? theme.colorScheme.error : null,
                ),
                label: Text('Page ${fixedObject.fixedPageIndex + 1}'),
              ),
            if (pageMismatch) ...[
              const Chip(
                key: Key('word-object-page-mismatch'),
                visualDensity: VisualDensity.compact,
                label: Text('Pinned page differs'),
              ),
              IconButton(
                key: const Key('word-object-repin-page'),
                tooltip: 'Re-pin to this question page',
                visualDensity: VisualDensity.compact,
                onPressed: fixedObject.locked
                    ? null
                    : () => _replaceSingle(
                        WordPaginationService.setAnchorMode(
                          fixedObject,
                          WordObjectAnchorMode.fixedOnPage,
                          ownerPageIndex: widget.ownerPageIndex,
                        ),
                      ),
                icon: const Icon(Icons.pin_drop_rounded, size: 19),
              ),
            ],
            if (geometryObject != null && editGeometry != null)
              IconButton(
                key: ValueKey('word-object-edit-geometry-${geometryObject.id}'),
                tooltip: 'Edit geometry',
                visualDensity: VisualDensity.compact,
                onPressed: geometryObject.locked
                    ? null
                    : () => editGeometry(geometryObject),
                icon: const Icon(Icons.architecture_rounded, size: 19),
              ),
            if (textObject != null)
              IconButton(
                key: ValueKey('word-object-edit-text-${textObject.id}'),
                tooltip: 'Edit text',
                visualDensity: VisualDensity.compact,
                onPressed: () => _editText(context, textObject),
                icon: const Icon(Icons.edit_note_rounded, size: 19),
              ),
            if (textObject != null)
              PopupMenuButton<WordTextBoxSizing>(
                key: ValueKey('word-object-text-sizing-${textObject.id}'),
                tooltip: 'Text box sizing',
                onSelected: (sizing) => _replaceSingle(
                  WordObjectManipulationService.setTextBoxSizing(
                    textObject,
                    sizing,
                  ),
                ),
                itemBuilder: (context) => [
                  for (final sizing in WordTextBoxSizing.values)
                    PopupMenuItem(value: sizing, child: Text(sizing.label)),
                ],
                icon: const Icon(Icons.fit_screen_rounded, size: 19),
              ),
            if (textObject != null)
              IconButton(
                key: ValueKey('word-object-border-${textObject.id}'),
                tooltip: textObject.borderVisible
                    ? 'Hide border'
                    : 'Show border',
                visualDensity: VisualDensity.compact,
                onPressed: () => _replaceSingle(
                  textObject.copyWith(borderVisible: !textObject.borderVisible),
                ),
                icon: Icon(
                  textObject.borderVisible
                      ? Icons.border_outer_rounded
                      : Icons.border_clear_rounded,
                  size: 19,
                ),
              ),
            if (textObject != null)
              IconButton(
                key: ValueKey('word-object-fill-${textObject.id}'),
                tooltip: textObject.fillOpacity > 0
                    ? 'Transparent fill'
                    : 'White fill',
                visualDensity: VisualDensity.compact,
                onPressed: () => _replaceSingle(
                  textObject.copyWith(
                    fillOpacity: textObject.fillOpacity > 0 ? 0 : 1,
                  ),
                ),
                icon: Icon(
                  textObject.fillOpacity > 0
                      ? Icons.format_color_reset_rounded
                      : Icons.format_color_fill_rounded,
                  size: 19,
                ),
              ),
            if (textObject != null)
              IconButton(
                key: ValueKey('word-object-padding-less-${textObject.id}'),
                tooltip: 'Less text padding',
                visualDensity: VisualDensity.compact,
                onPressed: textObject.padding <= 0
                    ? null
                    : () => _replaceSingle(
                        textObject.copyWith(padding: textObject.padding - 2),
                      ),
                icon: const Icon(Icons.compress_rounded, size: 18),
              ),
            if (textObject != null)
              IconButton(
                key: ValueKey('word-object-padding-more-${textObject.id}'),
                tooltip: 'More text padding',
                visualDensity: VisualDensity.compact,
                onPressed: textObject.padding >= 32
                    ? null
                    : () => _replaceSingle(
                        textObject.copyWith(padding: textObject.padding + 2),
                      ),
                icon: const Icon(Icons.expand_rounded, size: 18),
              ),
            if (single != null)
              IconButton(
                key: ValueKey('word-object-aspect-${single.id}'),
                tooltip: single.aspectRatioLocked
                    ? 'Unlock aspect ratio'
                    : 'Lock aspect ratio',
                visualDensity: VisualDensity.compact,
                onPressed: single.locked
                    ? null
                    : () => _replaceSingle(
                        single.copyWith(
                          aspectRatioLocked: !single.aspectRatioLocked,
                        ),
                      ),
                icon: Icon(
                  single.aspectRatioLocked
                      ? Icons.link_rounded
                      : Icons.link_off_rounded,
                  size: 19,
                ),
              ),
            if (selected.length >= 2)
              PopupMenuButton<WordObjectAlignment>(
                key: const Key('word-object-align-menu'),
                tooltip: 'Align selected objects',
                onSelected: (alignment) => widget.onShapesChanged(
                  WordObjectManipulationService.align(
                    widget.shapes,
                    _selectedIds,
                    alignment,
                  ),
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: WordObjectAlignment.left, child: Text('Align left')),
                  PopupMenuItem(value: WordObjectAlignment.horizontalCenter, child: Text('Align center')),
                  PopupMenuItem(value: WordObjectAlignment.right, child: Text('Align right')),
                  PopupMenuItem(value: WordObjectAlignment.top, child: Text('Align top')),
                  PopupMenuItem(value: WordObjectAlignment.verticalCenter, child: Text('Align middle')),
                  PopupMenuItem(value: WordObjectAlignment.bottom, child: Text('Align bottom')),
                ],
                icon: const Icon(Icons.align_horizontal_left_rounded, size: 19),
              ),
            if (selected.length >= 3)
              PopupMenuButton<WordObjectDistribution>(
                key: const Key('word-object-distribute-menu'),
                tooltip: 'Distribute selected objects',
                onSelected: (distribution) => widget.onShapesChanged(
                  WordObjectManipulationService.distribute(
                    widget.shapes,
                    _selectedIds,
                    distribution,
                  ),
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: WordObjectDistribution.horizontal,
                    child: Text('Distribute horizontally'),
                  ),
                  PopupMenuItem(
                    value: WordObjectDistribution.vertical,
                    child: Text('Distribute vertically'),
                  ),
                ],
                icon: const Icon(Icons.space_bar_rounded, size: 19),
              ),
            if (hasOverflow) ...[
              Chip(
                key: const Key('word-object-overflow-warning'),
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                label: const Text('Outside printable area'),
              ),
              IconButton(
                key: const Key('word-object-fit-inside'),
                tooltip: 'Fit selected objects inside printable area',
                visualDensity: VisualDensity.compact,
                onPressed: allLocked
                    ? null
                    : () => widget.onShapesChanged([
                        for (final item in widget.shapes)
                          if (_selectedIds.contains(item.id) && !item.locked)
                            WordPaginationService.fitInsidePrintableBounds(item)
                          else
                            item,
                      ]),
                icon: const Icon(Icons.fit_screen_rounded, size: 18),
              ),
            ],
            IconButton(
              key: const Key('word-object-copy'),
              tooltip: 'Copy (Ctrl+C)',
              visualDensity: VisualDensity.compact,
              onPressed: _copySelection,
              icon: const Icon(Icons.content_copy_rounded, size: 18),
            ),
            IconButton(
              key: const Key('word-object-paste'),
              tooltip: 'Paste (Ctrl+V)',
              visualDensity: VisualDensity.compact,
              onPressed: _clipboard.isEmpty ? null : _pasteClipboard,
              icon: const Icon(Icons.content_paste_rounded, size: 18),
            ),
            IconButton(
              key: const Key('word-object-duplicate'),
              tooltip: 'Duplicate (Ctrl+D)',
              visualDensity: VisualDensity.compact,
              onPressed: _duplicateSelection,
              icon: const Icon(Icons.copy_rounded, size: 18),
            ),
            IconButton(
              key: const Key('word-object-lock'),
              tooltip: allLocked ? 'Unlock (Ctrl+L)' : 'Lock (Ctrl+L)',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                widget.onShapesChanged(
                  WordObjectManipulationService.setLocked(
                    widget.shapes,
                    _selectedIds,
                    !allLocked,
                  ),
                );
              },
              icon: Icon(
                allLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                size: 18,
              ),
            ),
            IconButton(
              key: const Key('word-object-forward-one'),
              tooltip: 'Bring forward',
              visualDensity: VisualDensity.compact,
              onPressed: () => widget.onShapesChanged(
                WordObjectManipulationService.bringForwardOne(
                  widget.shapes,
                  _selectedIds,
                ),
              ),
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
            ),
            IconButton(
              key: const Key('word-object-backward-one'),
              tooltip: 'Send backward',
              visualDensity: VisualDensity.compact,
              onPressed: () => widget.onShapesChanged(
                WordObjectManipulationService.sendBackwardOne(
                  widget.shapes,
                  _selectedIds,
                ),
              ),
              icon: const Icon(Icons.arrow_downward_rounded, size: 18),
            ),
            IconButton(
              key: const Key('word-object-front'),
              tooltip: 'Bring to front',
              visualDensity: VisualDensity.compact,
              onPressed: () => widget.onShapesChanged(
                WordObjectManipulationService.bringToFront(
                  widget.shapes,
                  _selectedIds,
                ),
              ),
              icon: const Icon(Icons.flip_to_front_rounded, size: 18),
            ),
            IconButton(
              key: const Key('word-object-back'),
              tooltip: 'Send to back',
              visualDensity: VisualDensity.compact,
              onPressed: () => widget.onShapesChanged(
                WordObjectManipulationService.sendToBack(
                  widget.shapes,
                  _selectedIds,
                ),
              ),
              icon: const Icon(Icons.flip_to_back_rounded, size: 18),
            ),
            IconButton(
              key: const Key('word-object-delete'),
              tooltip: selected.any((item) => item.locked)
                  ? 'Delete unlocked selected objects'
                  : 'Delete',
              visualDensity: VisualDensity.compact,
              onPressed: _deleteSelection,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
            ),
            IconButton(
              key: const Key('word-object-clear-selection'),
              tooltip: 'Clear selection (Esc)',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(_selectedIds.clear),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSelectionToolbar(
    BuildContext context, {
    required List<WordShapeObject> selected,
    required WordShapeObject? single,
    required WordShapeObject? textObject,
    required WordShapeObject? geometryObject,
    required bool allLocked,
    required bool hasOverflow,
    required bool pageMismatch,
  }) {
    final theme = Theme.of(context);
    final editGeometry = widget.onEditGeometry;

    return Material(
      key: const Key('word-object-selection-toolbar'),
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Row(
            key: const Key('word-object-mobile-action-bar'),
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Icon(
                        selected.length > 1
                            ? Icons.select_all_rounded
                            : (single?.locked == true
                                  ? Icons.lock_rounded
                                  : Icons.touch_app_rounded),
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          selected.length == 1
                              ? (single?.kind.label ?? 'Object')
                              : '${selected.length} objects',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (hasOverflow || pageMismatch) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (textObject != null)
                _touchIconButton(
                  key: ValueKey('word-object-edit-text-${textObject.id}'),
                  tooltip: 'Edit text',
                  icon: Icons.edit_note_rounded,
                  onPressed: () => _editText(context, textObject),
                )
              else if (geometryObject != null && editGeometry != null)
                _touchIconButton(
                  key: ValueKey(
                    'word-object-edit-geometry-${geometryObject.id}',
                  ),
                  tooltip: 'Edit geometry',
                  icon: Icons.architecture_rounded,
                  onPressed: geometryObject.locked
                      ? null
                      : () => editGeometry(geometryObject),
                ),
              _touchIconButton(
                key: const Key('word-object-duplicate'),
                tooltip: 'Duplicate (Ctrl+D)',
                icon: Icons.copy_rounded,
                onPressed: _duplicateSelection,
              ),
              _touchIconButton(
                key: const Key('word-object-lock'),
                tooltip: allLocked ? 'Unlock (Ctrl+L)' : 'Lock (Ctrl+L)',
                icon: allLocked
                    ? Icons.lock_open_rounded
                    : Icons.lock_outline_rounded,
                onPressed: () => widget.onShapesChanged(
                  WordObjectManipulationService.setLocked(
                    widget.shapes,
                    _selectedIds,
                    !allLocked,
                  ),
                ),
              ),
              _touchIconButton(
                key: const Key('word-object-mobile-more'),
                tooltip: 'Object properties',
                icon: Icons.tune_rounded,
                onPressed: () => _showCompactPropertiesSheet(context),
              ),
              _touchIconButton(
                key: const Key('word-object-clear-selection'),
                tooltip: 'Clear selection (Esc)',
                icon: Icons.close_rounded,
                onPressed: () => setState(_selectedIds.clear),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _touchIconButton({
    Key? key,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: const EdgeInsets.all(12),
      icon: Icon(icon, size: 21),
    );
  }

  Future<void> _showCompactPropertiesSheet(BuildContext context) async {
    final selectedSnapshot = _selectedShapes;
    if (selectedSnapshot.isEmpty) return;
    var workingSingle = selectedSnapshot.length == 1
        ? selectedSnapshot.single
        : null;

    await showAdaptiveModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final theme = Theme.of(sheetContext);
          final editGeometry = widget.onEditGeometry;
          final selected = _selectedShapes;
          final currentSingle = workingSingle;
          final textObject = currentSingle?.isTextContainer == true
              ? currentSingle
              : null;
          final geometryObject = currentSingle?.isGeometryObject == true
              ? currentSingle
              : null;
          final fixedObject = currentSingle?.isFixedOnPage == true
              ? currentSingle
              : null;
          final pageMismatch =
              fixedObject != null &&
              fixedObject.fixedPageIndex != widget.ownerPageIndex;
          final allLocked =
              selected.isNotEmpty && selected.every((item) => item.locked);
          final hasOverflow = selected.any((item) => item.exceedsNormalizedBounds);

          void replaceWorking(WordShapeObject value) {
            workingSingle = value;
            _replaceSingle(value);
            setSheetState(() {});
          }

          Widget sectionTitle(String text) => Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              text,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          );

          return FractionallySizedBox(
            heightFactor: 0.84,
            child: SafeArea(
              child: ListView(
                key: const Key('word-object-mobile-properties-sheet'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Text(
                    selected.length == 1
                        ? currentSingle!.kind.label
                        : '${selected.length} selected objects',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selected.length == 1
                        ? 'Position, appearance and page behavior'
                        : 'Arrange and manage the current selection',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (geometryObject != null && editGeometry != null) ...[
                    sectionTitle('Content'),
                    ListTile(
                      key: ValueKey(
                        'word-object-mobile-edit-geometry-${geometryObject.id}',
                      ),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.architecture_rounded),
                      title: const Text('Edit geometry'),
                      subtitle: const Text('Open Geometry Studio'),
                      enabled: !geometryObject.locked,
                      onTap: geometryObject.locked
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              editGeometry(geometryObject);
                            },
                    ),
                  ],
                  if (textObject != null) ...[
                    sectionTitle('Text box'),
                    ListTile(
                      key: ValueKey(
                        'word-object-mobile-edit-text-${textObject.id}',
                      ),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.edit_note_rounded),
                      title: const Text('Edit text'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _editText(context, textObject);
                      },
                    ),
                    DropdownButtonFormField<WordTextBoxSizing>(
                      key: ValueKey(
                        'word-object-mobile-text-sizing-${textObject.id}',
                      ),
                      initialValue: textObject.textBoxSizing,
                      decoration: const InputDecoration(
                        labelText: 'Text box sizing',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final sizing in WordTextBoxSizing.values)
                          DropdownMenuItem(
                            value: sizing,
                            child: Text(sizing.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        replaceWorking(
                          WordObjectManipulationService.setTextBoxSizing(
                            textObject,
                            value,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      key: ValueKey(
                        'word-object-mobile-border-${textObject.id}',
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: textObject.borderVisible,
                      title: const Text('Border'),
                      onChanged: (value) => replaceWorking(
                        textObject.copyWith(borderVisible: value),
                      ),
                    ),
                    SwitchListTile(
                      key: ValueKey('word-object-mobile-fill-${textObject.id}'),
                      contentPadding: EdgeInsets.zero,
                      value: textObject.fillOpacity > 0,
                      title: const Text('White fill'),
                      subtitle: const Text('Off keeps the text box transparent'),
                      onChanged: (value) => replaceWorking(
                        textObject.copyWith(fillOpacity: value ? 1 : 0),
                      ),
                    ),
                    Text(
                      'Text padding: ${textObject.padding.toStringAsFixed(0)} pt',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Slider(
                      key: ValueKey(
                        'word-object-mobile-padding-${textObject.id}',
                      ),
                      value: textObject.padding.clamp(0, 32).toDouble(),
                      min: 0,
                      max: 32,
                      divisions: 16,
                      label: '${textObject.padding.toStringAsFixed(0)} pt',
                      onChanged: (value) => replaceWorking(
                        textObject.copyWith(padding: value),
                      ),
                    ),
                  ],
                  if (currentSingle != null) ...[
                    sectionTitle('Layout'),
                    DropdownButtonFormField<WordTextWrapMode>(
                      key: ValueKey(
                        'word-object-mobile-wrap-${currentSingle.id}',
                      ),
                      initialValue: currentSingle.wrapMode,
                      decoration: const InputDecoration(
                        labelText: 'Text wrapping',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final mode in WordTextWrapMode.values)
                          DropdownMenuItem(
                            value: mode,
                            child: Text(mode.label),
                          ),
                      ],
                      onChanged: (mode) {
                        if (mode == null) return;
                        var updated = currentSingle.copyWith(wrapMode: mode);
                        if (mode == WordTextWrapMode.squareLeft) {
                          updated = updated.copyWith(x: 0.02);
                        } else if (mode == WordTextWrapMode.squareRight) {
                          updated = updated.copyWith(
                            x: (0.98 - updated.width)
                                .clamp(0.0, 0.92)
                                .toDouble(),
                          );
                        }
                        replaceWorking(updated);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<WordObjectAnchorMode>(
                      key: ValueKey(
                        'word-object-mobile-anchor-${currentSingle.id}',
                      ),
                      initialValue: currentSingle.anchorMode,
                      decoration: const InputDecoration(
                        labelText: 'Page behavior',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final mode in WordObjectAnchorMode.values)
                          DropdownMenuItem(
                            value: mode,
                            child: Text(mode.label),
                          ),
                      ],
                      onChanged: currentSingle.locked
                          ? null
                          : (mode) {
                              if (mode == null) return;
                              replaceWorking(
                                WordPaginationService.setAnchorMode(
                                  currentSingle,
                                  mode,
                                  ownerPageIndex: widget.ownerPageIndex,
                                ),
                              );
                            },
                    ),
                    SwitchListTile(
                      key: ValueKey(
                        'word-object-mobile-aspect-${currentSingle.id}',
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: currentSingle.aspectRatioLocked,
                      title: const Text('Lock aspect ratio'),
                      onChanged: currentSingle.locked
                          ? null
                          : (value) => replaceWorking(
                              currentSingle.copyWith(
                                aspectRatioLocked: value,
                              ),
                            ),
                    ),
                    if (fixedObject != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          pageMismatch
                              ? Icons.warning_amber_rounded
                              : Icons.push_pin_rounded,
                          color: pageMismatch
                              ? theme.colorScheme.error
                              : null,
                        ),
                        title: Text(
                          'Pinned to page ${fixedObject.fixedPageIndex + 1}',
                        ),
                        subtitle: pageMismatch
                            ? Text(
                                'The question is now on page ${widget.ownerPageIndex + 1}.',
                              )
                            : const Text('Pinned page matches the question page'),
                        trailing: pageMismatch && !fixedObject.locked
                            ? TextButton(
                                key: const Key(
                                  'word-object-mobile-repin-page',
                                ),
                                onPressed: () => replaceWorking(
                                  WordPaginationService.setAnchorMode(
                                    fixedObject,
                                    WordObjectAnchorMode.fixedOnPage,
                                    ownerPageIndex: widget.ownerPageIndex,
                                  ),
                                ),
                                child: const Text('Re-pin'),
                              )
                            : null,
                      ),
                  ],
                  if (selected.length >= 2) ...[
                    sectionTitle('Arrange selection'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in const <
                          (WordObjectAlignment, String, IconData)
                        >[
                          (
                            WordObjectAlignment.left,
                            'Left',
                            Icons.align_horizontal_left_rounded,
                          ),
                          (
                            WordObjectAlignment.horizontalCenter,
                            'Center',
                            Icons.align_horizontal_center_rounded,
                          ),
                          (
                            WordObjectAlignment.right,
                            'Right',
                            Icons.align_horizontal_right_rounded,
                          ),
                          (
                            WordObjectAlignment.top,
                            'Top',
                            Icons.align_vertical_top_rounded,
                          ),
                          (
                            WordObjectAlignment.verticalCenter,
                            'Middle',
                            Icons.align_vertical_center_rounded,
                          ),
                          (
                            WordObjectAlignment.bottom,
                            'Bottom',
                            Icons.align_vertical_bottom_rounded,
                          ),
                        ])
                          OutlinedButton.icon(
                            onPressed: allLocked
                                ? null
                                : () => widget.onShapesChanged(
                                    WordObjectManipulationService.align(
                                      widget.shapes,
                                      _selectedIds,
                                      entry.$1,
                                    ),
                                  ),
                            icon: Icon(entry.$3),
                            label: Text(entry.$2),
                          ),
                      ],
                    ),
                    if (selected.length >= 3) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            key: const Key(
                              'word-object-mobile-distribute-horizontal',
                            ),
                            onPressed: allLocked
                                ? null
                                : () => widget.onShapesChanged(
                                    WordObjectManipulationService.distribute(
                                      widget.shapes,
                                      _selectedIds,
                                      WordObjectDistribution.horizontal,
                                    ),
                                  ),
                            icon: const Icon(Icons.space_bar_rounded),
                            label: const Text('Horizontal'),
                          ),
                          OutlinedButton.icon(
                            key: const Key(
                              'word-object-mobile-distribute-vertical',
                            ),
                            onPressed: allLocked
                                ? null
                                : () => widget.onShapesChanged(
                                    WordObjectManipulationService.distribute(
                                      widget.shapes,
                                      _selectedIds,
                                      WordObjectDistribution.vertical,
                                    ),
                                  ),
                            icon: const RotatedBox(
                              quarterTurns: 1,
                              child: Icon(Icons.space_bar_rounded),
                            ),
                            label: const Text('Vertical'),
                          ),
                        ],
                      ),
                    ],
                  ],
                  sectionTitle('Object actions'),
                  if (hasOverflow)
                    ListTile(
                      key: const Key('word-object-mobile-overflow-warning'),
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.warning_amber_rounded,
                        color: theme.colorScheme.error,
                      ),
                      title: const Text('Outside printable area'),
                      subtitle: const Text(
                        'Move or fit the selected object before export.',
                      ),
                      trailing: TextButton(
                        key: const Key('word-object-mobile-fit-inside'),
                        onPressed: allLocked
                            ? null
                            : () {
                                widget.onShapesChanged([
                                  for (final item in widget.shapes)
                                    if (_selectedIds.contains(item.id) &&
                                        !item.locked)
                                      WordPaginationService
                                          .fitInsidePrintableBounds(item)
                                    else
                                      item,
                                ]);
                                setSheetState(() {});
                              },
                        child: const Text('Fit inside'),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('word-object-mobile-copy'),
                        onPressed: _copySelection,
                        icon: const Icon(Icons.content_copy_rounded),
                        label: const Text('Copy'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('word-object-mobile-paste'),
                        onPressed: _clipboard.isEmpty ? null : _pasteClipboard,
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('Paste'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('word-object-mobile-forward'),
                        onPressed: () => widget.onShapesChanged(
                          WordObjectManipulationService.bringForwardOne(
                            widget.shapes,
                            _selectedIds,
                          ),
                        ),
                        icon: const Icon(Icons.arrow_upward_rounded),
                        label: const Text('Forward'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('word-object-mobile-backward'),
                        onPressed: () => widget.onShapesChanged(
                          WordObjectManipulationService.sendBackwardOne(
                            widget.shapes,
                            _selectedIds,
                          ),
                        ),
                        icon: const Icon(Icons.arrow_downward_rounded),
                        label: const Text('Backward'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('word-object-mobile-front'),
                        onPressed: () => widget.onShapesChanged(
                          WordObjectManipulationService.bringToFront(
                            widget.shapes,
                            _selectedIds,
                          ),
                        ),
                        icon: const Icon(Icons.flip_to_front_rounded),
                        label: const Text('To front'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('word-object-mobile-back'),
                        onPressed: () => widget.onShapesChanged(
                          WordObjectManipulationService.sendToBack(
                            widget.shapes,
                            _selectedIds,
                          ),
                        ),
                        icon: const Icon(Icons.flip_to_back_rounded),
                        label: const Text('To back'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    key: const Key('word-object-mobile-delete'),
                    onPressed: selected.every((item) => item.locked)
                        ? null
                        : () {
                            Navigator.of(sheetContext).pop();
                            _deleteSelection();
                          },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(
                      selected.any((item) => item.locked)
                          ? 'Delete unlocked objects'
                          : 'Delete selected',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool get _modifierPressed {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed;
  }

  void _handleDesktopPointerDown(
    WordShapeObject shape,
    PointerDownEvent event,
  ) {
    _select(shape.id, additive: _modifierPressed);
    _desktopPointerObjectId = shape.id;
    _desktopPointerDownPosition = event.position;
    _desktopPointerMoved = false;
  }

  void _handleDesktopPointerMove(
    WordShapeObject shape,
    PointerMoveEvent event,
  ) {
    if (_desktopPointerObjectId != shape.id) return;
    final origin = _desktopPointerDownPosition;
    if (origin == null) return;
    final delta = event.position - origin;
    if (delta.distanceSquared >
        _desktopClickMovementTolerance * _desktopClickMovementTolerance) {
      _desktopPointerMoved = true;
    }
  }

  void _handleDesktopPointerUp(
    BuildContext context,
    WordShapeObject shape,
    PointerUpEvent event,
    Future<void> Function(WordShapeObject shape)? editGeometry,
  ) {
    final qualifiesAsClick =
        _desktopPointerObjectId == shape.id && !_desktopPointerMoved;
    _resetDesktopPointerTracking();
    if (!qualifiesAsClick || _modifierPressed) {
      _resetDesktopClickTracking();
      return;
    }
    if (!shape.isTextContainer && !shape.isGeometryObject) {
      _resetDesktopClickTracking();
      return;
    }

    final previousTime = _lastDesktopClickTime;
    final previousPosition = _lastDesktopClickPosition;
    final elapsed = previousTime == null ? null : event.timeStamp - previousTime;
    final positionDelta = previousPosition == null
        ? null
        : event.position - previousPosition;
    final isDoubleClick = _lastDesktopClickObjectId == shape.id &&
        elapsed != null &&
        !elapsed.isNegative &&
        elapsed <= _desktopDoubleClickWindow &&
        positionDelta != null &&
        positionDelta.distanceSquared <=
            _desktopClickMovementTolerance * _desktopClickMovementTolerance;

    if (!isDoubleClick) {
      _lastDesktopClickObjectId = shape.id;
      _lastDesktopClickTime = event.timeStamp;
      _lastDesktopClickPosition = event.position;
      return;
    }

    _resetDesktopClickTracking();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = widget.shapes
          .where((item) => item.id == shape.id)
          .firstOrNull;
      if (current == null) return;
      if (current.isGeometryObject && editGeometry != null) {
        editGeometry(current);
      } else if (current.isTextContainer) {
        _editText(context, current);
      }
    });
  }

  void _resetDesktopPointerTracking() {
    _desktopPointerObjectId = null;
    _desktopPointerDownPosition = null;
    _desktopPointerMoved = false;
  }

  void _resetDesktopClickTracking() {
    _lastDesktopClickObjectId = null;
    _lastDesktopClickTime = null;
    _lastDesktopClickPosition = null;
  }

  void _select(String id, {required bool additive}) {
    _focusNode.requestFocus();
    setState(() {
      if (additive) {
        if (!_selectedIds.add(id)) _selectedIds.remove(id);
      } else {
        _selectedIds
          ..clear()
          ..add(id);
      }
    });
  }

  void _addToSelection(String id) {
    _focusNode.requestFocus();
    setState(() => _selectedIds.add(id));
  }

  void _replaceSingle(WordShapeObject replacement) {
    widget.onShapesChanged([
      for (final item in widget.shapes)
        if (item.id == replacement.id) replacement else item,
    ]);
  }

  void _clearGuides() {
    if (!mounted || (_verticalGuide == null && _horizontalGuide == null)) return;
    setState(() {
      _verticalGuide = null;
      _horizontalGuide = null;
    });
  }

  void _copySelection() {
    setState(() {
      _clipboard = List<WordShapeObject>.unmodifiable(_selectedShapes);
    });
  }

  void _pasteClipboard() {
    if (_clipboard.isEmpty) return;
    final beforeIds = widget.shapes.map((item) => item.id).toSet();
    final updated = WordObjectManipulationService.paste(
      widget.shapes,
      _clipboard,
    );
    final newIds = updated
        .map((item) => item.id)
        .where((id) => !beforeIds.contains(id))
        .toSet();
    widget.onShapesChanged(updated);
    if (newIds.isNotEmpty) {
      setState(() {
        _selectedIds
          ..clear()
          ..addAll(newIds);
      });
    }
  }

  void _duplicateSelection() {
    final beforeIds = widget.shapes.map((item) => item.id).toSet();
    final updated = WordObjectManipulationService.duplicate(
      widget.shapes,
      _selectedIds,
    );
    final newIds = updated
        .map((item) => item.id)
        .where((id) => !beforeIds.contains(id))
        .toSet();
    widget.onShapesChanged(updated);
    if (newIds.isNotEmpty) {
      setState(() {
        _selectedIds
          ..clear()
          ..addAll(newIds);
      });
    }
  }

  void _deleteSelection() {
    final updated = WordObjectManipulationService.deleteSelection(
      widget.shapes,
      _selectedIds,
    );
    final liveIds = updated.map((item) => item.id).toSet();
    widget.onShapesChanged(updated);
    setState(() => _selectedIds.removeWhere((id) => !liveIds.contains(id)));
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final command = keyboard.isControlPressed || keyboard.isMetaPressed;

    if (key == LogicalKeyboardKey.escape && _selectedIds.isNotEmpty) {
      setState(_selectedIds.clear);
      return KeyEventResult.handled;
    }
    if (command && key == LogicalKeyboardKey.keyA && widget.shapes.isNotEmpty) {
      setState(() {
        _selectedIds
          ..clear()
          ..addAll(widget.shapes.map((item) => item.id));
      });
      return KeyEventResult.handled;
    }
    if (command && key == LogicalKeyboardKey.keyC && _selectedIds.isNotEmpty) {
      _copySelection();
      return KeyEventResult.handled;
    }
    if (command &&
        key == LogicalKeyboardKey.keyV &&
        _clipboard.isNotEmpty) {
      _pasteClipboard();
      return KeyEventResult.handled;
    }
    if (command && key == LogicalKeyboardKey.keyD && _selectedIds.isNotEmpty) {
      _duplicateSelection();
      return KeyEventResult.handled;
    }
    if (command && key == LogicalKeyboardKey.keyL && _selectedIds.isNotEmpty) {
      final allLocked = _selectedShapes.every((item) => item.locked);
      widget.onShapesChanged(
        WordObjectManipulationService.setLocked(
          widget.shapes,
          _selectedIds,
          !allLocked,
        ),
      );
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.delete ||
            key == LogicalKeyboardKey.backspace) &&
        _selectedIds.isNotEmpty) {
      _deleteSelection();
      return KeyEventResult.handled;
    }

    if (_selectedIds.isEmpty) return KeyEventResult.ignored;

    final step = keyboard.isShiftPressed
        ? WordObjectManipulationService.keyboardNudgeLarge
        : WordObjectManipulationService.keyboardNudge;
    double dx = 0;
    double dy = 0;
    if (key == LogicalKeyboardKey.arrowLeft) dx = -step;
    if (key == LogicalKeyboardKey.arrowRight) dx = step;
    if (key == LogicalKeyboardKey.arrowUp) dy = -step;
    if (key == LogicalKeyboardKey.arrowDown) dy = step;
    if (dx == 0 && dy == 0) return KeyEventResult.ignored;

    widget.onShapesChanged(
      WordObjectManipulationService.moveSelection(
        widget.shapes,
        _selectedIds,
        deltaX: dx,
        deltaY: dy,
      ),
    );
    return KeyEventResult.handled;
  }

  Future<void> _editText(
    BuildContext context,
    WordShapeObject shape,
  ) async {
    final controller = TextEditingController(text: shape.text);
    final value = await showAdaptiveModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                shape.kind == WordShapeKind.callout
                    ? 'Edit callout text'
                    : 'Edit text box',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('word-object-text-editor'),
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Type text',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, controller.text),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Apply'),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (!mounted || value == null) return;
    final current = widget.shapes
        .where((item) => item.id == shape.id)
        .firstOrNull;
    if (current == null) return;
    _replaceSingle(WordObjectManipulationService.updateText(current, value));
  }
}
