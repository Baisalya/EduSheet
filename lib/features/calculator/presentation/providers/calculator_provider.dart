import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/calculation_history_entry.dart';
import '../../domain/models/calculator_editing_value.dart';
import '../../domain/models/calculator_input_command.dart';
import '../../domain/models/calculator_mode.dart';
import '../../domain/services/calculator_input_editor.dart';
import '../../domain/services/formula_solver.dart';
import '../../domain/services/math_engine.dart';

class CalculatorState {
  final CalculatorEditingValue editingValue;
  final String result;
  final String? previewResult;
  final String? errorMessage;
  final bool isShift;
  final bool isHyp;
  final AngleUnit angleUnit;
  final double lastAnswer;
  final List<CalculationHistoryEntry> history;
  final int historyIndex;
  final CalculatorEditingValue historyDraftEditingValue;
  final bool justEvaluated;

  const CalculatorState({
    this.editingValue = const CalculatorEditingValue(),
    this.result = '0',
    this.previewResult,
    this.errorMessage,
    this.isShift = false,
    this.isHyp = false,
    this.angleUnit = AngleUnit.radians,
    this.lastAnswer = 0,
    this.history = const [],
    this.historyIndex = -1,
    this.historyDraftEditingValue = const CalculatorEditingValue(),
    this.justEvaluated = false,
  });

  String get equation => editingValue.text;
  CalculatorSelection get selection => editingValue.selection;
  int get cursorOffset => editingValue.cursorOffset;
  bool get hasSelection => editingValue.hasSelection;
  String get historyDraft => historyDraftEditingValue.text;

  CalculatorState copyWith({
    CalculatorEditingValue? editingValue,
    String? equation,
    CalculatorSelection? selection,
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
    CalculatorEditingValue? historyDraftEditingValue,
    String? historyDraft,
    bool? justEvaluated,
  }) {
    final nextEditingValue = _resolveEditingValue(
      editingValue: editingValue,
      equation: equation,
      selection: selection,
    );

    return CalculatorState(
      editingValue: nextEditingValue,
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
      historyDraftEditingValue:
          historyDraftEditingValue?.normalized() ??
          (historyDraft != null
              ? CalculatorEditingValue.fromText(historyDraft)
              : this.historyDraftEditingValue),
      justEvaluated: justEvaluated ?? this.justEvaluated,
    );
  }

  CalculatorEditingValue _resolveEditingValue({
    CalculatorEditingValue? editingValue,
    String? equation,
    CalculatorSelection? selection,
  }) {
    if (editingValue != null) return editingValue.normalized();
    if (equation != null) {
      if (selection != null) {
        return CalculatorEditingValue(
          text: equation,
          selection: selection,
        ).normalized();
      }
      return CalculatorEditingValue.fromText(equation);
    }
    if (selection != null) {
      return this.editingValue.copyWith(selection: selection);
    }
    return this.editingValue;
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

  /// Single execution path for calculator input intents.
  ///
  /// Touch buttons, hardware keyboard/numpad input, and resolved formula insertion are
  /// translated into [CalculatorInputCommand] before reaching this dispatcher.
  void dispatch(CalculatorInputCommand command) {
    switch (command.type) {
      case CalculatorInputCommandType.insertToken:
        _insertToken(command.text!);
        return;
      case CalculatorInputCommandType.insertFormula:
        _insertFormula(command.text!);
        return;
      case CalculatorInputCommandType.deleteBackward:
        _deleteBackward();
        return;
      case CalculatorInputCommandType.deleteForward:
        _deleteForward();
        return;
      case CalculatorInputCommandType.toggleSign:
        _toggleSign();
        return;
      case CalculatorInputCommandType.moveCursorLeft:
        _moveCursorLeft(extendSelection: command.extendSelection);
        return;
      case CalculatorInputCommandType.moveCursorRight:
        _moveCursorRight(extendSelection: command.extendSelection);
        return;
      case CalculatorInputCommandType.moveCursorToStart:
        _moveCursorToStart(extendSelection: command.extendSelection);
        return;
      case CalculatorInputCommandType.moveCursorToEnd:
        _moveCursorToEnd(extendSelection: command.extendSelection);
        return;
      case CalculatorInputCommandType.selectAll:
        setSelection(0, state.equation.length);
        return;
      case CalculatorInputCommandType.calculate:
        _calculate();
        return;
      case CalculatorInputCommandType.clear:
        _clear();
        return;
      case CalculatorInputCommandType.previousHistory:
        _previousHistory();
        return;
      case CalculatorInputCommandType.nextHistory:
        _nextHistory();
        return;
      case CalculatorInputCommandType.toggleShift:
        _toggleShift();
        return;
      case CalculatorInputCommandType.toggleHyp:
        _toggleHyp();
        return;
      case CalculatorInputCommandType.toggleAngleUnit:
        _toggleAngleUnit();
        return;
    }
  }

  // Compatibility wrappers kept for existing callers and tests. New input
  // surfaces should prefer [dispatch] so every source shares the same route.
  void addToken(String token) =>
      dispatch(CalculatorInputCommand.insertToken(token));

  /// Backward delete kept under the existing name for keypad/API compatibility.
  void delete() => dispatch(CalculatorInputCommand.deleteBackward);

  void deleteBackward() => dispatch(CalculatorInputCommand.deleteBackward);

  void deleteForward() => dispatch(CalculatorInputCommand.deleteForward);

  void toggleSign() => dispatch(CalculatorInputCommand.toggleSign);

  void selectAll() => dispatch(CalculatorInputCommand.selectAll);

  void moveCursorLeft({bool extendSelection = false}) {
    dispatch(
      CalculatorInputCommand.moveCursorLeft(extendSelection: extendSelection),
    );
  }

  void moveCursorRight({bool extendSelection = false}) {
    dispatch(
      CalculatorInputCommand.moveCursorRight(extendSelection: extendSelection),
    );
  }

  void moveCursorToStart({bool extendSelection = false}) {
    dispatch(
      CalculatorInputCommand.moveCursorToStart(
        extendSelection: extendSelection,
      ),
    );
  }

  void moveCursorToEnd({bool extendSelection = false}) {
    dispatch(
      CalculatorInputCommand.moveCursorToEnd(extendSelection: extendSelection),
    );
  }

  void clear() => dispatch(CalculatorInputCommand.clear);

  void toggleShift() => dispatch(CalculatorInputCommand.toggleShift);

  void toggleHyp() => dispatch(CalculatorInputCommand.toggleHyp);

  void toggleAngleUnit() => dispatch(CalculatorInputCommand.toggleAngleUnit);

  void calculate() => dispatch(CalculatorInputCommand.calculate);

  void previousHistory() => dispatch(CalculatorInputCommand.previousHistory);

  void nextHistory() => dispatch(CalculatorInputCommand.nextHistory);

  void scrollHistory(int direction) {
    dispatch(
      direction < 0
          ? CalculatorInputCommand.previousHistory
          : CalculatorInputCommand.nextHistory,
    );
  }

  /// Compatibility wrapper for calculator-ready formula expressions.
  /// Science formula variables must be resolved before calling this method.
  void insertFormula(String expression) {
    dispatch(CalculatorInputCommand.insertFormula(expression));
  }

  void setSelection(int baseOffset, [int? extentOffset]) {
    final editingValue = _inputEditor.setSelection(
      state.editingValue,
      CalculatorSelection(
        baseOffset: baseOffset,
        extentOffset: extentOffset ?? baseOffset,
      ),
    );
    _commitSelection(editingValue);
  }

  void _insertToken(String token) {
    final resolved = _inputEditor.resolveModeToken(
      token,
      isShift: state.isShift,
      isHyp: state.isHyp,
    );
    final editingValue = _inputEditor.insert(
      state.editingValue,
      resolved,
      justEvaluated: state.justEvaluated,
    );

    _commitEditingValue(editingValue, resetModes: true);
  }

  void _deleteBackward() {
    final editingValue = _inputEditor.deleteBackward(state.editingValue);
    if (editingValue == state.editingValue) return;
    _commitEditingValue(editingValue);
  }

  void _deleteForward() {
    final editingValue = _inputEditor.deleteForward(state.editingValue);
    if (editingValue == state.editingValue) return;
    _commitEditingValue(editingValue);
  }

  void _toggleSign() {
    final editingValue = state.justEvaluated
        ? CalculatorEditingValue.fromText('-Ans')
        : _inputEditor.toggleSignAtCaret(state.editingValue);
    _commitEditingValue(editingValue);
  }

  void _moveCursorLeft({bool extendSelection = false}) {
    _commitSelection(
      _inputEditor.moveCaretBackward(
        state.editingValue,
        extendSelection: extendSelection,
      ),
    );
  }

  void _moveCursorRight({bool extendSelection = false}) {
    _commitSelection(
      _inputEditor.moveCaretForward(
        state.editingValue,
        extendSelection: extendSelection,
      ),
    );
  }

  void _moveCursorToStart({bool extendSelection = false}) {
    _commitSelection(
      _inputEditor.moveCaretToStart(
        state.editingValue,
        extendSelection: extendSelection,
      ),
    );
  }

  void _moveCursorToEnd({bool extendSelection = false}) {
    _commitSelection(
      _inputEditor.moveCaretToEnd(
        state.editingValue,
        extendSelection: extendSelection,
      ),
    );
  }

  void _clear() {
    _previewTimer?.cancel();
    state = state.copyWith(
      editingValue: const CalculatorEditingValue(),
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

  void _toggleShift() {
    state = state.copyWith(
      isShift: !state.isShift,
      isHyp: false,
      clearErrorMessage: true,
    );
  }

  void _toggleHyp() {
    state = state.copyWith(
      isHyp: !state.isHyp,
      isShift: false,
      clearErrorMessage: true,
    );
  }

  void _toggleAngleUnit() {
    state = state.copyWith(
      angleUnit: state.angleUnit == AngleUnit.radians
          ? AngleUnit.degrees
          : AngleUnit.radians,
      clearErrorMessage: true,
      clearPreviewResult: true,
    );
    _schedulePreview();
  }

  void _calculate() {
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

  void _previousHistory() {
    if (state.history.isEmpty) return;

    final draft = state.historyIndex == -1
        ? state.editingValue
        : state.historyDraftEditingValue;
    final newIndex = state.historyIndex == -1
        ? state.history.length - 1
        : (state.historyIndex - 1 < 0 ? 0 : state.historyIndex - 1);
    final entry = state.history[newIndex];

    state = state.copyWith(
      historyIndex: newIndex,
      historyDraftEditingValue: draft,
      equation: entry.expression,
      result: entry.result,
      justEvaluated: false,
      clearPreviewResult: true,
      clearErrorMessage: true,
    );
  }

  void _nextHistory() {
    if (state.history.isEmpty || state.historyIndex == -1) return;

    if (state.historyIndex >= state.history.length - 1) {
      state = state.copyWith(
        historyIndex: -1,
        editingValue: state.historyDraftEditingValue,
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

  /// Inserts an already-resolved formula calculation into the editable
  /// calculator surface. Symbolic textbook formulas are resolved by
  /// FormulaSolver before they reach this controller.
  void _insertFormula(String expression) {
    final editingValue = _inputEditor.insert(
      state.editingValue,
      expression,
      justEvaluated: state.justEvaluated,
    );
    _commitEditingValue(editingValue);
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

  void _commitEditingValue(
    CalculatorEditingValue editingValue, {
    bool resetModes = false,
  }) {
    state = state.copyWith(
      editingValue: editingValue,
      isShift: resetModes ? false : state.isShift,
      isHyp: resetModes ? false : state.isHyp,
      historyIndex: -1,
      historyDraft: '',
      justEvaluated: false,
      clearPreviewResult: true,
      clearErrorMessage: true,
    );
    _schedulePreview();
  }

  void _commitSelection(CalculatorEditingValue editingValue) {
    if (editingValue == state.editingValue && !state.justEvaluated) return;
    state = state.copyWith(
      editingValue: editingValue,
      justEvaluated: false,
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

final formulaSolverProvider = Provider<FormulaSolver>((ref) {
  return FormulaSolver();
});
