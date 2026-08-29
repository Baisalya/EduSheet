import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/math_symbol.dart';
import '../editing/math_editor_adapter.dart';

part 'math_keyboard_controller.g.dart';

enum KeyboardType { system, math }

enum FloatingElementType { shape, textBox }

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
  }

  void showSystemKeyboard() {
    state = state.copyWith(isVisible: false, type: KeyboardType.system);
    // The UI (MathKeyboardField) will handle calling TextInput.show after a frame
    final node = state.activeFocusNode;
    if (node != null && node.canRequestFocus && node.context != null) {
      node.requestFocus();
    }
  }

  void hideKeyboard() {
    state = state.copyWith(isVisible: false, type: KeyboardType.system);
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
  }

  void moveCursorRight() {
    MathEditorAdapterFactory.forController(state.activeController)?.moveRight();
  }

  void nextField() {
    final adapter = MathEditorAdapterFactory.forController(
      state.activeController,
    );
    if (adapter?.moveToNextSlot() ?? false) return;

    final focusContext = state.activeFocusNode?.context;
    if (focusContext != null) {
      FocusScope.of(focusContext).nextFocus();
    }
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
        return;
      case MathInputBehavior.subscriptMode:
        if (!state.isSubscriptMode && symbol.modeBaseSource != null) {
          _insertSource(symbol.modeBaseSource!);
        }
        toggleSubscriptMode();
        return;
      case MathInputBehavior.insert:
        _insertSource(symbol.tex);
    }
  }

  /// Compatibility/raw insertion path for actions that are not catalogue keys.
  void insertText(String source) => _insertSource(source);

  void _insertSource(String source) {
    final adapter = MathEditorAdapterFactory.forController(
      state.activeController,
    );
    if (adapter == null) return;

    _rememberSymbol(source);
    if (source == ' ' || source == '\n') {
      state = state.copyWith(isPowerMode: false, isSubscriptMode: false);
    }

    adapter.insert(
      source,
      MathInsertionContext(
        powerMode: state.isPowerMode,
        subscriptMode: state.isSubscriptMode,
        symbolSizeLevel: state.symbolSizeLevel,
      ),
    );
  }

  void clearAll() {
    MathEditorAdapterFactory.forController(state.activeController)?.clear();
  }

  void deleteBackward() {
    MathEditorAdapterFactory.forController(
      state.activeController,
    )?.deleteBackward();
  }
}
