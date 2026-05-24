import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/math_engine.dart';

// Refined Calculator State and Notifier
class CalculatorState {
  final String equation;
  final String result;
  final bool isShift;
  final bool isAlpha;
  final bool isHyp;
  final AngleUnit angleUnit;
  final double lastAnswer;
  final List<String> history;
  final int historyIndex;

  CalculatorState({
    this.equation = '',
    this.result = '0',
    this.isShift = false,
    this.isAlpha = false,
    this.isHyp = false,
    this.angleUnit = AngleUnit.radians,
    this.lastAnswer = 0,
    this.history = const [],
    this.historyIndex = -1,
  });

  CalculatorState copyWith({
    String? equation,
    String? result,
    bool? isShift,
    bool? isAlpha,
    bool? isHyp,
    AngleUnit? angleUnit,
    double? lastAnswer,
    List<String>? history,
    int? historyIndex,
  }) {
    return CalculatorState(
      equation: equation ?? this.equation,
      result: result ?? this.result,
      isShift: isShift ?? this.isShift,
      isAlpha: isAlpha ?? this.isAlpha,
      isHyp: isHyp ?? this.isHyp,
      angleUnit: angleUnit ?? this.angleUnit,
      lastAnswer: lastAnswer ?? this.lastAnswer,
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
    if (token == 'sin(') {
      newToken = state.isHyp ? 'sinh(' : (state.isShift ? 'arcsin(' : token);
    } else if (token == 'cos(') {
      newToken = state.isHyp ? 'cosh(' : (state.isShift ? 'arccos(' : token);
    } else if (token == 'tan(') {
      newToken = state.isHyp ? 'tanh(' : (state.isShift ? 'arctan(' : token);
    } else if (token == 'sqrt(' && state.isShift) {
      newToken = 'cbrt(';
    } else if (token == '^2' && state.isShift) {
      newToken = '^3';
    } else if (token == '^' && state.isShift) {
      newToken = '^-1';
    } else if (token == 'log(' && state.isShift) {
      newToken = '10^';
    } else if (token == 'ln(' && state.isShift) {
      newToken = 'e^';
    } else if (token == 'C' && state.isShift) {
      newToken = 'P';
    }

    if (state.equation == 'Error' || state.equation == '0') {
      state = state.copyWith(
        equation: newToken,
        isShift: false,
        isAlpha: false,
        isHyp: false,
        historyIndex: -1,
      );
    } else {
      state = state.copyWith(
        equation: state.equation + newToken,
        isShift: false,
        isAlpha: false,
        isHyp: false,
        historyIndex: -1,
      );
    }
  }

  void delete() {
    if (state.equation.isNotEmpty) {
      final removableTokens = [
        'arcsin(',
        'arccos(',
        'arctan(',
        'sinh(',
        'cosh(',
        'tanh(',
        'sqrt(',
        'cbrt(',
        'log(',
        'ln(',
        'Ans',
      ];
      String? matchedToken;
      for (final token in removableTokens) {
        if (state.equation.endsWith(token)) {
          matchedToken = token;
          break;
        }
      }

      state = state.copyWith(
        equation: matchedToken == null
            ? state.equation.substring(0, state.equation.length - 1)
            : state.equation.substring(
                0,
                state.equation.length - matchedToken.length,
              ),
        historyIndex: -1,
      );
    }
  }

  void toggleSign() {
    if (state.equation.isEmpty || state.equation == 'Error') {
      state = state.copyWith(equation: '-', historyIndex: -1);
      return;
    }

    final start = _currentEntryStart(state.equation);
    final entry = state.equation.substring(start);
    final updatedEquation = entry.startsWith('-')
        ? state.equation.replaceRange(start, start + 1, '')
        : state.equation.replaceRange(start, start, '-');

    state = state.copyWith(equation: updatedEquation, historyIndex: -1);
  }

  int _currentEntryStart(String equation) {
    for (var i = equation.length - 1; i >= 0; i--) {
      final char = equation[i];
      if (char == '(' || char == ',') return i + 1;
      if (_isBinaryOperator(equation, i)) return i + 1;
    }
    return 0;
  }

  bool _isBinaryOperator(String equation, int index) {
    final char = equation[index];
    if (!'+-×÷*/'.contains(char)) return false;
    if (index == 0) return false;
    final previous = equation[index - 1];
    return previous != '(' && previous != ',' && !'+-×÷*/'.contains(previous);
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
    state = state.copyWith(
      isShift: !state.isShift,
      isAlpha: false,
      isHyp: false,
    );
  }

  void toggleAlpha() {
    state = state.copyWith(
      isAlpha: !state.isAlpha,
      isShift: false,
      isHyp: false,
    );
  }

  void toggleHyp() {
    state = state.copyWith(isHyp: !state.isHyp, isShift: false, isAlpha: false);
  }

  void toggleAngleUnit() {
    state = state.copyWith(
      angleUnit: state.angleUnit == AngleUnit.radians
          ? AngleUnit.degrees
          : AngleUnit.radians,
    );
  }

  void calculate() {
    if (state.equation.isEmpty) return;
    final res = _engine.evaluate(
      state.equation,
      angleUnit: state.angleUnit,
      ans: state.lastAnswer,
    );
    final parsedResult = double.tryParse(res);

    List<String> newHistory = List.from(state.history);
    if (res != 'Error' &&
        (newHistory.isEmpty || newHistory.last != state.equation)) {
      newHistory.add(state.equation);
      if (newHistory.length > 50) newHistory.removeAt(0);
    }

    state = state.copyWith(
      result: res,
      lastAnswer: parsedResult ?? state.lastAnswer,
      history: newHistory,
      historyIndex: -1,
    );
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

    if (state.equation == 'Error' ||
        state.equation == '0' ||
        state.equation.isEmpty) {
      state = state.copyWith(equation: cleanFormula, historyIndex: -1);
    } else {
      state = state.copyWith(
        equation: state.equation + cleanFormula,
        historyIndex: -1,
      );
    }
  }

  void clearHistory() {
    state = state.copyWith(history: [], historyIndex: -1);
  }

  void reuseHistory(String historyEntry) {
    state = state.copyWith(equation: historyEntry, historyIndex: -1);
  }
}

final calculatorProvider =
    StateNotifierProvider<CalculatorNotifier, CalculatorState>((ref) {
      return CalculatorNotifier();
    });
