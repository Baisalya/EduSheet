import 'dart:convert';

import 'package:flutter/material.dart';

import 'math_expression.dart';
import 'paper_page_layout.dart';

/// Values 0-2 are persisted by legacy releases. Never reorder them.
enum QuestionType {
  mcq,
  descriptive,
  fillInTheBlanks,
  multipleSelect,
  trueFalse,
  oneWord,
  shortAnswer,
  longAnswer,
  numerical,
  mathematicalExpression,
  assertionReason,
  matching,
  passage,
  subQuestions,
  imageOrDiagram,
  table,
  internalChoice,
  caseStudy,
  custom,
}

extension QuestionTypeProperties on QuestionType {
  String get label {
    switch (this) {
      case QuestionType.mcq:
        return 'Multiple choice';
      case QuestionType.descriptive:
        return 'Descriptive';
      case QuestionType.fillInTheBlanks:
        return 'Fill in the blank';
      case QuestionType.multipleSelect:
        return 'Multiple select';
      case QuestionType.trueFalse:
        return 'True or false';
      case QuestionType.oneWord:
        return 'One-word answer';
      case QuestionType.shortAnswer:
        return 'Short answer';
      case QuestionType.longAnswer:
        return 'Long answer';
      case QuestionType.numerical:
        return 'Numerical';
      case QuestionType.mathematicalExpression:
        return 'Mathematical expression';
      case QuestionType.assertionReason:
        return 'Assertion and reason';
      case QuestionType.matching:
        return 'Matching';
      case QuestionType.passage:
        return 'Passage / comprehension';
      case QuestionType.subQuestions:
        return 'Question with parts';
      case QuestionType.imageOrDiagram:
        return 'Image or diagram';
      case QuestionType.table:
        return 'Table question';
      case QuestionType.internalChoice:
        return 'Internal choice';
      case QuestionType.caseStudy:
        return 'Case study';
      case QuestionType.custom:
        return 'Custom';
    }
  }

  bool get usesOptions {
    return this == QuestionType.mcq ||
        this == QuestionType.multipleSelect ||
        this == QuestionType.trueFalse ||
        this == QuestionType.assertionReason ||
        this == QuestionType.matching;
  }

  bool get allowsMultipleCorrect {
    return this == QuestionType.multipleSelect || this == QuestionType.matching;
  }
}

enum QuestionDifficulty { easy, medium, hard }

enum CognitiveLevel {
  remember,
  understand,
  apply,
  analyse,
  evaluate,
  create,
  unspecified,
}

enum QuestionStatus { draft, complete }

enum QuestionAttachmentKind { image, diagram, file }

enum QuestionNumberStyle {
  number,
  lowerAlpha,
  upperAlpha,
  lowerRoman,
  upperRoman,
  hindiDigits,
  odiaDigits,
  englishWords,
  hindiLetters,
  odiaLetters,
  custom,
}

class Paper {
  final String id;
  final String title;
  final String schoolName;
  final String instruction;
  final List<String> logos;
  final List<PaperHeaderField> headerFields;
  final Map<String, String> customHeaderValues;
  final List<PaperSection> sections;
  final bool includeOmr;
  final String templateId;
  final QuestionNumberStyle questionNumberStyle;
  final List<String> customQuestionNumberLabels;
  final DateTime createdAt;
  final double? maximumMarks;
  final bool includeCoverPage;
  final String headerText;
  final String footerText;
  final bool showPageNumbers;
  final PaperPageLayout pageLayout;

  Paper({
    required this.id,
    required this.title,
    this.schoolName = 'My School',
    this.instruction = '',
    this.logos = const [],
    this.headerFields = const [],
    this.customHeaderValues = const {},
    this.sections = const [],
    this.includeOmr = false,
    this.templateId = 'school_formal',
    this.questionNumberStyle = QuestionNumberStyle.number,
    this.customQuestionNumberLabels = const [],
    this.maximumMarks,
    this.includeCoverPage = false,
    this.headerText = '',
    this.footerText = '',
    this.showPageNumbers = true,
    this.pageLayout = PaperPageLayout.defaults,
    required this.createdAt,
  });

  Paper copyWith({
    String? id,
    String? title,
    String? schoolName,
    String? instruction,
    List<String>? logos,
    List<PaperHeaderField>? headerFields,
    Map<String, String>? customHeaderValues,
    List<PaperSection>? sections,
    bool? includeOmr,
    String? templateId,
    QuestionNumberStyle? questionNumberStyle,
    List<String>? customQuestionNumberLabels,
    double? maximumMarks,
    bool clearMaximumMarks = false,
    bool? includeCoverPage,
    String? headerText,
    String? footerText,
    bool? showPageNumbers,
    PaperPageLayout? pageLayout,
    DateTime? createdAt,
  }) {
    return Paper(
      id: id ?? this.id,
      title: title ?? this.title,
      schoolName: schoolName ?? this.schoolName,
      instruction: instruction ?? this.instruction,
      logos: logos ?? this.logos,
      headerFields: headerFields ?? this.headerFields,
      customHeaderValues: customHeaderValues ?? this.customHeaderValues,
      sections: sections ?? this.sections,
      includeOmr: includeOmr ?? this.includeOmr,
      templateId: templateId ?? this.templateId,
      questionNumberStyle: questionNumberStyle ?? this.questionNumberStyle,
      customQuestionNumberLabels:
          customQuestionNumberLabels ?? this.customQuestionNumberLabels,
      maximumMarks: clearMaximumMarks
          ? null
          : (maximumMarks ?? this.maximumMarks),
      includeCoverPage: includeCoverPage ?? this.includeCoverPage,
      headerText: headerText ?? this.headerText,
      footerText: footerText ?? this.footerText,
      showPageNumbers: showPageNumbers ?? this.showPageNumbers,
      pageLayout: pageLayout ?? this.pageLayout,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  double get totalMarks {
    return sections.fold(0.0, (sum, section) => sum + section.totalMarks);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'schoolName': schoolName,
      'instruction': instruction,
      'logos': logos,
      'headerFields': headerFields.map((f) => f.toJson()).toList(),
      'customHeaderValues': customHeaderValues,
      'sections': sections.map((s) => s.toJson()).toList(),
      'includeOmr': includeOmr,
      'templateId': templateId,
      'questionNumberStyle': questionNumberStyle.index,
      'customQuestionNumberLabels': customQuestionNumberLabels,
      'maximumMarks': maximumMarks,
      'includeCoverPage': includeCoverPage,
      'headerText': headerText,
      'footerText': footerText,
      'showPageNumbers': showPageNumbers,
      'pageLayout': pageLayout.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Paper.fromJson(Map<String, dynamic> json) {
    final questionNumberStyleIndex = json['questionNumberStyle'];
    return Paper(
      id: json['id'],
      title: json['title'],
      schoolName: json['schoolName'] ?? 'My School',
      instruction: json['instruction'] ?? '',
      logos: (json['logos'] as List?)?.cast<String>() ?? [],
      headerFields:
          (json['headerFields'] as List?)
              ?.map((f) => PaperHeaderField.fromJson(f))
              .toList() ??
          [],
      customHeaderValues:
          (json['customHeaderValues'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          {},
      sections:
          (json['sections'] as List?)
              ?.map((s) => PaperSection.fromJson(s))
              .toList() ??
          [],
      includeOmr: json['includeOmr'] ?? false,
      templateId: json['templateId'] ?? 'school_formal',
      questionNumberStyle:
          questionNumberStyleIndex is int &&
              questionNumberStyleIndex >= 0 &&
              questionNumberStyleIndex < QuestionNumberStyle.values.length
          ? QuestionNumberStyle.values[questionNumberStyleIndex]
          : QuestionNumberStyle.number,
      customQuestionNumberLabels:
          (json['customQuestionNumberLabels'] as List?)
              ?.map((label) => label.toString())
              .toList() ??
          const [],
      maximumMarks: (json['maximumMarks'] as num?)?.toDouble(),
      includeCoverPage: json['includeCoverPage'] == true,
      headerText: json['headerText']?.toString() ?? '',
      footerText: json['footerText']?.toString() ?? '',
      showPageNumbers: json['showPageNumbers'] != false,
      pageLayout: json['pageLayout'] is Map
          ? PaperPageLayout.fromJson(
              Map<String, dynamic>.from(json['pageLayout'] as Map),
            )
          : PaperPageLayout.defaults,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

class PaperHeaderField {
  final String id;
  final String label;
  final String value;
  final bool isPlaceholder;

  PaperHeaderField({
    required this.id,
    required this.label,
    this.value = '',
    this.isPlaceholder = false,
  });

  PaperHeaderField copyWith({
    String? id,
    String? label,
    String? value,
    bool? isPlaceholder,
  }) {
    return PaperHeaderField(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'value': value,
      'isPlaceholder': isPlaceholder,
    };
  }

  factory PaperHeaderField.fromJson(Map<String, dynamic> json) {
    return PaperHeaderField(
      id: json['id'],
      label: json['label'],
      value: json['value'] ?? '',
      isPlaceholder: json['isPlaceholder'] ?? false,
    );
  }
}

class PaperSection {
  final String id;
  final String title;
  final String? instruction;
  final String prefix;
  final List<Question> questions;
  final int? requiredCount;
  final bool showTitle;
  final bool showDivider;
  final QuestionNumberStyle? numberingStyle;
  final double? defaultMarks;
  final bool pageBreakBefore;
  final bool keepTogether;
  final int answerSpaceLines;
  final bool ruledAnswerArea;
  final bool graphAnswerArea;

  PaperSection({
    required this.id,
    required this.title,
    this.instruction,
    this.prefix = '',
    this.questions = const [],
    this.requiredCount,
    this.showTitle = true,
    this.showDivider = true,
    this.numberingStyle,
    this.defaultMarks,
    this.pageBreakBefore = false,
    this.keepTogether = true,
    this.answerSpaceLines = 0,
    this.ruledAnswerArea = false,
    this.graphAnswerArea = false,
  });

  PaperSection copyWith({
    String? id,
    String? title,
    String? instruction,
    String? prefix,
    List<Question>? questions,
    int? requiredCount,
    bool clearRequiredCount = false,
    bool? showTitle,
    bool? showDivider,
    QuestionNumberStyle? numberingStyle,
    bool clearNumberingStyle = false,
    double? defaultMarks,
    bool clearDefaultMarks = false,
    bool? pageBreakBefore,
    bool? keepTogether,
    int? answerSpaceLines,
    bool? ruledAnswerArea,
    bool? graphAnswerArea,
  }) {
    return PaperSection(
      id: id ?? this.id,
      title: title ?? this.title,
      instruction: instruction ?? this.instruction,
      prefix: prefix ?? this.prefix,
      questions: questions ?? this.questions,
      requiredCount: clearRequiredCount
          ? null
          : (requiredCount ?? this.requiredCount),
      showTitle: showTitle ?? this.showTitle,
      showDivider: showDivider ?? this.showDivider,
      numberingStyle: clearNumberingStyle
          ? null
          : (numberingStyle ?? this.numberingStyle),
      defaultMarks: clearDefaultMarks
          ? null
          : (defaultMarks ?? this.defaultMarks),
      pageBreakBefore: pageBreakBefore ?? this.pageBreakBefore,
      keepTogether: keepTogether ?? this.keepTogether,
      answerSpaceLines: answerSpaceLines ?? this.answerSpaceLines,
      ruledAnswerArea: ruledAnswerArea ?? this.ruledAnswerArea,
      graphAnswerArea: graphAnswerArea ?? this.graphAnswerArea,
    );
  }

  double get totalMarks {
    if (questions.isEmpty) return 0.0;

    // Filter out questions explicitly marked as optional
    final nonOptionalQuestions = questions
        .where((q) => !q.isOptional && !q.isWordContentBlock)
        .toList();

    if (requiredCount == null ||
        requiredCount! >= nonOptionalQuestions.length) {
      return nonOptionalQuestions.fold(0.0, (sum, q) => sum + q.marks);
    }

    // If there's a requiredCount, we usually assume the student picks the ones with most marks
    // to determine the maximum possible marks for the section.
    final sortedMarks = nonOptionalQuestions.map((q) => q.marks).toList()
      ..sort((a, b) => b.compareTo(a));
    return sortedMarks.take(requiredCount!).fold(0.0, (sum, m) => sum + m);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'instruction': instruction,
      'prefix': prefix,
      'questions': questions.map((q) => q.toJson()).toList(),
      'requiredCount': requiredCount,
      'showTitle': showTitle,
      'showDivider': showDivider,
      'numberingStyle': numberingStyle?.name,
      'defaultMarks': defaultMarks,
      'pageBreakBefore': pageBreakBefore,
      'keepTogether': keepTogether,
      'answerSpaceLines': answerSpaceLines,
      'ruledAnswerArea': ruledAnswerArea,
      'graphAnswerArea': graphAnswerArea,
    };
  }

  factory PaperSection.fromJson(Map<String, dynamic> json) {
    return PaperSection(
      id: json['id'],
      title: json['title'],
      instruction: json['instruction'],
      prefix: json['prefix'] ?? '',
      questions:
          (json['questions'] as List?)
              ?.map((q) => Question.fromJson(q))
              .toList() ??
          [],
      requiredCount: json['requiredCount'],
      showTitle: json['showTitle'] ?? true,
      showDivider: json['showDivider'] ?? true,
      numberingStyle: json['numberingStyle'] == null
          ? null
          : _enumByName(
              QuestionNumberStyle.values,
              json['numberingStyle'],
              QuestionNumberStyle.number,
            ),
      defaultMarks: (json['defaultMarks'] as num?)?.toDouble(),
      pageBreakBefore: json['pageBreakBefore'] == true,
      keepTogether: json['keepTogether'] != false,
      answerSpaceLines: (json['answerSpaceLines'] as num?)?.toInt() ?? 0,
      ruledAnswerArea: json['ruledAnswerArea'] == true,
      graphAnswerArea: json['graphAnswerArea'] == true,
    );
  }
}

class QuestionOption {
  final String id;
  final String text;
  final bool isCorrect;

  QuestionOption({
    required this.id,
    required this.text,
    this.isCorrect = false,
  });

  QuestionOption copyWith({String? id, String? text, bool? isCorrect}) {
    return QuestionOption(
      id: id ?? this.id,
      text: text ?? this.text,
      isCorrect: isCorrect ?? this.isCorrect,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'text': text, 'isCorrect': isCorrect};
  }

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      id: json['id'],
      text: json['text'],
      isCorrect: json['isCorrect'] ?? false,
    );
  }
}

class QuestionAttachment {
  final String id;
  final QuestionAttachmentKind kind;
  final String path;
  final String alternativeText;
  final String caption;
  final String? mimeType;
  final double? width;
  final double? height;

  const QuestionAttachment({
    required this.id,
    required this.kind,
    required this.path,
    required this.alternativeText,
    this.caption = '',
    this.mimeType,
    this.width,
    this.height,
  });

  QuestionAttachment copyWith({
    String? id,
    QuestionAttachmentKind? kind,
    String? path,
    String? alternativeText,
    String? caption,
    String? mimeType,
    double? width,
    double? height,
  }) {
    return QuestionAttachment(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      path: path ?? this.path,
      alternativeText: alternativeText ?? this.alternativeText,
      caption: caption ?? this.caption,
      mimeType: mimeType ?? this.mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      'path': path,
      'alternativeText': alternativeText,
      'caption': caption,
      'mimeType': mimeType,
      'width': width,
      'height': height,
    };
  }

  factory QuestionAttachment.fromJson(Map<String, dynamic> json) {
    return QuestionAttachment(
      id: json['id']?.toString() ?? '',
      kind: _enumByName(
        QuestionAttachmentKind.values,
        json['kind'],
        QuestionAttachmentKind.image,
      ),
      path: json['path']?.toString() ?? '',
      alternativeText:
          json['alternativeText']?.toString() ??
          json['altText']?.toString() ??
          '',
      caption: json['caption']?.toString() ?? '',
      mimeType: json['mimeType']?.toString(),
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
    );
  }
}

class QuestionTable {
  final List<String> headers;
  final List<List<String>> rows;
  final String caption;
  final String accessibilitySummary;

  const QuestionTable({
    this.headers = const [],
    this.rows = const [],
    this.caption = '',
    this.accessibilitySummary = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'headers': headers,
      'rows': rows,
      'caption': caption,
      'accessibilitySummary': accessibilitySummary,
    };
  }

  factory QuestionTable.fromJson(Map<String, dynamic> json) {
    return QuestionTable(
      headers: _stringList(json['headers']),
      rows: (json['rows'] as List? ?? const [])
          .whereType<List>()
          .map((row) => row.map((cell) => cell.toString()).toList())
          .toList(),
      caption: json['caption']?.toString() ?? '',
      accessibilitySummary: json['accessibilitySummary']?.toString() ?? '',
    );
  }
}

class Question {
  final String id;
  final String text;
  final String richTextFormat;
  final String plainTextAccessibility;
  final String? imageUrl;
  final List<QuestionOption> options;
  final QuestionType type;
  final double marks;
  final double negativeMarks;
  final TextAlign alignment;
  final bool isOptional;
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
  final List<MathExpression> mathExpressions;
  final List<QuestionAttachment> attachments;
  final QuestionTable? tableData;
  final List<Question> subQuestions;
  final List<Question> internalChoices;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final int version;
  final QuestionStatus status;
  final Map<String, dynamic> metadata;

  Question({
    required this.id,
    required this.text,
    this.richTextFormat = 'quill-delta-json-v1',
    String? plainTextAccessibility,
    this.imageUrl,
    this.options = const [],
    this.type = QuestionType.descriptive,
    this.marks = 1.0,
    this.negativeMarks = 0,
    this.alignment = TextAlign.left,
    this.isOptional = false,
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
    this.mathExpressions = const [],
    this.attachments = const [],
    this.tableData,
    this.subQuestions = const [],
    this.internalChoices = const [],
    DateTime? createdAt,
    DateTime? modifiedAt,
    this.version = 1,
    this.status = QuestionStatus.complete,
    this.metadata = const {},
  }) : plainTextAccessibility =
           plainTextAccessibility?.trim().isNotEmpty == true
           ? plainTextAccessibility!.trim()
           : _plainTextFromRich(text),
       createdAt = createdAt ?? DateTime.now(),
       modifiedAt = modifiedAt ?? createdAt ?? DateTime.now();

  static const String wordContentBlockKindMetadataKey =
      'edusheet.wordContentBlockKind';
  static const String wordContentBlockVersionMetadataKey =
      'edusheet.wordContentBlockVersion';

  /// Word Mode can persist free-form paragraphs/tables/images without
  /// introducing a second paper schema by storing them as non-assessment
  /// custom content blocks. Smart Mode, preview and exporters use this marker
  /// to preserve the block while excluding it from numbering and marks.
  bool get isWordContentBlock =>
      metadata[wordContentBlockKindMetadataKey]?.toString().trim().isNotEmpty ==
      true;

  String? get wordContentBlockKind {
    final value = metadata[wordContentBlockKindMetadataKey]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  Question copyWith({
    String? id,
    String? text,
    String? richTextFormat,
    String? plainTextAccessibility,
    String? imageUrl,
    bool clearImageUrl = false,
    List<QuestionOption>? options,
    QuestionType? type,
    double? marks,
    double? negativeMarks,
    TextAlign? alignment,
    bool? isOptional,
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
    List<MathExpression>? mathExpressions,
    List<QuestionAttachment>? attachments,
    QuestionTable? tableData,
    bool clearTableData = false,
    List<Question>? subQuestions,
    List<Question>? internalChoices,
    DateTime? createdAt,
    DateTime? modifiedAt,
    int? version,
    QuestionStatus? status,
    Map<String, dynamic>? metadata,
  }) {
    return Question(
      id: id ?? this.id,
      text: text ?? this.text,
      richTextFormat: richTextFormat ?? this.richTextFormat,
      plainTextAccessibility:
          plainTextAccessibility ??
          (text == null ? this.plainTextAccessibility : null),
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      options: options ?? this.options,
      type: type ?? this.type,
      marks: marks ?? this.marks,
      negativeMarks: negativeMarks ?? this.negativeMarks,
      alignment: alignment ?? this.alignment,
      isOptional: isOptional ?? this.isOptional,
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
      mathExpressions: mathExpressions ?? this.mathExpressions,
      attachments: attachments ?? this.attachments,
      tableData: clearTableData ? null : (tableData ?? this.tableData),
      subQuestions: subQuestions ?? this.subQuestions,
      internalChoices: internalChoices ?? this.internalChoices,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? DateTime.now(),
      version: version ?? this.version,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'richTextFormat': richTextFormat,
      'plainTextAccessibility': plainTextAccessibility,
      'imageUrl': imageUrl,
      'options': options.map((o) => o.toJson()).toList(),
      'type': type.index,
      'typeName': type.name,
      'marks': marks,
      'negativeMarks': negativeMarks,
      'alignment': alignment.index,
      'isOptional': isOptional,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'estimatedAnswerMinutes': estimatedAnswerMinutes,
      'difficulty': difficulty.name,
      'grade': grade,
      'subject': subject,
      'chapter': chapter,
      'topic': topic,
      'learningObjective': learningObjective,
      'cognitiveLevel': cognitiveLevel.name,
      'tags': tags,
      'language': language,
      'instructions': instructions,
      'sourceReference': sourceReference,
      'mathExpressions': mathExpressions.map((item) => item.toJson()).toList(),
      'attachments': attachments.map((item) => item.toJson()).toList(),
      'tableData': tableData?.toJson(),
      'subQuestions': subQuestions.map((item) => item.toJson()).toList(),
      'internalChoices': internalChoices.map((item) => item.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'version': version,
      'status': status.name,
      'metadata': metadata,
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? now;
    return Question(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      richTextFormat:
          json['richTextFormat']?.toString() ?? 'quill-delta-json-v1',
      plainTextAccessibility: json['plainTextAccessibility']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      options:
          (json['options'] as List?)
              ?.whereType<Map>()
              .map((o) => QuestionOption.fromJson(Map<String, dynamic>.from(o)))
              .toList() ??
          [],
      type: _questionTypeFromJson(json),
      marks: (json['marks'] as num?)?.toDouble() ?? 1.0,
      negativeMarks: (json['negativeMarks'] as num?)?.toDouble() ?? 0,
      alignment: _enumByIndex(
        TextAlign.values,
        json['alignment'],
        TextAlign.left,
      ),
      isOptional: json['isOptional'] ?? false,
      correctAnswer: json['correctAnswer']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
      estimatedAnswerMinutes: (json['estimatedAnswerMinutes'] as num?)?.toInt(),
      difficulty: _enumByName(
        QuestionDifficulty.values,
        json['difficulty'],
        QuestionDifficulty.medium,
      ),
      grade: json['grade']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      chapter: json['chapter']?.toString() ?? '',
      topic: json['topic']?.toString() ?? '',
      learningObjective: json['learningObjective']?.toString() ?? '',
      cognitiveLevel: _enumByName(
        CognitiveLevel.values,
        json['cognitiveLevel'],
        CognitiveLevel.unspecified,
      ),
      tags: _stringList(json['tags']),
      language: json['language']?.toString() ?? 'en',
      instructions: json['instructions']?.toString() ?? '',
      sourceReference: json['sourceReference']?.toString() ?? '',
      mathExpressions: _modelList(
        json['mathExpressions'],
        MathExpression.fromJson,
      ),
      attachments: _modelList(json['attachments'], QuestionAttachment.fromJson),
      tableData: json['tableData'] is Map
          ? QuestionTable.fromJson(
              Map<String, dynamic>.from(json['tableData'] as Map),
            )
          : null,
      subQuestions: _modelList(json['subQuestions'], Question.fromJson),
      internalChoices: _modelList(json['internalChoices'], Question.fromJson),
      createdAt: createdAt,
      modifiedAt:
          DateTime.tryParse(json['modifiedAt']?.toString() ?? '') ?? createdAt,
      version: (json['version'] as num?)?.toInt() ?? 1,
      status: _enumByName(
        QuestionStatus.values,
        json['status'],
        QuestionStatus.complete,
      ),
      metadata: _dynamicMap(json['metadata']),
    );
  }
}

QuestionType _questionTypeFromJson(Map<String, dynamic> json) {
  final name = json['typeName']?.toString();
  if (name != null) {
    for (final value in QuestionType.values) {
      if (value.name == name) return value;
    }
  }
  return _enumByIndex(
    QuestionType.values,
    json['type'],
    QuestionType.descriptive,
  );
}

T _enumByIndex<T>(List<T> values, dynamic raw, T fallback) {
  final index = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
  if (index == null || index < 0 || index >= values.length) return fallback;
  return values[index];
}

T _enumByName<T extends Enum>(List<T> values, dynamic raw, T fallback) {
  final name = raw?.toString();
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

List<T> _modelList<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
  return (raw as List? ?? const [])
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

List<String> _stringList(dynamic raw) {
  return (raw as List? ?? const []).map((item) => item.toString()).toList();
}

Map<String, dynamic> _dynamicMap(dynamic raw) {
  if (raw is! Map) return const {};
  return raw.map((key, value) => MapEntry(key.toString(), value));
}

String _plainTextFromRich(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is List) {
      final buffer = StringBuffer();
      for (final operation in decoded.whereType<Map>()) {
        final insert = operation['insert'];
        if (insert is String) {
          buffer.write(insert);
        } else if (insert is Map) {
          if (insert.containsKey('geometry')) buffer.write('[diagram]');
          if (insert.containsKey(MathExpression.quillEmbedKey)) {
            final expression = MathExpression.tryFromQuillEmbedData(
              insert[MathExpression.quillEmbedKey],
            );
            if (expression != null) {
              final plain = expression.plainText.trim();
              buffer.write(plain.isEmpty ? expression.latex : plain);
            } else {
              buffer.write('[formula]');
            }
          }
        }
      }
      final plain = buffer.toString().trim();
      if (plain.isNotEmpty) return plain;
    }
  } catch (_) {
    // Legacy plain text is a valid fallback; never reject it as malformed rich text.
  }
  return trimmed
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}
