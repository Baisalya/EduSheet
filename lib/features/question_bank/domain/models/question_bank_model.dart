import '../../../editor/domain/models/paper_model.dart';

/// Legacy Question Bank difficulty wrapper retained for JSON compatibility.
///
/// Modern [Question] already persists [QuestionDifficulty]. New Question Bank
/// writes keep the wrapper in a namespaced field while preserving the complete
/// question JSON, so reusable questions no longer lose their modern metadata.
enum Difficulty { easy, medium, hard }

extension DifficultyQuestionMapping on Difficulty {
  QuestionDifficulty get questionDifficulty => QuestionDifficulty.values[index];
}

extension QuestionDifficultyBankMapping on QuestionDifficulty {
  Difficulty get bankDifficulty => Difficulty.values[index];
}

class QuestionBankQuestion {
  final Question question;
  final String subject;
  final String chapter;
  final Difficulty difficulty;
  final List<String> tags;
  final bool isFavorite;
  final DateTime createdAt;

  QuestionBankQuestion({
    required this.question,
    required this.subject,
    required this.chapter,
    this.difficulty = Difficulty.medium,
    this.tags = const [],
    this.isFavorite = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory QuestionBankQuestion.fromQuestion(
    Question question, {
    bool isFavorite = false,
    DateTime? createdAt,
  }) {
    final subject = question.subject.trim().isEmpty
        ? 'General'
        : question.subject.trim();
    final chapter = question.chapter.trim().isEmpty
        ? 'General'
        : question.chapter.trim();
    return QuestionBankQuestion(
      question: question.copyWith(
        subject: subject,
        chapter: chapter,
        tags: List<String>.from(question.tags),
        modifiedAt: question.modifiedAt,
      ),
      subject: subject,
      chapter: chapter,
      difficulty: question.difficulty.bankDifficulty,
      tags: List<String>.from(question.tags),
      isFavorite: isFavorite,
      createdAt: createdAt,
    );
  }

  QuestionBankQuestion copyWith({
    Question? question,
    String? subject,
    String? chapter,
    Difficulty? difficulty,
    List<String>? tags,
    bool? isFavorite,
    DateTime? createdAt,
  }) {
    final nextQuestion = question ?? this.question;
    final nextSubject = subject ?? this.subject;
    final nextChapter = chapter ?? this.chapter;
    final nextDifficulty = difficulty ?? this.difficulty;
    final nextTags = tags ?? this.tags;
    return QuestionBankQuestion(
      question: nextQuestion.copyWith(
        subject: nextSubject,
        chapter: nextChapter,
        difficulty: nextDifficulty.questionDifficulty,
        tags: List<String>.from(nextTags),
        modifiedAt: nextQuestion.modifiedAt,
      ),
      subject: nextSubject,
      chapter: nextChapter,
      difficulty: nextDifficulty,
      tags: List<String>.from(nextTags),
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    // Keep the complete modern Question payload untouched. The older format
    // overwrote Question.difficulty (a name) with a bank integer, which silently
    // reset hard/easy questions to medium when reloaded.
    return {
      ...question.toJson(),
      'bankSubject': subject,
      'bankChapter': chapter,
      'bankDifficulty': difficulty.index,
      'bankTags': tags,
      'isFavorite': isFavorite,
      'bankCreatedAt': createdAt.toIso8601String(),
    };
  }

  factory QuestionBankQuestion.fromJson(Map<String, dynamic> json) {
    final legacyDifficulty = json['difficulty'];
    final bankDifficulty = json.containsKey('bankDifficulty')
        ? _difficultyFromIndex(json['bankDifficulty'])
        : legacyDifficulty is num
        ? _difficultyFromIndex(legacyDifficulty)
        : _difficultyFromQuestionValue(legacyDifficulty);

    // For legacy files, Question.fromJson would see the bank integer at the
    // 'difficulty' key. Restore the semantic Question difficulty explicitly.
    final questionJson = Map<String, dynamic>.from(json);
    if (legacyDifficulty is num) {
      questionJson['difficulty'] = bankDifficulty.questionDifficulty.name;
    }
    if (json['bankCreatedAt'] != null && json['createdAt'] == null) {
      questionJson['createdAt'] = json['bankCreatedAt'];
    }

    final parsed = Question.fromJson(questionJson);
    final subject = _firstNonEmpty(
      json['bankSubject']?.toString(),
      parsed.subject,
      json['subject']?.toString(),
      fallback: 'General',
    );
    final chapter = _firstNonEmpty(
      json['bankChapter']?.toString(),
      parsed.chapter,
      json['chapter']?.toString(),
      fallback: 'General',
    );
    final tags = _stringList(
      json.containsKey('bankTags') ? json['bankTags'] : json['tags'],
    );
    final normalized = parsed.copyWith(
      subject: subject,
      chapter: chapter,
      difficulty: bankDifficulty.questionDifficulty,
      tags: tags,
      modifiedAt: parsed.modifiedAt,
    );

    return QuestionBankQuestion(
      question: normalized,
      subject: subject,
      chapter: chapter,
      difficulty: bankDifficulty,
      tags: tags,
      isFavorite: json['isFavorite'] == true,
      createdAt:
          DateTime.tryParse(
            json['bankCreatedAt']?.toString() ??
                json['createdAt']?.toString() ??
                '',
          ) ??
          normalized.createdAt,
    );
  }
}

Difficulty _difficultyFromIndex(dynamic value) {
  final index = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (index == null || index < 0 || index >= Difficulty.values.length) {
    return Difficulty.medium;
  }
  return Difficulty.values[index];
}

Difficulty _difficultyFromQuestionValue(dynamic value) {
  final name = value?.toString();
  if (name != null) {
    for (final difficulty in QuestionDifficulty.values) {
      if (difficulty.name == name) {
        return difficulty.bankDifficulty;
      }
    }
  }
  return Difficulty.medium;
}

String _firstNonEmpty(
  String? first,
  String? second,
  String? third, {
  required String fallback,
}) {
  for (final value in [first, second, third]) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return fallback;
}

List<String> _stringList(dynamic value) {
  return (value as List? ?? const [])
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}
