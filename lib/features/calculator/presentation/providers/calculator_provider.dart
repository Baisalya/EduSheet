import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/calculation_history_entry.dart';
import '../../domain/models/calculator_mode.dart';
import '../../domain/services/calculator_input_editor.dart';
import '../../domain/services/math_engine.dart';

class CalculatorState {
  final String equation;
  final String result;
  final String? previewResult;
  final String? errorMessage;
  final bool isShift;
  final bool isHyp;
  final AngleUnit angleUnit;
  final double lastAnswer;
  final List<CalculationHistoryEntry> history;
  final int historyIndex;
  final String historyDraft;
  final bool justEvaluated;

  const CalculatorState({
    this.equation = '',
    this.result = '0',
    this.previewResult,
    this.errorMessage,
    this.isShift = false,
    this.isHyp = false,
    this.angleUnit = AngleUnit.radians,
    this.lastAnswer = 0,
    this.history = const [],
    this.historyIndex = -1,
    this.historyDraft = '',
    this.justEvaluated = false,
  });

  CalculatorState copyWith({
    String? equation,
    String? result,
    String? previewResult,
    bool clearPreviewResult = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isShift,
    bool? isHyp,
    AngleUnit? angleUnit,
    double? lastAnswer,
    List<CalculationHistoryEntry>? history,
    int? historyIndex,
    String? historyDraft,
    bool? justEvaluated,
  }) {
    return CalculatorState(
      equation: equation ?? this.equation,
      result: result ?? this.result,
      previewResult: clearPreviewResult
          ? null
          : (previewResult ?? this.previewResult),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      isShift: isShift ?? this.isShift,
      isHyp: isHyp ?? this.isHyp,
      angleUnit: angleUnit ?? this.angleUnit,
      lastAnswer: lastAnswer ?? this.lastAnswer,
      history: history ?? this.history,
      historyIndex: historyIndex ?? this.historyIndex,
      historyDraft: historyDraft ?? this.historyDraft,
      justEvaluated: justEvaluated ?? this.justEvaluated,
    );
  }
}

class CalculatorController extends StateNotifier<CalculatorState> {
  final MathEngine _engine;
  final CalculatorInputEditor _inputEditor;
  final Duration previewDebounce;
  Timer? _previewTimer;
  bool _isDisposed = false;

  CalculatorController({
    MathEngine? engine,
    CalculatorInputEditor inputEditor = const CalculatorInputEditor(),
    this.previewDebounce = const Duration(milliseconds: 100),
  }) : _engine = engine ?? MathEngine(),
       _inputEditor = inputEditor,
       super(const CalculatorState());

  void addToken(String token) {
    final resolved = _inputEditor.resolveModeToken(
      token,
      isShift: state.isShift,
      isHyp: state.isHyp,
    );
    final equation = _inputEditor.append(
      state.equation,
      resolved,
      justEvaluated: state.justEvaluated,
    );

    state = state.copyWith(
      equation: equation,
      isShift: false,
      isHyp: false,
      historyIndex: -1,
      historyDraft: '',
      justEvaluated: false,
      clearPreviewResult: true,
      clearErrorMessage: true,
    );
    _schedulePreview();
  }

  void delete() {
    if (state.equation.isEmpty) return;
    state = state.copyWith(
      equation: _inputEditor.deleteLastToken(state.equation),
      historyIndex: -1,
      historyDraft: '',
      justEvaluated: false,
      clearPreviewResult: true,
      clearErrorMessage: true,
    );
    _schedulePreview();
  }

  void toggleSign() {
    state = state.copyWith(
      equation: state.justEvaluated
          ? '-Ans'
          : _inputEditor.toggleSign(state.equation),
      historyIndex: -1,
      historyDraft: '',
      justEvaluated: false,
      clearPreviewResult: true,
      clearErrorMessage: true,
    );
    _schedulePreview();
  }

  void clear() {
    _previewTimer?.cancel();
    state = state.copyWith(
      equation: '',
      result: '0',
      isShift: false,
      isHyp: false,
      historyIndex: -1,
      historyDraft: '',
      justEvaluated: false,
      clearPreviewResult: true,
      clearErrorMessage: true,
    );
  }

  void toggleShift() {
    state = state.copyWith(
      isShift: !state.isShift,
      isHyp: false,
      clearErrorMessage: true,
    );
  }

  void toggleHyp() {
    state = state.copyWith(
      isHyp: !state.isHyp,
      isShift: false,
      clearErrorMessage: true,
    );
  }

  void toggleAngleUnit() {
    state = state.copyWith(
      angleUnit: state.angleUnit == AngleUnit.radians
          ? AngleUnit.degrees
          : AngleUnit.radians,
      clearErrorMessage: true,
      clearPreviewResult: true,
    );
    _schedulePreview();
  }

  void calculate() {
    if (state.equation.trim().isEmpty) return;

    _previewTimer?.cancel();

    final calculation = _engine.evaluateDetailed(
      state.equation,
      angleUnit: state.angleUnit,
      ans: state.lastAnswer,
    );

    if (calculation.isFailure) {
      state = state.copyWith(
        result: calculation.displayText,
        errorMessage: calculation.errorMessage,
        justEvaluated: false,
        historyIndex: -1,
        historyDraft: '',
        clearPreviewResult: true,
      );
      return;
    }

    final entry = CalculationHistoryEntry(
      expression: state.equation,
      result: calculation.displayText,
      angleUnit: state.angleUnit,
      createdAt: DateTime.now(),
    );
    final history = List<CalculationHistoryEntry>.from(state.history);
    if (history.isEmpty || !_sameCalculation(history.last, entry)) {
      history.add(entry);
      if (history.length > 50) history.removeAt(0);
    }

    state = state.copyWith(
      result: calculation.displayText,
      lastAnswer: calculation.value,
      history: history,
      historyIndex: -1,
      historyDraft: '',
      justEvaluated: true,
      clearPreviewResult: true,
      clearErrorMessage: true,
    );
  }

  void previousHistory() {
    if (state.history.isEmpty) return;

    final draft = state.historyIndex == -1
        ? state.equation
        : state.historyDraft;
    final newIndex = state.historyIndex == -1
        ? state.history.length - 1
        : (state.historyIndex - 1 < 0 ? 0 : state.historyIndex - 1);
    final entry = state.history[newIndex];

    state = state.copyWith(
      historyIndex: newIndex,
      historyDraft: draft,
      equation: entry.expression,
      result: entry.result,
      justEvaluated: false,
      clearPreviewResult: true,
      clearErrorMessage: true,
    );
  }

  void nextHistory() {
    if (state.history.isEmpty || state.historyIndex == -1) return;

    if (state.historyIndex >= state.history.length - 1) {
      state = state.copyWith(
        historyIndex: -1,
        equation: state.historyDraft,
        historyDraft: '',
        justEvaluated: false,
        clearPreviewResult: true,
        clearErrorMessage: true,
      );
      _schedulePreview();
      return;
    }

    final newIndex = state.historyIndex + 1;
    final entry = state.history[newIndex];
    state = state.copyWith(
      historyIndex: newIndex,
      equation: entry.expression,
      result: entry.result,
      justEvaluated: false,
      clearPreviewResult: true,
      clearErrorMessage: true,
    );
  }

  void scrollHistory(int direction) {
    if (direction < 0) {
      previousHistory();
    } else {
      nextHistory();
    }
  }

  void insertFormula(String formula) {
    var cleanFormula = formula;
    final equalsIndex = formula.indexOf('=');
    if (equalsIndex != -1 && equalsIndex < formula.length - 1) {
      cleanFormula = formula.substring(equalsIndex + 1).trim();
    }

    final equation = state.equation.isEmpty || state.justEvaluated
        ? cleanFormula
        : '${state.equation}$cleanFormula';
    state = state.copyWith(
      equation: equation,
      historyIndex: -1,
      historyDraft: '',
      justEvaluated: false,
      clearPreviewResult: true,
      clearErrorMessage: true,
    );
    _schedulePreview();
  }

  void clearHistory() {
    state = state.copyWith(
      history: const [],
      historyIndex: -1,
      historyDraft: '',
    );
  }

  void reuseHistory(CalculationHistoryEntry entry) {
    state = state.copyWith(
      equation: entry.expression,
      result: entry.result,
      angleUnit: entry.angleUnit,
      historyIndex: -1,
      historyDraft: '',
      justEvaluated: false,
      clearPreviewResult: true,
      clearErrorMessage: true,
    );
  }

  void _schedulePreview() {
    _previewTimer?.cancel();

    if (state.justEvaluated || state.equation.trim().isEmpty) {
      if (state.previewResult != null) {
        state = state.copyWith(clearPreviewResult: true);
      }
      return;
    }

    final expression = state.equation;
    final angleUnit = state.angleUnit;
    final ans = state.lastAnswer;

    void evaluate() {
      if (_isDisposed) return;
      if (state.equation != expression ||
          state.angleUnit != angleUnit ||
          state.lastAnswer != ans ||
          state.justEvaluated) {
        return;
      }

      final preview = _engine.evaluatePreview(
        expression,
        angleUnit: angleUnit,
        ans: ans,
      );

      state = preview == null
          ? state.copyWith(clearPreviewResult: true)
          : state.copyWith(previewResult: preview.displayText);
    }

    if (previewDebounce == Duration.zero) {
      scheduleMicrotask(evaluate);
    } else {
      _previewTimer = Timer(previewDebounce, evaluate);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _previewTimer?.cancel();
    super.dispose();
  }

  bool _sameCalculation(CalculationHistoryEntry a, CalculationHistoryEntry b) {
    return a.expression == b.expression &&
        a.result == b.result &&
        a.angleUnit == b.angleUnit;
  }
}

typedef CalculatorNotifier = CalculatorController;

final calculatorProvider =
    StateNotifierProvider<CalculatorController, CalculatorState>((ref) {
      return CalculatorController();
    });
