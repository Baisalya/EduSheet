import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/math_symbol.dart';

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
  static const String _storageKey = 'math_keyboard_favorite_symbols_v1';
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
    final saved = preferences.getStringList(_storageKey) ?? const [];
    state = saved
        .map((tex) {
          final matches = mathSymbols.where((symbol) => symbol.tex == tex);
          return matches.isEmpty ? null : matches.first;
        })
        .whereType<MathSymbol>()
        .toList();
  }

  void toggleFavorite(MathSymbol symbol) {
    if (state.any((item) => item.tex == symbol.tex)) {
      state = state.where((item) => item.tex != symbol.tex).toList();
    } else {
      state = [...state, symbol];
    }
    _persist();
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _storageKey,
      state.map((symbol) => symbol.tex).toList(),
    );
  }
}
