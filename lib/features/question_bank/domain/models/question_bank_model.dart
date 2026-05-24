import '../../../editor/domain/models/paper_model.dart';

enum Difficulty { easy, medium, hard }

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

  QuestionBankQuestion copyWith({
    Question? question,
    String? subject,
    String? chapter,
    Difficulty? difficulty,
    List<String>? tags,
    bool? isFavorite,
    DateTime? createdAt,
  }) {
    return QuestionBankQuestion(
      question: question ?? this.question,
      subject: subject ?? this.subject,
      chapter: chapter ?? this.chapter,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': question.id,
      'text': question.text,
      'imageUrl': question.imageUrl,
      'options': question.options
          .map((o) => {'id': o.id, 'text': o.text, 'isCorrect': o.isCorrect})
          .toList(),
      'type': question.type.index,
      'marks': question.marks,
      'alignment': question.alignment.index,
      'subject': subject,
      'chapter': chapter,
      'difficulty': difficulty.index,
      'tags': tags,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory QuestionBankQuestion.fromJson(Map<String, dynamic> json) {
    return QuestionBankQuestion(
      question: Question(
        id: json['id'],
        text: json['text'],
        imageUrl: json['imageUrl'],
        options: (json['options'] as List)
            .map(
              (o) => QuestionOption(
                id: o['id'],
                text: o['text'],
                isCorrect: o['isCorrect'] ?? false,
              ),
            )
            .toList(),
        type: QuestionType.values[json['type'] ?? 1],
        marks: (json['marks'] as num?)?.toDouble() ?? 1.0,
        // alignment: TextAlign.values[json['alignment'] ?? 0], // Not easily accessible from core models sometimes, but let's assume it works
      ),
      subject: json['subject'],
      chapter: json['chapter'],
      difficulty: Difficulty.values[json['difficulty'] ?? 1],
      tags: List<String>.from(json['tags'] ?? []),
      isFavorite: json['isFavorite'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
