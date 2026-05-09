import 'package:riverpod_annotation/riverpod_annotation.dart';
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
  @override
  List<MathSymbol> build() => [];

  void toggleFavorite(MathSymbol symbol) {
    if (state.contains(symbol)) {
      state = state.where((s) => s != symbol).toList();
    } else {
      state = [...state, symbol];
    }
  }
}
