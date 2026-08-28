import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/geometry_editor_session.dart';
import '../application/geometry_recipe.dart';
import '../application/geometry_selection.dart';
import '../models/geometry_diagram.dart';
import '../models/geometry_label.dart';
import '../models/geometry_point.dart';
import '../models/geometry_shape.dart';
import 'geometry_add_sheet.dart';
import 'geometry_canvas.dart';
import 'geometry_context_bar.dart';
import 'geometry_input_dialogs.dart';
import 'geometry_quick_start.dart';
import 'geometry_selection_inspector.dart';
import 'label_editor_sheet.dart';

class GeometryBuilderScreen extends StatefulWidget {
  final GeometryDiagram? initialDiagram;
  final GeometryShapeType? initialShape;
  final double? maxHeight;

  const GeometryBuilderScreen({
    super.key,
    this.initialDiagram,
    this.initialShape,
    this.maxHeight,
  });

  static Future<GeometryDiagram?> show(
    BuildContext context, {
    GeometryDiagram? initialDiagram,
    GeometryShapeType? initialShape,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    final view = View.of(context);
    final fullHeight = view.physicalSize.height / view.devicePixelRatio;
    final sheetHeight = fullHeight * 0.94;

    return showGeneralDialog<GeometryDiagram>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1220),
                child: FractionallySizedBox(
                  widthFactor: 1,
                  child: GeometryBuilderScreen(
                    maxHeight: sheetHeight,
                    initialDiagram: initialDiagram,
                    initialShape: initialShape,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<GeometryBuilderScreen> createState() => _GeometryBuilderScreenState();
}

class _GeometryBuilderScreenState extends State<GeometryBuilderScreen> {
  late final GeometryEditorSession _session;
  final _repaintKey = GlobalKey();
  final _canvasFocus = FocusNode(debugLabel: 'Geometry Studio canvas');

  @override
  void initState() {
    super.initState();
    _session = GeometryEditorSession(initialDiagram: widget.initialDiagram);
    final initialShape = widget.initialShape;
    if (initialShape != null && widget.initialDiagram == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _session.addShape(initialShape);
      });
    }
  }

  @override
  void dispose() {
    _canvasFocus.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaHeight = MediaQuery.sizeOf(context).height;
    final height = widget.maxHeight ?? mediaHeight * 0.92;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SizedBox(
        height: height,
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.keyZ, control: true):
                _UndoIntent(),
            SingleActivator(LogicalKeyboardKey.keyY, control: true):
                _RedoIntent(),
            SingleActivator(LogicalKeyboardKey.delete): _DeleteIntent(),
            SingleActivator(LogicalKeyboardKey.escape): _EscapeIntent(),
            SingleActivator(LogicalKeyboardKey.keyD, control: true):
                _DuplicateIntent(),
          },
          child: Actions(
            actions: {
              _UndoIntent: CallbackAction<_UndoIntent>(
                onInvoke: (_) {
                  _session.undo();
                  return null;
                },
              ),
              _RedoIntent: CallbackAction<_RedoIntent>(
                onInvoke: (_) {
                  _session.redo();
                  return null;
                },
              ),
              _DeleteIntent: CallbackAction<_DeleteIntent>(
                onInvoke: (_) {
                  _showOutcome(_session.deleteSelected());
                  return null;
                },
              ),
              _EscapeIntent: CallbackAction<_EscapeIntent>(
                onInvoke: (_) {
                  if (_session.selection.kind != GeometrySelectionKind.none) {
                    _session.clearSelection();
                  } else {
                    _requestClose();
                  }
                  return null;
                },
              ),
              _DuplicateIntent: CallbackAction<_DuplicateIntent>(
                onInvoke: (_) {
                  _showOutcome(_session.duplicateSelectedShape());
                  return null;
                },
              ),
            },
            child: Focus(
              focusNode: _canvasFocus,
              autofocus: true,
              child: PopScope<GeometryDiagram>(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (!didPop) _requestClose();
                },
                child: Scaffold(
                  resizeToAvoidBottomInset: false,
                  appBar: _buildAppBar(),
                  body: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;
                      if (wide) return _buildDesktop();
                      return _buildCompact(constraints.maxHeight);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: AnimatedBuilder(
        animation: _session,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Geometry Studio'),
            Text(
              _session.isEmpty
                  ? 'Choose a figure and edit it directly'
                  : _session.selectionLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!compact)
          AnimatedBuilder(
            animation: _session,
            builder: (context, _) => IconButton(
              tooltip: 'Undo (Ctrl+Z)',
              onPressed: _session.canUndo ? _session.undo : null,
              icon: const Icon(Icons.undo_rounded),
            ),
          ),
        if (!compact)
          AnimatedBuilder(
            animation: _session,
            builder: (context, _) => IconButton(
              tooltip: 'Redo (Ctrl+Y)',
              onPressed: _session.canRedo ? _session.redo : null,
              icon: const Icon(Icons.redo_rounded),
            ),
          ),
        PopupMenuButton<_GeometryMenuAction>(
          tooltip: 'More geometry options',
          onSelected: _handleMenu,
          itemBuilder: (context) => [
            if (compact)
              PopupMenuItem(
                value: _GeometryMenuAction.undo,
                enabled: _session.canUndo,
                child: const ListTile(
                  dense: true,
                  leading: Icon(Icons.undo_rounded),
                  title: Text('Undo'),
                ),
              ),
            if (compact)
              PopupMenuItem(
                value: _GeometryMenuAction.redo,
                enabled: _session.canRedo,
                child: const ListTile(
                  dense: true,
                  leading: Icon(Icons.redo_rounded),
                  title: Text('Redo'),
                ),
              ),
            const PopupMenuItem(
              value: _GeometryMenuAction.grid,
              child: ListTile(
                dense: true,
                leading: Icon(Icons.grid_4x4_rounded),
                title: Text('Toggle grid'),
              ),
            ),
            const PopupMenuItem(
              value: _GeometryMenuAction.snap,
              child: ListTile(
                dense: true,
                leading: Icon(Icons.grid_on_rounded),
                title: Text('Toggle snap'),
              ),
            ),
            const PopupMenuItem(
              value: _GeometryMenuAction.clear,
              child: ListTile(
                dense: true,
                leading: Icon(Icons.delete_sweep_outlined),
                title: Text('Clear diagram'),
              ),
            ),
          ],
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: _requestClose,
          icon: const Icon(Icons.close_rounded),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton.icon(
            onPressed: _insert,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Insert'),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktop() {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 250,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              border: Border(
                right: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
              ),
            ),
            child: GeometryQuickStart(
              onRecipe: _useRecipe,
              onBrowseAll: _browseAll,
            ),
          ),
        ),
        Expanded(child: _canvasWorkspace(showQuickStart: false)),
        SizedBox(
          width: 260,
          child: GeometrySelectionInspector(session: _session),
        ),
      ],
    );
  }

  Widget _buildCompact(double availableHeight) {
    final veryShort = availableHeight < 430;
    return _canvasWorkspace(
      showQuickStart: !veryShort && _session.isEmpty,
      compactQuickStart: true,
    );
  }

  Widget _canvasWorkspace({
    required bool showQuickStart,
    bool compactQuickStart = false,
  }) {
    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        return Column(
          children: [
            if (showQuickStart && _session.isEmpty)
              GeometryQuickStart(
                compact: compactQuickStart,
                onRecipe: _useRecipe,
                onBrowseAll: _browseAll,
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.5,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        GeometryCanvas(
                          session: _session,
                          repaintKey: _repaintKey,
                          onEditLabel: _showLabelEditor,
                          onEditPointLabel: _showPointLabelEditor,
                        ),
                        if (_session.isEmpty && !showQuickStart)
                          Center(
                            child: Card(
                              elevation: 0,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh
                                  .withValues(alpha: 0.94),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.category_outlined,
                                      size: 30,
                                    ),
                                    const SizedBox(height: 7),
                                    const Text(
                                      'Start with a figure',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    FilledButton.tonalIcon(
                                      onPressed: _browseAll,
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Choose figure'),
                                    ),
                                  ],
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
            GeometryContextBar(
              session: _session,
              onAdd: _browseAll,
              onRenamePoint: _renameSelectedPoint,
              onEditLabel: _editSelectedLabel,
              onSideMeasurement: _measureSelectedSide,
              onAngleMeasurement: _measureSelectedAngle,
              onCustomText: _addCustomText,
              onCoordinatePoint: _addCoordinatePoint,
              onOutcome: _showOutcome,
            ),
          ],
        );
      },
    );
  }

  Future<void> _browseAll() async {
    final recipe = await GeometryAddSheet.show(context);
    if (recipe == null || !mounted) return;
    _useRecipe(recipe);
  }

  void _useRecipe(GeometryRecipe recipe) {
    _session.useRecipe(recipe);
    _canvasFocus.requestFocus();
  }

  void _renameSelectedPoint() {
    final point = _session.selection.point(_session.diagram);
    if (point == null) return;
    _showPointLabelEditor(point);
  }

  void _editSelectedLabel() {
    final label = _session.selection.label(_session.diagram);
    if (label == null) return;
    _showLabelEditor(label);
  }

  void _showLabelEditor(GeometryLabel label) {
    showAdaptiveModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => LabelEditorSheet(
        type: label.type,
        initialLabel: label,
        onSubmitted: (text, fontSize, rotation, isBold) {
          _session.document.updateLabel(
            label.id,
            text: text,
            fontSize: fontSize,
            rotation: rotation,
            isBold: isBold,
          );
          _session.setSelection(GeometrySelection.label(label.id));
        },
      ),
    );
  }

  void _showPointLabelEditor(GeometryPoint point) {
    showAdaptiveModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => PointLabelEditorSheet(
        point: point,
        onSubmitted: (text, fontSize, rotation, isBold) {
          _session.document.updatePointLabel(
            point.id,
            text: text,
            fontSize: fontSize,
            rotation: rotation,
            isBold: isBold,
          );
          _session.setSelection(GeometrySelection.point(point.id));
        },
      ),
    );
  }

  Future<void> _addCoordinatePoint() async {
    final input = await GeometryInputDialogs.coordinatePoint(context);
    if (input == null || !mounted) return;
    _showOutcome(
      _session.addCoordinatePoint(x: input.x, y: input.y, label: input.label),
    );
  }

  Future<void> _addCustomText() async {
    final text = await GeometryInputDialogs.text(
      context,
      title: 'Add text to diagram',
      label: 'Text',
      hint: 'Example: Given, P, 5 cm, or a short note',
    );
    if (text == null || !mounted) return;
    _session.addCustomLabel(text);
  }

  Future<void> _measureSelectedSide() async {
    final text = await GeometryInputDialogs.text(
      context,
      title: 'Label this side',
      label: 'Measurement or name',
      hint: 'Example: 5 cm or AB = 5 cm',
    );
    if (text == null || !mounted) return;
    _showOutcome(_session.addSideMeasurement(text));
  }

  Future<void> _measureSelectedAngle() async {
    final pointLabel = _session.selection.point(_session.diagram)?.label.trim();
    final text = await GeometryInputDialogs.text(
      context,
      title: pointLabel != null && pointLabel.isNotEmpty
          ? 'Label angle $pointLabel'
          : 'Label this angle',
      label: 'Angle',
      hint: 'Example: 60° or ∠A = 60°',
    );
    if (text == null || !mounted) return;
    _showOutcome(_session.addAngleMeasurement(text));
  }

  void _showOutcome(GeometryEditOutcome outcome) {
    final message = outcome.message;
    if (!mounted || message == null || message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _handleMenu(_GeometryMenuAction action) {
    switch (action) {
      case _GeometryMenuAction.undo:
        _session.undo();
      case _GeometryMenuAction.redo:
        _session.redo();
      case _GeometryMenuAction.grid:
        _session.toggleGrid();
      case _GeometryMenuAction.snap:
        _session.toggleSnap();
      case _GeometryMenuAction.clear:
        _clearDiagram();
    }
  }

  Future<void> _clearDiagram() async {
    if (_session.isEmpty) return;
    final confirmed = await GeometryInputDialogs.confirm(
      context,
      title: 'Clear this diagram?',
      message: 'You can still use Undo immediately afterwards.',
      confirmLabel: 'Clear',
    );
    if (!mounted || !confirmed) return;
    _session.document.clear();
    _session.clearSelection();
  }

  Future<void> _requestClose() async {
    if (!_session.isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await GeometryInputDialogs.confirm(
      context,
      title: 'Discard geometry changes?',
      message: 'Your changes have not been inserted into the question yet.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      tonalConfirm: true,
    );
    if (!mounted || !discard) return;
    Navigator.of(context).pop();
  }

  void _insert() {
    if (_session.isEmpty) {
      _showOutcome(
        const GeometryEditOutcome.failure(
          'Choose or draw a figure before inserting.',
        ),
      );
      return;
    }
    Navigator.of(context).pop(_session.diagram);
  }
}

enum _GeometryMenuAction { undo, redo, grid, snap, clear }

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

class _DeleteIntent extends Intent {
  const _DeleteIntent();
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

class _DuplicateIntent extends Intent {
  const _DuplicateIntent();
}
