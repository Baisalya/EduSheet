import 'package:flutter/material.dart';

enum QuestionType { mcq, descriptive, fillInTheBlanks }

class Paper {
  final String id;
  final String title;
  final String schoolName;
  final String? schoolLogo;
  final List<PaperSection> sections;
  final bool includeOmr;
  final String templateId;

  Paper({
    required this.id,
    required this.title,
    this.schoolName = 'My School',
    this.schoolLogo,
    this.sections = const [],
    this.includeOmr = false,
    this.templateId = 'school_formal',
  });

  Paper copyWith({
    String? id,
    String? title,
    String? schoolName,
    String? schoolLogo,
    List<PaperSection>? sections,
    bool? includeOmr,
    String? templateId,
  }) {
    return Paper(
      id: id ?? this.id,
      title: title ?? this.title,
      schoolName: schoolName ?? this.schoolName,
      schoolLogo: schoolLogo ?? this.schoolLogo,
      sections: sections ?? this.sections,
      includeOmr: includeOmr ?? this.includeOmr,
      templateId: templateId ?? this.templateId,
    );
  }

  double get totalMarks {
    double total = 0;
    for (var section in sections) {
      for (var question in section.questions) {
        total += question.marks;
      }
    }
    return total;
  }
}

class PaperSection {
  final String id;
  final String title;
  final String? instruction;
  final String prefix;
  final List<Question> questions;

  PaperSection({
    required this.id,
    required this.title,
    this.instruction,
    this.prefix = '',
    this.questions = const [],
  });

  PaperSection copyWith({
    String? id,
    String? title,
    String? instruction,
    String? prefix,
    List<Question>? questions,
  }) {
    return PaperSection(
      id: id ?? this.id,
      title: title ?? this.title,
      instruction: instruction ?? this.instruction,
      prefix: prefix ?? this.prefix,
      questions: questions ?? this.questions,
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

  QuestionOption copyWith({
    String? id,
    String? text,
    bool? isCorrect,
  }) {
    return QuestionOption(
      id: id ?? this.id,
      text: text ?? this.text,
      isCorrect: isCorrect ?? this.isCorrect,
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

  Question({
    required this.id,
    required this.text,
    this.imageUrl,
    this.options = const [],
    this.type = QuestionType.descriptive,
    this.marks = 1.0,
    this.alignment = TextAlign.left,
  });

  Question copyWith({
    String? id,
    String? text,
    String? imageUrl,
    List<QuestionOption>? options,
    QuestionType? type,
    double? marks,
    TextAlign? alignment,
  }) {
    return Question(
      id: id ?? this.id,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      options: options ?? this.options,
      type: type ?? this.type,
      marks: marks ?? this.marks,
      alignment: alignment ?? this.alignment,
    );
  }
}
