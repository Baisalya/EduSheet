import 'package:edusheet/features/editor/domain/models/paper_model.dart';

/// Metadata-backed advanced paper content for one question.
///
/// The persisted [Question] model already provides a JSON-safe metadata map.
/// EduSheet therefore keeps advanced authoring helpers inside that existing
/// contract instead of introducing a second database schema. Older questions
/// simply decode to [QuestionAdvancedContent.empty].
enum QuestionStimulusKind { passage, poem, caseStudy, sourceText }

extension QuestionStimulusKindLabel on QuestionStimulusKind {
  String get label => switch (this) {
    QuestionStimulusKind.passage => 'Passage',
    QuestionStimulusKind.poem => 'Poem',
    QuestionStimulusKind.caseStudy => 'Case study',
    QuestionStimulusKind.sourceText => 'Source text',
  };
}

class QuestionStimulus {
  final QuestionStimulusKind kind;
  final String title;
  final String text;

  const QuestionStimulus({
    this.kind = QuestionStimulusKind.passage,
    this.title = '',
    required this.text,
  });

  bool get isEmpty => text.trim().isEmpty;

  QuestionStimulus copyWith({
    QuestionStimulusKind? kind,
    String? title,
    String? text,
  }) {
    return QuestionStimulus(
      kind: kind ?? this.kind,
      title: title ?? this.title,
      text: text ?? this.text,
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'title': title,
    'text': text,
  };

  factory QuestionStimulus.fromJson(Map<String, dynamic> json) {
    return QuestionStimulus(
      kind: QuestionStimulusKind.values.firstWhere(
        (value) => value.name == json['kind']?.toString(),
        orElse: () => QuestionStimulusKind.passage,
      ),
      title: json['title']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }
}

enum QuestionAnswerSpaceStyle { none, blank, ruled, box, graph }

extension QuestionAnswerSpaceStyleLabel on QuestionAnswerSpaceStyle {
  String get label => switch (this) {
    QuestionAnswerSpaceStyle.none => 'Use section setting',
    QuestionAnswerSpaceStyle.blank => 'Blank space',
    QuestionAnswerSpaceStyle.ruled => 'Ruled lines',
    QuestionAnswerSpaceStyle.box => 'Answer box',
    QuestionAnswerSpaceStyle.graph => 'Graph grid',
  };
}

class QuestionAnswerSpace {
  final QuestionAnswerSpaceStyle style;
  final int lines;

  const QuestionAnswerSpace({
    this.style = QuestionAnswerSpaceStyle.none,
    this.lines = 0,
  });

  bool get isConfigured => style != QuestionAnswerSpaceStyle.none && lines > 0;

  QuestionAnswerSpace copyWith({QuestionAnswerSpaceStyle? style, int? lines}) {
    return QuestionAnswerSpace(
      style: style ?? this.style,
      lines: lines ?? this.lines,
    );
  }

  Map<String, dynamic> toJson() => {'style': style.name, 'lines': lines};

  factory QuestionAnswerSpace.fromJson(Map<String, dynamic> json) {
    return QuestionAnswerSpace(
      style: QuestionAnswerSpaceStyle.values.firstWhere(
        (value) => value.name == json['style']?.toString(),
        orElse: () => QuestionAnswerSpaceStyle.none,
      ),
      lines: ((json['lines'] as num?)?.toInt() ?? 0).clamp(0, 30).toInt(),
    );
  }
}

class QuestionAdvancedContent {
  static const metadataKey = 'smartPaperContentV1';

  final QuestionStimulus? stimulus;
  final List<String> wordBank;
  final QuestionAnswerSpace answerSpace;

  const QuestionAdvancedContent({
    this.stimulus,
    this.wordBank = const [],
    this.answerSpace = const QuestionAnswerSpace(),
  });

  static const empty = QuestionAdvancedContent();

  bool get hasStimulus => stimulus != null && !stimulus!.isEmpty;
  bool get hasWordBank => wordBank.any((item) => item.trim().isNotEmpty);
  bool get hasAnswerSpace => answerSpace.isConfigured;
  bool get hasAny => hasStimulus || hasWordBank || hasAnswerSpace;

  QuestionAdvancedContent copyWith({
    QuestionStimulus? stimulus,
    bool clearStimulus = false,
    List<String>? wordBank,
    QuestionAnswerSpace? answerSpace,
  }) {
    return QuestionAdvancedContent(
      stimulus: clearStimulus ? null : (stimulus ?? this.stimulus),
      wordBank: wordBank ?? this.wordBank,
      answerSpace: answerSpace ?? this.answerSpace,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (hasStimulus) 'stimulus': stimulus!.toJson(),
      if (hasWordBank)
        'wordBank': wordBank
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
      if (hasAnswerSpace) 'answerSpace': answerSpace.toJson(),
    };
  }

  static QuestionAdvancedContent fromQuestion(Question question) {
    return fromMetadata(question.metadata);
  }

  static QuestionAdvancedContent fromMetadata(Map<String, dynamic> metadata) {
    final raw = metadata[metadataKey];
    if (raw is! Map) return empty;
    final json = Map<String, dynamic>.from(raw);

    QuestionStimulus? stimulus;
    final rawStimulus = json['stimulus'];
    if (rawStimulus is Map) {
      final parsed = QuestionStimulus.fromJson(
        Map<String, dynamic>.from(rawStimulus),
      );
      if (!parsed.isEmpty) stimulus = parsed;
    }

    final wordBank = (json['wordBank'] as List? ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();

    var answerSpace = const QuestionAnswerSpace();
    final rawAnswerSpace = json['answerSpace'];
    if (rawAnswerSpace is Map) {
      answerSpace = QuestionAnswerSpace.fromJson(
        Map<String, dynamic>.from(rawAnswerSpace),
      );
    }

    return QuestionAdvancedContent(
      stimulus: stimulus,
      wordBank: wordBank,
      answerSpace: answerSpace,
    );
  }

  /// Writes only EduSheet's namespaced advanced-content entry while retaining
  /// every unrelated metadata key owned by older releases or other features.
  Map<String, dynamic> writeToMetadata(Map<String, dynamic> source) {
    final next = Map<String, dynamic>.from(source);
    if (!hasAny) {
      next.remove(metadataKey);
    } else {
      next[metadataKey] = toJson();
    }
    return next;
  }
}
