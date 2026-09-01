import 'package:edusheet/features/editor/domain/models/paper_model.dart';

enum QuestionOptionLayout { vertical, twoColumn, inline }

extension QuestionOptionLayoutLabel on QuestionOptionLayout {
  String get label => switch (this) {
    QuestionOptionLayout.vertical => 'Vertical',
    QuestionOptionLayout.twoColumn => '2 columns',
    QuestionOptionLayout.inline => 'Inline',
  };

  String get shortDescription => switch (this) {
    QuestionOptionLayout.vertical => 'One option per line',
    QuestionOptionLayout.twoColumn => 'Two options per row',
    QuestionOptionLayout.inline => 'Compact flowing options',
  };
}

/// Stores option presentation in the existing Question.metadata bag so older
/// saved papers remain compatible and no database/schema migration is needed.
class QuestionOptionLayoutCodec {
  const QuestionOptionLayoutCodec._();

  static const metadataKey = 'paperOptionLayout';

  static QuestionOptionLayout fromQuestion(Question question) {
    return fromMetadata(question.metadata);
  }

  static QuestionOptionLayout fromMetadata(Map<String, dynamic> metadata) {
    final raw = metadata[metadataKey]?.toString();
    return QuestionOptionLayout.values.firstWhere(
      (layout) => layout.name == raw,
      orElse: () => QuestionOptionLayout.vertical,
    );
  }

  static Map<String, dynamic> write(
    Map<String, dynamic> metadata,
    QuestionOptionLayout layout,
  ) {
    final next = Map<String, dynamic>.from(metadata);
    if (layout == QuestionOptionLayout.vertical) {
      next.remove(metadataKey);
    } else {
      next[metadataKey] = layout.name;
    }
    return next;
  }
}
