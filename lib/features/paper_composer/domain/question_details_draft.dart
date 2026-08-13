import 'package:edusheet/features/editor/domain/models/paper_model.dart';

/// Advanced question metadata kept out of the primary writing surface.
///
/// This maps one-to-one to fields already persisted by [Question]. It does not
/// introduce a new storage format; it only gives the focused composer a clean
/// editing boundary for details teachers use less frequently.
class QuestionDetailsDraft {
  final double negativeMarks;
  final String correctAnswer;
  final String explanation;
  final int? estimatedAnswerMinutes;
  final QuestionDifficulty difficulty;
  final String grade;
  final String subject;
  final String chapter;
  final String topic;
  final String learningObjective;
  final CognitiveLevel cognitiveLevel;
  final List<String> tags;
  final String language;
  final String instructions;
  final String sourceReference;

  const QuestionDetailsDraft({
    this.negativeMarks = 0,
    this.correctAnswer = '',
    this.explanation = '',
    this.estimatedAnswerMinutes,
    this.difficulty = QuestionDifficulty.medium,
    this.grade = '',
    this.subject = '',
    this.chapter = '',
    this.topic = '',
    this.learningObjective = '',
    this.cognitiveLevel = CognitiveLevel.unspecified,
    this.tags = const [],
    this.language = 'en',
    this.instructions = '',
    this.sourceReference = '',
  });

  factory QuestionDetailsDraft.fromQuestion(Question question) {
    return QuestionDetailsDraft(
      negativeMarks: question.negativeMarks,
      correctAnswer: question.correctAnswer,
      explanation: question.explanation,
      estimatedAnswerMinutes: question.estimatedAnswerMinutes,
      difficulty: question.difficulty,
      grade: question.grade,
      subject: question.subject,
      chapter: question.chapter,
      topic: question.topic,
      learningObjective: question.learningObjective,
      cognitiveLevel: question.cognitiveLevel,
      tags: List<String>.from(question.tags),
      language: question.language,
      instructions: question.instructions,
      sourceReference: question.sourceReference,
    );
  }

  QuestionDetailsDraft copyWith({
    double? negativeMarks,
    String? correctAnswer,
    String? explanation,
    int? estimatedAnswerMinutes,
    bool clearEstimatedAnswerMinutes = false,
    QuestionDifficulty? difficulty,
    String? grade,
    String? subject,
    String? chapter,
    String? topic,
    String? learningObjective,
    CognitiveLevel? cognitiveLevel,
    List<String>? tags,
    String? language,
    String? instructions,
    String? sourceReference,
  }) {
    return QuestionDetailsDraft(
      negativeMarks: negativeMarks ?? this.negativeMarks,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
      estimatedAnswerMinutes: clearEstimatedAnswerMinutes
          ? null
          : (estimatedAnswerMinutes ?? this.estimatedAnswerMinutes),
      difficulty: difficulty ?? this.difficulty,
      grade: grade ?? this.grade,
      subject: subject ?? this.subject,
      chapter: chapter ?? this.chapter,
      topic: topic ?? this.topic,
      learningObjective: learningObjective ?? this.learningObjective,
      cognitiveLevel: cognitiveLevel ?? this.cognitiveLevel,
      tags: tags ?? this.tags,
      language: language ?? this.language,
      instructions: instructions ?? this.instructions,
      sourceReference: sourceReference ?? this.sourceReference,
    );
  }

  bool get hasTeacherDetails {
    return negativeMarks > 0 ||
        correctAnswer.trim().isNotEmpty ||
        explanation.trim().isNotEmpty ||
        estimatedAnswerMinutes != null ||
        difficulty != QuestionDifficulty.medium ||
        grade.trim().isNotEmpty ||
        subject.trim().isNotEmpty ||
        chapter.trim().isNotEmpty ||
        topic.trim().isNotEmpty ||
        learningObjective.trim().isNotEmpty ||
        cognitiveLevel != CognitiveLevel.unspecified ||
        tags.isNotEmpty ||
        (language.trim().isNotEmpty && language.trim() != 'en') ||
        instructions.trim().isNotEmpty ||
        sourceReference.trim().isNotEmpty;
  }
}
