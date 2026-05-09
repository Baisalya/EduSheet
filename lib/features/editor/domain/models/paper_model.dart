class Paper {
  final String id;
  final String title;
  final List<PaperSection> sections;
  final bool includeOmr;

  Paper({
    required this.id,
    required this.title,
    this.sections = const [],
    this.includeOmr = false,
  });

  Paper copyWith({
    String? id,
    String? title,
    List<PaperSection>? sections,
    bool? includeOmr,
  }) {
    return Paper(
      id: id ?? this.id,
      title: title ?? this.title,
      sections: sections ?? this.sections,
      includeOmr: includeOmr ?? this.includeOmr,
    );
  }
}

class PaperSection {
  final String id;
  final String title;
  final List<Question> questions;

  PaperSection({
    required this.id,
    required this.title,
    this.questions = const [],
  });

  PaperSection copyWith({
    String? id,
    String? title,
    List<Question>? questions,
  }) {
    return PaperSection(
      id: id ?? this.id,
      title: title ?? this.title,
      questions: questions ?? this.questions,
    );
  }
}

class Question {
  final String id;
  final String text;
  final String? imageUrl;
  final List<String> options;

  Question({
    required this.id,
    required this.text,
    this.imageUrl,
    this.options = const [],
  });

  Question copyWith({
    String? id,
    String? text,
    String? imageUrl,
    List<String>? options,
  }) {
    return Question(
      id: id ?? this.id,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      options: options ?? this.options,
    );
  }
}
