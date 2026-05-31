import 'package:flutter/material.dart';

enum QuestionType { mcq, descriptive, fillInTheBlanks }

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

  PaperSection({
    required this.id,
    required this.title,
    this.instruction,
    this.prefix = '',
    this.questions = const [],
    this.requiredCount,
    this.showTitle = true,
    this.showDivider = true,
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
    );
  }

  double get totalMarks {
    if (questions.isEmpty) return 0.0;

    // Filter out questions explicitly marked as optional
    final nonOptionalQuestions = questions.where((q) => !q.isOptional).toList();

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

class Question {
  final String id;
  final String text; // Rich text / HTML
  final String? imageUrl;
  final List<QuestionOption> options;
  final QuestionType type;
  final double marks;
  final TextAlign alignment;
  final bool isOptional;

  Question({
    required this.id,
    required this.text,
    this.imageUrl,
    this.options = const [],
    this.type = QuestionType.descriptive,
    this.marks = 1.0,
    this.alignment = TextAlign.left,
    this.isOptional = false,
  });

  Question copyWith({
    String? id,
    String? text,
    String? imageUrl,
    List<QuestionOption>? options,
    QuestionType? type,
    double? marks,
    TextAlign? alignment,
    bool? isOptional,
  }) {
    return Question(
      id: id ?? this.id,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      options: options ?? this.options,
      type: type ?? this.type,
      marks: marks ?? this.marks,
      alignment: alignment ?? this.alignment,
      isOptional: isOptional ?? this.isOptional,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'imageUrl': imageUrl,
      'options': options.map((o) => o.toJson()).toList(),
      'type': type.index,
      'marks': marks,
      'alignment': alignment.index,
      'isOptional': isOptional,
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      text: json['text'],
      imageUrl: json['imageUrl'],
      options:
          (json['options'] as List?)
              ?.map((o) => QuestionOption.fromJson(o))
              .toList() ??
          [],
      type: QuestionType.values[json['type'] ?? 1],
      marks: (json['marks'] as num?)?.toDouble() ?? 1.0,
      alignment: TextAlign.values[json['alignment'] ?? 0],
      isOptional: json['isOptional'] ?? false,
    );
  }
}
