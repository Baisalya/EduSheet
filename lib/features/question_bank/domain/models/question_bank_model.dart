import 'package:flutter/material.dart';
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
      'isOptional': question.isOptional,
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
        id: json['id']?.toString() ?? '',
        text: json['text']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString(),
        options: (json['options'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (o) => QuestionOption(
                id: o['id']?.toString() ?? '',
                text: o['text']?.toString() ?? '',
                isCorrect: o['isCorrect'] == true,
              ),
            )
            .toList(),
        type: _questionTypeFromIndex(json['type']),
        marks: (json['marks'] as num?)?.toDouble() ?? 1.0,
        alignment: _alignmentFromIndex(json['alignment']),
        isOptional: json['isOptional'] == true,
      ),
      subject: json['subject']?.toString() ?? 'General',
      chapter: json['chapter']?.toString() ?? 'General',
      difficulty: _difficultyFromIndex(json['difficulty']),
      tags: (json['tags'] as List? ?? const [])
          .map((tag) => tag.toString())
          .toList(),
      isFavorite: json['isFavorite'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

QuestionType _questionTypeFromIndex(dynamic value) {
  final index = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (index == null || index < 0 || index >= QuestionType.values.length) {
    return QuestionType.descriptive;
  }
  return QuestionType.values[index];
}

TextAlign _alignmentFromIndex(dynamic value) {
  final index = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (index == null || index < 0 || index >= TextAlign.values.length) {
    return TextAlign.left;
  }
  return TextAlign.values[index];
}

Difficulty _difficultyFromIndex(dynamic value) {
  final index = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (index == null || index < 0 || index >= Difficulty.values.length) {
    return Difficulty.medium;
  }
  return Difficulty.values[index];
}
