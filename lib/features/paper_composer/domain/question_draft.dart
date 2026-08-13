import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'question_details_draft.dart';

/// Editing model for the paper composer.
///
/// The persisted [Question] remains the storage contract. This draft only owns
/// fields that the focused question-writing workflow edits directly; every
/// other persisted field is preserved through [_seed].
class QuestionDraft {
  final Question _seed;
  final String text;
  final QuestionType type;
  final double marks;
  final bool isOptional;
  final List<QuestionOption> options;
  final List<MathExpression> mathExpressions;
  final QuestionDetailsDraft details;

  const QuestionDraft._({
    required Question seed,
    required this.text,
    required this.type,
    required this.marks,
    required this.isOptional,
    required this.options,
    required this.mathExpressions,
    required this.details,
  }) : _seed = seed;

  String get id => _seed.id;

  bool get isExisting => _seed.metadata['paperComposerDraft'] != true;

  factory QuestionDraft.create({
    QuestionType type = QuestionType.descriptive,
    double marks = 1,
    bool isOptional = false,
  }) {
    final now = DateTime.now();
    final seed = Question(
      id: const Uuid().v4(),
      text: '',
      type: type,
      marks: marks,
      isOptional: isOptional,
      status: QuestionStatus.draft,
      createdAt: now,
      modifiedAt: now,
      metadata: const {'paperComposerDraft': true},
    );
    return QuestionDraft._(
      seed: seed,
      text: '',
      type: type,
      marks: marks,
      isOptional: isOptional,
      options: _defaultOptions(type),
      mathExpressions: const [],
      details: const QuestionDetailsDraft(),
    );
  }

  factory QuestionDraft.fromQuestion(Question question) {
    return QuestionDraft._(
      seed: question,
      text: question.text,
      type: question.type,
      marks: question.marks,
      isOptional: question.isOptional,
      options: question.options.map((item) => item.copyWith()).toList(),
      mathExpressions: question.mathExpressions
          .map((item) => item.copyWith())
          .toList(),
      details: QuestionDetailsDraft.fromQuestion(question),
    );
  }

  QuestionDraft copyWith({
    String? text,
    QuestionType? type,
    double? marks,
    bool? isOptional,
    List<QuestionOption>? options,
    List<MathExpression>? mathExpressions,
    QuestionDetailsDraft? details,
  }) {
    final nextType = type ?? this.type;
    var nextOptions = options ?? this.options;
    if (type != null && type != this.type) {
      if (!nextType.usesOptions) {
        nextOptions = const [];
      } else if (nextType == QuestionType.trueFalse ||
          this.type == QuestionType.trueFalse ||
          nextOptions.isEmpty) {
        // True/False has fixed semantic choices. Leaving it should also create
        // fresh generic choices rather than carrying "True"/"False" into MCQ.
        nextOptions = _defaultOptions(nextType);
      }
    }

    return QuestionDraft._(
      seed: _seed,
      text: text ?? this.text,
      type: nextType,
      marks: marks ?? this.marks,
      isOptional: isOptional ?? this.isOptional,
      options: nextOptions,
      mathExpressions: mathExpressions ?? this.mathExpressions,
      details: details ?? this.details,
    );
  }

  Question toQuestion({required String plainTextAccessibility}) {
    final now = DateTime.now();
    final metadata = Map<String, dynamic>.from(_seed.metadata)
      ..remove('paperComposerDraft');

    return _seed.copyWith(
      text: text,
      richTextFormat: 'quill-delta-json-v1',
      plainTextAccessibility: plainTextAccessibility,
      type: type,
      marks: marks,
      options: options,
      isOptional: isOptional,
      negativeMarks: details.negativeMarks,
      correctAnswer: details.correctAnswer,
      explanation: details.explanation,
      estimatedAnswerMinutes: details.estimatedAnswerMinutes,
      clearEstimatedAnswerMinutes: details.estimatedAnswerMinutes == null,
      difficulty: details.difficulty,
      grade: details.grade,
      subject: details.subject,
      chapter: details.chapter,
      topic: details.topic,
      learningObjective: details.learningObjective,
      cognitiveLevel: details.cognitiveLevel,
      tags: details.tags,
      language: details.language,
      instructions: details.instructions,
      sourceReference: details.sourceReference,
      mathExpressions: mathExpressions,
      modifiedAt: now,
      version: isExisting ? _seed.version + 1 : 1,
      status: QuestionStatus.complete,
      metadata: metadata,
      alignment: _seed.alignment,
    );
  }

  static List<QuestionOption> _defaultOptions(QuestionType type) {
    if (!type.usesOptions) return const [];
    if (type == QuestionType.trueFalse) {
      return [
        QuestionOption(id: const Uuid().v4(), text: 'True'),
        QuestionOption(id: const Uuid().v4(), text: 'False'),
      ];
    }
    return List.generate(
      4,
      (_) => QuestionOption(id: const Uuid().v4(), text: ''),
    );
  }
}

extension QuestionDraftQuestionType on QuestionType {
  IconData get composerIcon {
    switch (this) {
      case QuestionType.mcq:
      case QuestionType.multipleSelect:
        return Icons.checklist_rounded;
      case QuestionType.trueFalse:
        return Icons.rule_rounded;
      case QuestionType.fillInTheBlanks:
        return Icons.space_bar_rounded;
      case QuestionType.numerical:
      case QuestionType.mathematicalExpression:
        return Icons.calculate_outlined;
      case QuestionType.imageOrDiagram:
        return Icons.category_outlined;
      case QuestionType.table:
        return Icons.table_chart_outlined;
      case QuestionType.subQuestions:
      case QuestionType.internalChoice:
      case QuestionType.caseStudy:
      case QuestionType.passage:
        return Icons.account_tree_outlined;
      case QuestionType.assertionReason:
        return Icons.psychology_alt_outlined;
      case QuestionType.matching:
        return Icons.compare_arrows_rounded;
      case QuestionType.oneWord:
      case QuestionType.shortAnswer:
      case QuestionType.longAnswer:
      case QuestionType.descriptive:
      case QuestionType.custom:
        return Icons.edit_note_rounded;
    }
  }
}
