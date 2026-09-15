import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/catalog/math_symbol_catalog.dart';
import '../../domain/models/math_dynamic_structure.dart';
import '../../domain/models/math_symbol.dart';
import '../../domain/services/math_dynamic_structure_codec.dart';
import '../editing/math_editor_adapter.dart';
import '../shortcuts/math_keyboard_productivity_shortcuts.dart';

part 'math_keyboard_controller.g.dart';

enum KeyboardType { system, math }

enum FloatingElementType { shape, textBox }

enum MathKeyboardPanelRequest { none, search, shortcuts }

/// Keeps the custom keyboard and every editor that reserves room for it on the
/// same window-dependent height. Using the raw requested height in one place
/// and a clamped height in another makes a short desktop window jump when the
/// native IME finishes hiding.
double effectiveMathKeyboardHeight(Size viewport, double requestedHeight) {
  final adaptiveMax = math.max(240.0, math.min(500.0, viewport.height * 0.62));
  final adaptiveMin = math.min(280.0, adaptiveMax);
  return requestedHeight.clamp(adaptiveMin, adaptiveMax).toDouble();
}

const mathKeyboardTransitionDuration = Duration(milliseconds: 260);

class FloatingElement {
  final String id;
  final FloatingElementType type;
  final Offset position;
  final Size size;
  final String? content; // For text box or specific shape data
  final IconData? icon; // For shapes

  FloatingElement({
    required this.id,
    required this.type,
    required this.position,
    this.size = const Size(100, 100),
    this.content,
    this.icon,
  });

  FloatingElement copyWith({Offset? position, Size? size, String? content}) {
    return FloatingElement(
      id: id,
      type: type,
      position: position ?? this.position,
      size: size ?? this.size,
      content: content ?? this.content,
      icon: icon,
    );
  }
}

class MathKeyboardStateData {
  final bool isVisible;
  final KeyboardType type;
  final Object? activeController;
  final FocusNode? activeFocusNode;
  final double height;
  final MathCategory currentCategory;
  final bool isTabletLayout;
  final bool isPowerMode;
  final bool isSubscriptMode;
  final int symbolSizeLevel; // -2 to +2 (small to large)
  final List<FloatingElement> floatingElements;
  final List<String> recentSymbols;
  final String accessibilityStatus;
  final int accessibilityStatusSerial;
  final MathKeyboardPanelRequest panelRequest;
  final int panelRequestSerial;

  MathKeyboardStateData({
    this.isVisible = false,
    this.type = KeyboardType.system,
    this.activeController,
    this.activeFocusNode,
    this.height = 320,
    this.currentCategory = MathCategory.basic,
    this.isTabletLayout = false,
    this.isPowerMode = false,
    this.isSubscriptMode = false,
    this.symbolSizeLevel = 0,
    this.floatingElements = const [],
    this.recentSymbols = const [],
    this.accessibilityStatus = 'Math keyboard ready.',
    this.accessibilityStatusSerial = 0,
    this.panelRequest = MathKeyboardPanelRequest.none,
    this.panelRequestSerial = 0,
  });

  MathKeyboardStateData copyWith({
    bool? isVisible,
    KeyboardType? type,
    Object? activeController,
    bool clearActiveController = false,
    FocusNode? activeFocusNode,
    bool clearActiveFocusNode = false,
    double? height,
    MathCategory? currentCategory,
    bool? isTabletLayout,
    bool? isPowerMode,
    bool? isSubscriptMode,
    int? symbolSizeLevel,
    List<FloatingElement>? floatingElements,
    List<String>? recentSymbols,
    String? accessibilityStatus,
    int? accessibilityStatusSerial,
    MathKeyboardPanelRequest? panelRequest,
    int? panelRequestSerial,
  }) {
    return MathKeyboardStateData(
      isVisible: isVisible ?? this.isVisible,
      type: type ?? this.type,
      activeController: clearActiveController
          ? null
          : (activeController ?? this.activeController),
      activeFocusNode: clearActiveFocusNode
          ? null
          : (activeFocusNode ?? this.activeFocusNode),
      height: height ?? this.height,
      currentCategory: currentCategory ?? this.currentCategory,
      isTabletLayout: isTabletLayout ?? this.isTabletLayout,
      isPowerMode: isPowerMode ?? this.isPowerMode,
      isSubscriptMode: isSubscriptMode ?? this.isSubscriptMode,
      symbolSizeLevel: symbolSizeLevel ?? this.symbolSizeLevel,
      floatingElements: floatingElements ?? this.floatingElements,
      recentSymbols: recentSymbols ?? this.recentSymbols,
      accessibilityStatus: accessibilityStatus ?? this.accessibilityStatus,
      accessibilityStatusSerial:
          accessibilityStatusSerial ?? this.accessibilityStatusSerial,
      panelRequest: panelRequest ?? this.panelRequest,
      panelRequestSerial: panelRequestSerial ?? this.panelRequestSerial,
    );
  }
}

@Riverpod(keepAlive: true)
class MathKeyboardController extends _$MathKeyboardController {
  static const String _recentStorageKey = 'math_keyboard_recent_symbols_v1';
  bool _disposed = false;

  @override
  MathKeyboardStateData build() {
    ref.onDispose(() => _disposed = true);
    Future<void>.microtask(_loadRecentSymbols);
    return MathKeyboardStateData();
  }

  Future<void> _loadRecentSymbols() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_disposed) return;
      state = state.copyWith(
        recentSymbols:
            preferences.getStringList(_recentStorageKey) ?? const <String>[],
      );
    } catch (_) {
      // Recents are an optional convenience cache. A missing platform storage
      // implementation (for example in a widget test) must not break input.
    }
  }

  void registerController(Object controller, FocusNode focusNode) {
    state = state.copyWith(
      activeController: controller,
      activeFocusNode: focusNode,
    );
  }

  /// Atomically assigns ownership and opens the custom math keyboard.
  ///
  /// Keeping those changes in one state emission prevents desktop focus
  /// transitions from observing a half-open session (visible keyboard with a
  /// stale owner, or a new owner while the keyboard is still marked hidden).
  void showMathKeyboardFor(Object controller, FocusNode focusNode) {
    state = state.copyWith(
      activeController: controller,
      activeFocusNode: focusNode,
      isVisible: true,
      type: KeyboardType.math,
    );
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    _announce(
      'Math keyboard active. Use Tab for the next formula box and Shift Tab for the previous box.',
    );
  }

  /// Transfers an already-visible math session to a rebuilt editor owner.
  ///
  /// This is intentionally a single state emission: replacing a FocusNode or
  /// editor controller must not publish a transient hidden/system-keyboard
  /// state between the old and new owner. Returns false when the supplied old
  /// controller no longer owns a visible math session.
  bool transferMathSessionOwner(
    Object previousController,
    Object controller,
    FocusNode focusNode,
  ) {
    if (!state.isVisible ||
        state.type != KeyboardType.math ||
        !identical(state.activeController, previousController)) {
      return false;
    }

    state = state.copyWith(
      activeController: controller,
      activeFocusNode: focusNode,
      isVisible: true,
      type: KeyboardType.math,
    );
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    return true;
  }

  void unregisterController(Object controller, {FocusNode? focusNode}) {
    if (state.activeController != controller) return;

    // A disposed/rebuilt MathKeyboardField can leave a post-frame cleanup
    // callback behind. Do not let that stale callback close a newer session
    // that happens to reuse the same editor controller with a new FocusNode.
    if (focusNode != null && !identical(state.activeFocusNode, focusNode)) {
      return;
    }

    state = state.copyWith(
      clearActiveController: true,
      clearActiveFocusNode: true,
      isVisible: false,
    );
  }

  void showMathKeyboard() {
    state = state.copyWith(isVisible: true, type: KeyboardType.math);
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    _announce('Math keyboard active.');
  }

  void showSystemKeyboard() {
    state = state.copyWith(isVisible: false, type: KeyboardType.system);
    _announce('Normal text keyboard active.');
    // The UI (MathKeyboardField) will handle calling TextInput.show after a frame
    final node = state.activeFocusNode;
    if (node != null && node.canRequestFocus && node.context != null) {
      node.requestFocus();
    }
  }

  void hideKeyboard() {
    state = state.copyWith(isVisible: false, type: KeyboardType.system);
    _announce('Math keyboard closed.');
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  /// Returns focus to the field that owns the current custom-keyboard session.
  /// Useful after a keyboard-local category/search/action panel is dismissed.
  void restoreActiveMathFocus() {
    if (!state.isVisible || state.type != KeyboardType.math) return;

    final node = state.activeFocusNode;
    if (node != null && node.canRequestFocus && node.context != null) {
      node.requestFocus();
    }
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void setCategory(MathCategory category) {
    state = state.copyWith(currentCategory: category);
    _announce('${_categoryAccessibilityLabel(category)} keys selected.');
  }

  void setHeight(double height) {
    // Clamp height between reasonable limits
    final clampedHeight = height.clamp(240.0, 520.0);
    state = state.copyWith(height: clampedHeight);
  }

  void toggleTabletLayout() {
    state = state.copyWith(isTabletLayout: !state.isTabletLayout);
  }

  void togglePowerMode() {
    state = state.copyWith(
      isPowerMode: !state.isPowerMode,
      isSubscriptMode: false,
    );
  }

  void toggleSubscriptMode() {
    state = state.copyWith(
      isSubscriptMode: !state.isSubscriptMode,
      isPowerMode: false,
    );
  }

  void addFloatingElement(FloatingElementType type, {IconData? icon}) {
    final newElement = FloatingElement(
      id: const Uuid().v4(),
      type: type,
      position: const Offset(50, 100),
      icon: icon,
      size: type == FloatingElementType.textBox
          ? const Size(150, 60)
          : const Size(80, 80),
    );
    state = state.copyWith(
      floatingElements: [...state.floatingElements, newElement],
    );
  }

  void updateElement(
    String id, {
    Offset? position,
    Size? size,
    String? content,
  }) {
    state = state.copyWith(
      floatingElements: state.floatingElements.map((e) {
        if (e.id == id) {
          return e.copyWith(position: position, size: size, content: content);
        }
        return e;
      }).toList(),
    );
  }

  void removeElement(String id) {
    state = state.copyWith(
      floatingElements: state.floatingElements
          .where((e) => e.id != id)
          .toList(),
    );
  }

  void setSymbolSize(int level) {
    state = state.copyWith(symbolSizeLevel: level.clamp(-2, 2));
  }

  void moveCursorLeft() {
    MathEditorAdapterFactory.forController(state.activeController)?.moveLeft();
    restoreActiveMathFocus();
  }

  void moveCursorRight() {
    MathEditorAdapterFactory.forController(state.activeController)?.moveRight();
    restoreActiveMathFocus();
  }

  void nextField() {
    final adapter = MathEditorAdapterFactory.forController(
      state.activeController,
    );
    if (adapter?.moveToNextSlot() ?? false) {
      _announce('Moved to the next formula box.');
      restoreActiveMathFocus();
      return;
    }

    final focusContext = state.activeFocusNode?.context;
    if (focusContext != null) {
      FocusScope.of(focusContext).nextFocus();
      _announce('Moved to the next field.');
    }
  }

  void previousField() {
    final adapter = MathEditorAdapterFactory.forController(
      state.activeController,
    );
    if (adapter?.moveToPreviousSlot() ?? false) {
      _announce('Moved to the previous formula box.');
      restoreActiveMathFocus();
      return;
    }

    final focusContext = state.activeFocusNode?.context;
    if (focusContext != null) {
      FocusScope.of(focusContext).previousFocus();
      _announce('Moved to the previous field.');
    }
  }

  void requestPanel(MathKeyboardPanelRequest request) {
    if (request == MathKeyboardPanelRequest.none) return;
    state = state.copyWith(
      panelRequest: request,
      panelRequestSerial: state.panelRequestSerial + 1,
    );
    _announce(
      request == MathKeyboardPanelRequest.search
          ? 'Opening math search.'
          : 'Opening keyboard shortcuts.',
    );
  }

  void consumePanelRequest(int serial) {
    if (serial != state.panelRequestSerial) return;
    state = state.copyWith(panelRequest: MathKeyboardPanelRequest.none);
  }

  bool handleProductivityCommand(MathKeyboardProductivityCommand command) {
    final mathActive = state.isVisible && state.type == KeyboardType.math;
    switch (command) {
      case MathKeyboardProductivityCommand.toggleKeyboard:
        if (mathActive) {
          showSystemKeyboard();
          return true;
        }
        final activeController = state.activeController;
        final activeFocusNode = state.activeFocusNode;
        if (activeController == null || activeFocusNode == null) return false;
        showMathKeyboardFor(activeController, activeFocusNode);
        return true;
      case MathKeyboardProductivityCommand.search:
        if (!mathActive) return false;
        requestPanel(MathKeyboardPanelRequest.search);
        return true;
      case MathKeyboardProductivityCommand.showShortcuts:
        if (!mathActive) return false;
        requestPanel(MathKeyboardPanelRequest.shortcuts);
        return true;
      case MathKeyboardProductivityCommand.insertFraction:
        return mathActive && insertStructureByTex(r'\frac{}{}');
      case MathKeyboardProductivityCommand.insertSquareRoot:
        return mathActive && insertStructureByTex(r'\sqrt{}');
      case MathKeyboardProductivityCommand.insertPower:
        return mathActive && insertStructureByTex(r'^{}');
      case MathKeyboardProductivityCommand.insertSubscript:
        return mathActive && insertStructureByTex(r'_{}');
      case MathKeyboardProductivityCommand.systemKeyboard:
        if (!mathActive) return false;
        showSystemKeyboard();
        return true;
      case MathKeyboardProductivityCommand.nextSlot:
        if (!mathActive || state.activeController == null) return false;
        nextField();
        return true;
      case MathKeyboardProductivityCommand.previousSlot:
        if (!mathActive || state.activeController == null) return false;
        previousField();
        return true;
    }
  }

  bool insertStructureByTex(String source) {
    final symbol = MathSymbolCatalog.findByTex(source);
    if (symbol == null) return false;
    insertStructure(symbol);
    return true;
  }

  void clearRecentSymbols() {
    state = state.copyWith(recentSymbols: const <String>[]);
    _persistRecentSymbols(const <String>[]);
  }

  void _rememberSymbol(String source) {
    if (source.trim().isEmpty || source.startsWith('{{geometry:')) return;
    final recent = <String>[
      source,
      ...state.recentSymbols.where((item) => item != source),
    ];
    final limited = recent.take(18).toList(growable: false);
    state = state.copyWith(recentSymbols: limited);
    _persistRecentSymbols(limited);
  }

  Future<void> _persistRecentSymbols(List<String> symbols) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(_recentStorageKey, symbols);
    } catch (_) {
      // Losing recent-history persistence is safe; formula insertion is not.
    }
  }

  /// Typed entry point used by the keyboard UI.
  ///
  /// [insertText] remains available for compatibility with non-catalog actions
  /// such as geometry placeholders, spaces and newlines.
  void insertSymbol(MathSymbol symbol) {
    switch (symbol.inputBehavior) {
      case MathInputBehavior.powerMode:
        if (!state.isPowerMode && symbol.modeBaseSource != null) {
          _insertSource(symbol.modeBaseSource!);
        }
        togglePowerMode();
        restoreActiveMathFocus();
        return;
      case MathInputBehavior.subscriptMode:
        if (!state.isSubscriptMode && symbol.modeBaseSource != null) {
          _insertSource(symbol.modeBaseSource!);
        }
        toggleSubscriptMode();
        restoreActiveMathFocus();
        return;
      case MathInputBehavior.insert:
        _insertCatalogSymbol(symbol);
    }
  }

  /// Inserts a catalogue structure immediately instead of activating a
  /// one-key power/subscript mode.
  ///
  /// The teacher-facing Build panel promises a visible box as soon as a
  /// structure is chosen. Normal keyboard keys still use [insertSymbol] so
  /// their existing quick power/subscript mode behavior is unchanged.
  void insertStructure(MathSymbol symbol) {
    state = state.copyWith(isPowerMode: false, isSubscriptMode: false);
    _insertCatalogSymbol(symbol);
  }

  /// Inserts a runtime-sized structure such as an arbitrary matrix,
  /// piecewise function, equation system, or aligned derivation.
  void insertDynamicStructure(MathDynamicStructureSpec spec) {
    if (!spec.isValid) return;
    final adapter = MathEditorAdapterFactory.forController(
      state.activeController,
    );
    if (adapter == null) return;

    state = state.copyWith(isPowerMode: false, isSubscriptMode: false);
    final instance = MathDynamicStructureInstance(spec: spec);
    final document = const MathDynamicStructureCodec().compile(instance);
    _rememberSymbol(document.tex);
    adapter.insertDynamicStructure(instance, _currentInsertionContext());
    _announce(
      'Inserted ${_dynamicStructureAccessibilityLabel(spec.kind)}. Use Tab to move through its boxes.',
    );
    restoreActiveMathFocus();
  }

  /// Compatibility/raw insertion path for actions that are not catalogue keys.
  void insertText(String source) => _insertSource(source);

  void _insertCatalogSymbol(MathSymbol symbol) {
    final adapter = MathEditorAdapterFactory.forController(
      state.activeController,
    );
    if (adapter == null) return;

    _rememberSymbol(symbol.tex);
    adapter.insertSymbol(symbol, _currentInsertionContext());
    _announce('Inserted ${symbol.accessibilityLabel}.');
    restoreActiveMathFocus();
  }

  void _insertSource(String source) {
    final adapter = MathEditorAdapterFactory.forController(
      state.activeController,
    );
    if (adapter == null) return;

    _rememberSymbol(source);
    if (source == ' ' || source == '\n') {
      state = state.copyWith(isPowerMode: false, isSubscriptMode: false);
    }

    adapter.insert(source, _currentInsertionContext());
    restoreActiveMathFocus();
  }

  MathInsertionContext _currentInsertionContext() => MathInsertionContext(
    powerMode: state.isPowerMode,
    subscriptMode: state.isSubscriptMode,
    symbolSizeLevel: state.symbolSizeLevel,
  );

  void clearAll() {
    MathEditorAdapterFactory.forController(state.activeController)?.clear();
    restoreActiveMathFocus();
  }

  void deleteBackward() {
    MathEditorAdapterFactory.forController(
      state.activeController,
    )?.deleteBackward();
    _announce('Deleted the previous math item.');
    restoreActiveMathFocus();
  }

  String _categoryAccessibilityLabel(MathCategory category) =>
      switch (category) {
        MathCategory.recent => 'Recent math',
        MathCategory.favorites => 'Favourite math',
        MathCategory.basic => 'Common math',
        MathCategory.functions => 'Algebra',
        MathCategory.trig => 'Trigonometry',
        MathCategory.calculus => 'Calculus',
        MathCategory.geometry => 'Geometry',
        MathCategory.physics => 'Physics',
        MathCategory.chemistry => 'Chemistry',
        MathCategory.statistics => 'Statistics',
        MathCategory.matrices => 'Matrices',
        MathCategory.greek => 'Greek symbols',
        MathCategory.operators => 'Operators and signs',
        MathCategory.brackets => 'Brackets',
        MathCategory.arrows => 'Arrows',
        MathCategory.sets => 'Sets',
        MathCategory.templates => 'Formula templates',
        MathCategory.format => 'Formatting',
        MathCategory.misc => 'Extra math',
      };

  String _dynamicStructureAccessibilityLabel(MathDynamicStructureKind kind) =>
      switch (kind) {
        MathDynamicStructureKind.matrix => 'matrix structure',
        MathDynamicStructureKind.determinant => 'determinant structure',
        MathDynamicStructureKind.augmentedMatrix =>
          'augmented matrix structure',
        MathDynamicStructureKind.piecewise => 'piecewise function',
        MathDynamicStructureKind.equationSystem => 'equation system',
        MathDynamicStructureKind.alignedDerivation => 'aligned derivation',
      };

  void _announce(String message) {
    state = state.copyWith(
      accessibilityStatus: message,
      accessibilityStatusSerial: state.accessibilityStatusSerial + 1,
    );
  }
}
