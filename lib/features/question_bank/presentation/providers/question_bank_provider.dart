import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/local_question_bank_repository.dart';
import '../../data/repositories/question_bank_repository.dart';
import '../../domain/models/question_bank_model.dart';

final questionBankRepositoryProvider = Provider<QuestionBankRepository>((ref) {
  return LocalQuestionBankRepository();
});

class QuestionBankState {
  final List<QuestionBankQuestion> questions;
  final bool isLoading;
  final String searchQuery;
  final String? selectedSubject;
  final String? selectedChapter;
  final Difficulty? selectedDifficulty;
  final bool showOnlyFavorites;

  QuestionBankState({
    this.questions = const [],
    this.isLoading = false,
    this.searchQuery = '',
    this.selectedSubject,
    this.selectedChapter,
    this.selectedDifficulty,
    this.showOnlyFavorites = false,
  });

  QuestionBankState copyWith({
    List<QuestionBankQuestion>? questions,
    bool? isLoading,
    String? searchQuery,
    String? selectedSubject,
    String? selectedChapter,
    Difficulty? selectedDifficulty,
    bool? showOnlyFavorites,
  }) {
    return QuestionBankState(
      questions: questions ?? this.questions,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedSubject: selectedSubject ?? this.selectedSubject,
      selectedChapter: selectedChapter ?? this.selectedChapter,
      selectedDifficulty: selectedDifficulty ?? this.selectedDifficulty,
      showOnlyFavorites: showOnlyFavorites ?? this.showOnlyFavorites,
    );
  }

  List<QuestionBankQuestion> get filteredQuestions {
    return questions.where((q) {
      final matchesSearch = q.question.text.toLowerCase().contains(searchQuery.toLowerCase()) ||
          q.tags.any((t) => t.toLowerCase().contains(searchQuery.toLowerCase()));
      final matchesSubject = selectedSubject == null || q.subject == selectedSubject;
      final matchesChapter = selectedChapter == null || q.chapter == selectedChapter;
      final matchesDifficulty = selectedDifficulty == null || q.difficulty == selectedDifficulty;
      final matchesFavorite = !showOnlyFavorites || q.isFavorite;

      return matchesSearch && matchesSubject && matchesChapter && matchesDifficulty && matchesFavorite;
    }).toList();
  }

  List<String> get subjects => questions.map((q) => q.subject).toSet().toList();
  List<String> get chapters => questions
      .where((q) => selectedSubject == null || q.subject == selectedSubject)
      .map((q) => q.chapter)
      .toSet()
      .toList();
}

class QuestionBankNotifier extends StateNotifier<QuestionBankState> {
  final QuestionBankRepository _repository;

  QuestionBankNotifier(this._repository) : super(QuestionBankState()) {
    loadQuestions();
  }

  Future<void> loadQuestions() async {
    state = state.copyWith(isLoading: true);
    final questions = await _repository.getAllQuestions();
    state = state.copyWith(questions: questions, isLoading: false);
  }

  Future<void> addQuestion(QuestionBankQuestion question) async {
    await _repository.addQuestion(question);
    await loadQuestions();
  }

  Future<void> updateQuestion(QuestionBankQuestion question) async {
    await _repository.updateQuestion(question);
    await loadQuestions();
  }

  Future<void> deleteQuestion(String id) async {
    await _repository.deleteQuestion(id);
    await loadQuestions();
  }

  Future<void> toggleFavorite(String id) async {
    final question = state.questions.firstWhere((q) => q.question.id == id);
    await updateQuestion(question.copyWith(isFavorite: !question.isFavorite));
  }

  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);
  void setSubject(String? subject) => state = state.copyWith(selectedSubject: subject, selectedChapter: null);
  void setChapter(String? chapter) => state = state.copyWith(selectedChapter: chapter);
  void setDifficulty(Difficulty? difficulty) => state = state.copyWith(selectedDifficulty: difficulty);
  void toggleShowOnlyFavorites() => state = state.copyWith(showOnlyFavorites: !state.showOnlyFavorites);

  Future<void> importData(String json) async {
    await _repository.importFromJson(json);
    await loadQuestions();
  }
}

final questionBankProvider = StateNotifierProvider<QuestionBankNotifier, QuestionBankState>((ref) {
  return QuestionBankNotifier(ref.watch(questionBankRepositoryProvider));
});
