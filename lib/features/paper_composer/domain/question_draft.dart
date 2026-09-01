import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/question_option_layout.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'question_advanced_content.dart';
import 'question_details_draft.dart';

/// Editing model for the paper composer.
///
/// The persisted [Question] remains the storage contract. This draft only owns
/// fields that the focused question-writing workflow edits directly. Structural
/// content (options, attachments, tables, sub-questions and internal choices)
/// is owned explicitly so the Universal Smart Paper Editor can compose them
/// independently of the legacy [QuestionType]. The persisted [Question] remains
/// the compatibility/storage contract.
class QuestionDraft {
  final Question _seed;
  final String text;
  final QuestionType type;
  final double marks;
  final bool isOptional;
  final List<QuestionOption> options;
  final List<MathExpression> mathExpressions;
  final List<QuestionAttachment> attachments;
  final QuestionTable? tableData;
  final List<Question> subQuestions;
  final List<Question> internalChoices;
  final QuestionOptionLayout optionLayout;
  final QuestionAdvancedContent advancedContent;
  final QuestionDetailsDraft details;

  const QuestionDraft._({
    required Question seed,
    required this.text,
    required this.type,
    required this.marks,
    required this.isOptional,
    required this.options,
    required this.mathExpressions,
    required this.attachments,
    required this.tableData,
    required this.subQuestions,
    required this.internalChoices,
    required this.optionLayout,
    required this.advancedContent,
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
      attachments: const [],
      tableData: null,
      subQuestions: const [],
      internalChoices: const [],
      optionLayout: QuestionOptionLayout.vertical,
      advancedContent: QuestionAdvancedContent.empty,
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
      attachments: question.attachments.map((item) => item.copyWith()).toList(),
      tableData: _copyTable(question.tableData),
      subQuestions: List<Question>.from(question.subQuestions),
      internalChoices: List<Question>.from(question.internalChoices),
      optionLayout: QuestionOptionLayoutCodec.fromQuestion(question),
      advancedContent: QuestionAdvancedContent.fromQuestion(question),
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
    List<QuestionAttachment>? attachments,
    QuestionTable? tableData,
    bool clearTableData = false,
    List<Question>? subQuestions,
    List<Question>? internalChoices,
    QuestionOptionLayout? optionLayout,
    QuestionAdvancedContent? advancedContent,
    QuestionDetailsDraft? details,
  }) {
    return QuestionDraft._(
      seed: _seed,
      text: text ?? this.text,
      type: type ?? this.type,
      marks: marks ?? this.marks,
      isOptional: isOptional ?? this.isOptional,
      options: options ?? this.options,
      mathExpressions: mathExpressions ?? this.mathExpressions,
      attachments: attachments ?? this.attachments,
      tableData: clearTableData ? null : (tableData ?? this.tableData),
      subQuestions: subQuestions ?? this.subQuestions,
      internalChoices: internalChoices ?? this.internalChoices,
      optionLayout: optionLayout ?? this.optionLayout,
      advancedContent: advancedContent ?? this.advancedContent,
      details: details ?? this.details,
    );
  }

  /// Applies an optional quick-start helper without making QuestionType the
  /// owner of document structure. Existing content is never removed.
  QuestionDraft applyQuickStart(QuestionType nextType) {
    var nextOptions = options;
    if (nextType == QuestionType.trueFalse && nextOptions.isEmpty) {
      nextOptions = _defaultOptions(nextType);
    } else if (nextType.usesOptions && nextOptions.isEmpty) {
      nextOptions = _defaultOptions(nextType);
    }
    return copyWith(type: nextType, options: nextOptions);
  }

  /// Adds structured answer choices as a convenience while keeping the paper
  /// itself manual-first. The legacy type is updated only for answer semantics
  /// and export compatibility.
  QuestionDraft ensureAnswerOptions({bool multipleCorrect = false}) {
    if (options.isNotEmpty) return this;
    final nextType = multipleCorrect
        ? QuestionType.multipleSelect
        : QuestionType.mcq;
    return copyWith(type: nextType, options: _defaultOptions(nextType));
  }

  Question toQuestion({required String plainTextAccessibility}) {
    final now = DateTime.now();
    var metadata = Map<String, dynamic>.from(_seed.metadata)
      ..remove('paperComposerDraft');
    metadata = QuestionOptionLayoutCodec.write(metadata, optionLayout);
    metadata = advancedContent.writeToMetadata(metadata);

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
      instructionAlignment: details.instructionAlignment,
      sourceReference: details.sourceReference,
      mathExpressions: mathExpressions,
      attachments: attachments,
      tableData: tableData,
      subQuestions: subQuestions,
      internalChoices: internalChoices,
      modifiedAt: now,
      version: isExisting ? _seed.version + 1 : 1,
      status: QuestionStatus.complete,
      metadata: metadata,
      alignment: _seed.alignment,
    );
  }

  static QuestionTable? _copyTable(QuestionTable? table) {
    if (table == null) return null;
    return QuestionTable(
      headers: List<String>.from(table.headers),
      rows: table.rows.map((row) => List<String>.from(row)).toList(),
      caption: table.caption,
      accessibilitySummary: table.accessibilitySummary,
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
