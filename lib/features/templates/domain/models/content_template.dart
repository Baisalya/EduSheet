import '../../../editor/domain/models/paper_model.dart';

class QuestionTemplate {
  final String id;
  final String name;
  final String description;
  final Question question;
  final bool isBuiltIn;
  final DateTime createdAt;
  final DateTime modifiedAt;

  QuestionTemplate({
    required this.id,
    required this.name,
    required this.question,
    this.description = '',
    this.isBuiltIn = false,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       modifiedAt = modifiedAt ?? createdAt ?? DateTime.now();

  QuestionTemplate copyWith({
    String? id,
    String? name,
    String? description,
    Question? question,
    bool? isBuiltIn,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return QuestionTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      question: question ?? this.question,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'question': question.toJson(),
    'isBuiltIn': isBuiltIn,
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': modifiedAt.toIso8601String(),
  };

  factory QuestionTemplate.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return QuestionTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Question template',
      description: json['description']?.toString() ?? '',
      question: Question.fromJson(
        Map<String, dynamic>.from(json['question'] as Map? ?? const {}),
      ),
      isBuiltIn: json['isBuiltIn'] == true,
      createdAt: createdAt,
      modifiedAt:
          DateTime.tryParse(json['modifiedAt']?.toString() ?? '') ?? createdAt,
    );
  }
}

class SectionTemplate {
  final String id;
  final String name;
  final String description;
  final PaperSection section;
  final bool isBuiltIn;
  final DateTime createdAt;
  final DateTime modifiedAt;

  SectionTemplate({
    required this.id,
    required this.name,
    required this.section,
    this.description = '',
    this.isBuiltIn = false,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       modifiedAt = modifiedAt ?? createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'section': section.toJson(),
    'isBuiltIn': isBuiltIn,
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': modifiedAt.toIso8601String(),
  };

  factory SectionTemplate.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return SectionTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Section template',
      description: json['description']?.toString() ?? '',
      section: PaperSection.fromJson(
        Map<String, dynamic>.from(json['section'] as Map? ?? const {}),
      ),
      isBuiltIn: json['isBuiltIn'] == true,
      createdAt: createdAt,
      modifiedAt:
          DateTime.tryParse(json['modifiedAt']?.toString() ?? '') ?? createdAt,
    );
  }
}

class PaperBlueprint {
  final String id;
  final String name;
  final String description;
  final Paper paper;
  final Map<String, String> variableDefaults;
  final bool isBuiltIn;
  final DateTime createdAt;
  final DateTime modifiedAt;

  PaperBlueprint({
    required this.id,
    required this.name,
    required this.paper,
    this.description = '',
    this.variableDefaults = const {},
    this.isBuiltIn = false,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       modifiedAt = modifiedAt ?? createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'paper': paper.toJson(),
    'variableDefaults': variableDefaults,
    'isBuiltIn': isBuiltIn,
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': modifiedAt.toIso8601String(),
  };

  factory PaperBlueprint.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return PaperBlueprint(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Paper template',
      description: json['description']?.toString() ?? '',
      paper: Paper.fromJson(
        Map<String, dynamic>.from(json['paper'] as Map? ?? const {}),
      ),
      variableDefaults: (json['variableDefaults'] as Map? ?? const {}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      isBuiltIn: json['isBuiltIn'] == true,
      createdAt: createdAt,
      modifiedAt:
          DateTime.tryParse(json['modifiedAt']?.toString() ?? '') ?? createdAt,
    );
  }
}

class TemplateLibraryData {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final List<QuestionTemplate> questions;
  final List<SectionTemplate> sections;
  final List<PaperBlueprint> papers;

  const TemplateLibraryData({
    this.schemaVersion = currentSchemaVersion,
    this.questions = const [],
    this.sections = const [],
    this.papers = const [],
  });

  TemplateLibraryData copyWith({
    List<QuestionTemplate>? questions,
    List<SectionTemplate>? sections,
    List<PaperBlueprint>? papers,
  }) {
    return TemplateLibraryData(
      schemaVersion: schemaVersion,
      questions: questions ?? this.questions,
      sections: sections ?? this.sections,
      papers: papers ?? this.papers,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'questions': questions.map((item) => item.toJson()).toList(),
    'sections': sections.map((item) => item.toJson()).toList(),
    'papers': papers.map((item) => item.toJson()).toList(),
  };

  factory TemplateLibraryData.fromJson(Map<String, dynamic> json) {
    List<T> decode<T>(dynamic value, T Function(Map<String, dynamic>) parse) {
      return (value as List? ?? const [])
          .whereType<Map>()
          .map((item) => parse(Map<String, dynamic>.from(item)))
          .toList();
    }

    return TemplateLibraryData(
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
      questions: decode(json['questions'], QuestionTemplate.fromJson),
      sections: decode(json['sections'], SectionTemplate.fromJson),
      papers: decode(json['papers'], PaperBlueprint.fromJson),
    );
  }
}
