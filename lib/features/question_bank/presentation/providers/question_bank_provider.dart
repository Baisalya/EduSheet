import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/question_copy_service.dart';
import 'package:edusheet/features/geometry_builder/services/geometry_diagram_registry.dart';
import 'package:edusheet/features/question_bank/application/question_bank_application_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/local_question_bank_repository.dart';
import '../../data/repositories/question_bank_repository.dart';
import '../../domain/models/question_bank_model.dart';

final questionBankRepositoryProvider = Provider<QuestionBankRepository>((ref) {
  return LocalQuestionBankRepository();
});

final questionBankApplicationServiceProvider =
    Provider<QuestionBankApplicationService>((ref) {
      return QuestionBankApplicationService(
        QuestionCopyService(
          geometryResolver: GeometryDiagramRegistry.instance.diagramFor,
        ),
      );
    });

const _unset = Object();

class QuestionBankState {
  final List<QuestionBankQuestion> questions;
  final bool isLoading;
  final String searchQuery;
  final String? selectedSubject;
  final String? selectedChapter;
  final Difficulty? selectedDifficulty;
  final QuestionType? selectedType;
  final bool showOnlyFavorites;

  const QuestionBankState({
    this.questions = const [],
    this.isLoading = false,
    this.searchQuery = '',
    this.selectedSubject,
    this.selectedChapter,
    this.selectedDifficulty,
    this.selectedType,
    this.showOnlyFavorites = false,
  });

  QuestionBankState copyWith({
    List<QuestionBankQuestion>? questions,
    bool? isLoading,
    String? searchQuery,
    Object? selectedSubject = _unset,
    Object? selectedChapter = _unset,
    Object? selectedDifficulty = _unset,
    Object? selectedType = _unset,
    bool? showOnlyFavorites,
  }) {
    return QuestionBankState(
      questions: questions ?? this.questions,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedSubject: identical(selectedSubject, _unset)
          ? this.selectedSubject
          : selectedSubject as String?,
      selectedChapter: identical(selectedChapter, _unset)
          ? this.selectedChapter
          : selectedChapter as String?,
      selectedDifficulty: identical(selectedDifficulty, _unset)
          ? this.selectedDifficulty
          : selectedDifficulty as Difficulty?,
      selectedType: identical(selectedType, _unset)
          ? this.selectedType
          : selectedType as QuestionType?,
      showOnlyFavorites: showOnlyFavorites ?? this.showOnlyFavorites,
    );
  }

  List<QuestionBankQuestion> get filteredQuestions {
    final query = searchQuery.trim().toLowerCase();
    final filtered = questions.where((entry) {
      final question = entry.question;
      final searchable = [
        question.plainTextAccessibility,
        question.subject,
        question.chapter,
        question.topic,
        question.grade,
        question.correctAnswer,
        entry.subject,
        entry.chapter,
        ...entry.tags,
      ].join(' ').toLowerCase();
      final matchesSearch = query.isEmpty || searchable.contains(query);
      final matchesSubject =
          selectedSubject == null || entry.subject == selectedSubject;
      final matchesChapter =
          selectedChapter == null || entry.chapter == selectedChapter;
      final matchesDifficulty =
          selectedDifficulty == null || entry.difficulty == selectedDifficulty;
      final matchesType = selectedType == null || question.type == selectedType;
      final matchesFavorite = !showOnlyFavorites || entry.isFavorite;

      return matchesSearch &&
          matchesSubject &&
          matchesChapter &&
          matchesDifficulty &&
          matchesType &&
          matchesFavorite;
    }).toList();

    filtered.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return filtered;
  }

  List<String> get subjects {
    final values =
        questions
            .map((question) => question.subject.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<String> get chapters {
    final values =
        questions
            .where(
              (question) =>
                  selectedSubject == null ||
                  question.subject == selectedSubject,
            )
            .map((question) => question.chapter.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }
}

class QuestionBankNotifier extends StateNotifier<QuestionBankState> {
  final QuestionBankRepository _repository;

  QuestionBankNotifier(this._repository) : super(const QuestionBankState()) {
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
    final question = state.questions.firstWhere(
      (item) => item.question.id == id,
    );
    await updateQuestion(question.copyWith(isFavorite: !question.isFavorite));
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSubject(String? subject) {
    state = state.copyWith(selectedSubject: subject, selectedChapter: null);
  }

  void setChapter(String? chapter) {
    state = state.copyWith(selectedChapter: chapter);
  }

  void setDifficulty(Difficulty? difficulty) {
    state = state.copyWith(selectedDifficulty: difficulty);
  }

  void setType(QuestionType? type) {
    state = state.copyWith(selectedType: type);
  }

  void toggleShowOnlyFavorites() {
    state = state.copyWith(showOnlyFavorites: !state.showOnlyFavorites);
  }

  void clearFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedSubject: null,
      selectedChapter: null,
      selectedDifficulty: null,
      selectedType: null,
      showOnlyFavorites: false,
    );
  }

  Future<void> importData(String json) async {
    await _repository.importFromJson(json);
    await loadQuestions();
  }
}

final questionBankProvider =
    StateNotifierProvider<QuestionBankNotifier, QuestionBankState>((ref) {
      return QuestionBankNotifier(ref.watch(questionBankRepositoryProvider));
    });
