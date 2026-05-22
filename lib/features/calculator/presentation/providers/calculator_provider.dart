import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/math_engine.dart';

// Refined Calculator State and Notifier
class CalculatorState {
  final String equation;
  final String result;
  final bool isShift;
  final bool isAlpha;
  final bool isHyp;
  final List<String> history;
  final int historyIndex;

  CalculatorState({
    this.equation = '',
    this.result = '0',
    this.isShift = false,
    this.isAlpha = false,
    this.isHyp = false,
    this.history = const [],
    this.historyIndex = -1,
  });

  CalculatorState copyWith({
    String? equation,
    String? result,
    bool? isShift,
    bool? isAlpha,
    bool? isHyp,
    List<String>? history,
    int? historyIndex,
  }) {
    return CalculatorState(
      equation: equation ?? this.equation,
      result: result ?? this.result,
      isShift: isShift ?? this.isShift,
      isAlpha: isAlpha ?? this.isAlpha,
      isHyp: isHyp ?? this.isHyp,
      history: history ?? this.history,
      historyIndex: historyIndex ?? this.historyIndex,
    );
  }
}

class CalculatorNotifier extends StateNotifier<CalculatorState> {
  final MathEngine _engine = MathEngine();

  CalculatorNotifier() : super(CalculatorState());

  void addToken(String token) {
    String newToken = token;
    if (state.isHyp) {
      if (token == 'sin(') newToken = 'sinh(';
      if (token == 'cos(') newToken = 'cosh(';
      if (token == 'tan(') newToken = 'tanh(';
    }

    if (state.equation == 'Error' || state.equation == '0') {
      state = state.copyWith(equation: newToken, isShift: false, isAlpha: false, isHyp: false, historyIndex: -1);
    } else {
      state = state.copyWith(equation: state.equation + newToken, isShift: false, isAlpha: false, isHyp: false, historyIndex: -1);
    }
  }

  void delete() {
    if (state.equation.isNotEmpty) {
      state = state.copyWith(
        equation: state.equation.substring(0, state.equation.length - 1),
        historyIndex: -1,
      );
    }
  }

  void clear() {
    state = state.copyWith(
      equation: '',
      result: '0',
      isShift: false,
      isAlpha: false,
      isHyp: false,
      historyIndex: -1,
    );
  }

  void toggleShift() {
    state = state.copyWith(isShift: !state.isShift, isAlpha: false, isHyp: false);
  }

  void toggleAlpha() {
    state = state.copyWith(isAlpha: !state.isAlpha, isShift: false, isHyp: false);
  }

  void toggleHyp() {
    state = state.copyWith(isHyp: !state.isHyp, isShift: false, isAlpha: false);
  }

  void calculate() {
    if (state.equation.isEmpty) return;
    final res = _engine.evaluate(state.equation);
    
    List<String> newHistory = List.from(state.history);
    if (res != 'Error' && (newHistory.isEmpty || newHistory.last != state.equation)) {
      newHistory.add(state.equation);
      if (newHistory.length > 50) newHistory.removeAt(0);
    }
    
    state = state.copyWith(result: res, history: newHistory, historyIndex: -1);
  }

  void scrollHistory(int direction) {
    if (state.history.isEmpty) return;
    
    int newIndex;
    if (state.historyIndex == -1) {
      // Start from newest entry when pressing Up (-1)
      newIndex = direction < 0 ? state.history.length - 1 : 0;
    } else {
      // Move within history
      newIndex = state.historyIndex + direction;
      // Clamp index
      if (newIndex < 0) newIndex = 0;
      if (newIndex >= state.history.length) newIndex = state.history.length - 1;
    }
    
    state = state.copyWith(
      historyIndex: newIndex,
      equation: state.history[newIndex],
    );
  }

  void insertFormula(String formula) {
    String cleanFormula = formula;
    if (formula.contains('=')) {
      cleanFormula = formula.split('=')[1].trim();
    }
    
    if (state.equation == 'Error' || state.equation == '0' || state.equation.isEmpty) {
      state = state.copyWith(equation: cleanFormula, historyIndex: -1);
    } else {
      state = state.copyWith(equation: state.equation + cleanFormula, historyIndex: -1);
    }
  }

  void clearHistory() {
    state = state.copyWith(history: [], historyIndex: -1);
  }

  void reuseHistory(String historyEntry) {
    state = state.copyWith(equation: historyEntry, historyIndex: -1);
  }
}

final calculatorProvider = StateNotifierProvider<CalculatorNotifier, CalculatorState>((ref) {
  return CalculatorNotifier();
});
