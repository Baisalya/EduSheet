import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/math_symbol.dart';
import '../../domain/catalog/math_symbol_catalog.dart';

part 'math_keyboard_provider.g.dart';

@riverpod
class MathKeyboardState extends _$MathKeyboardState {
  @override
  MathCategory build() => MathCategory.basic;

  void setCategory(MathCategory category) {
    state = category;
  }
}

@riverpod
class FavoriteSymbols extends _$FavoriteSymbols {
  static const String _storageKey = 'math_keyboard_favorite_symbols_v2';
  static const String _legacyStorageKey = 'math_keyboard_favorite_symbols_v1';
  bool _disposed = false;

  @override
  List<MathSymbol> build() {
    ref.onDispose(() => _disposed = true);
    Future<void>.microtask(_load);
    return [];
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (_disposed) return;

    final savedIds = preferences.getStringList(_storageKey);
    if (savedIds != null) {
      state = savedIds
          .map(MathSymbolCatalog.findById)
          .whereType<MathSymbol>()
          .toList(growable: false);
      return;
    }

    // Backward-compatible one-time migration. Previous builds persisted raw
    // TeX, so existing teacher favourites must survive the domain refactor.
    final legacyTex =
        preferences.getStringList(_legacyStorageKey) ?? const <String>[];
    state = legacyTex
        .map(MathSymbolCatalog.findByTex)
        .whereType<MathSymbol>()
        .toList(growable: false);
    if (state.isNotEmpty) {
      await _persist();
    }
  }

  void toggleFavorite(MathSymbol symbol) {
    if (state.any((item) => item.id == symbol.id)) {
      state = state.where((item) => item.id != symbol.id).toList();
    } else {
      state = <MathSymbol>[...state, symbol];
    }
    _persist();
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _storageKey,
      state.map((symbol) => symbol.id).toList(growable: false),
    );
  }
}
