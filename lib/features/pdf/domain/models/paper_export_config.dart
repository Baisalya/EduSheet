enum PaperOutputMode {
  standard,
  withAnswerSpace,
  questionAnswerBooklet,
  answerKey,
  teacherSolution,
  studentCopy,
  multipleSet,
  worksheet,
  compact,
  largePrint,
}

enum ExportPageSize { useTemplate, a4, letter }

enum ExportOrientation { portrait, landscape }

enum ExportColourMode { colour, grayscale }

class BookletSettings {
  final bool enabled;
  final double gutterPoints;
  final int signatureSize;
  final bool padWithBlankPages;

  const BookletSettings({
    this.enabled = false,
    this.gutterPoints = 18,
    this.signatureSize = 0,
    this.padWithBlankPages = true,
  });

  List<String> validate() {
    final errors = <String>[];
    if (gutterPoints < 0 || gutterPoints > 144) {
      errors.add('Booklet gutter must be between 0 and 144 points.');
    }
    if (signatureSize != 0 &&
        (signatureSize < 4 || signatureSize % 4 != 0)) {
      errors.add('Signature size must be zero or a positive multiple of four.');
    }
    return errors;
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'gutterPoints': gutterPoints,
    'signatureSize': signatureSize,
    'padWithBlankPages': padWithBlankPages,
  };

  factory BookletSettings.fromJson(Map<String, dynamic> json) {
    return BookletSettings(
      enabled: json['enabled'] == true,
      gutterPoints: (json['gutterPoints'] as num?)?.toDouble() ?? 18,
      signatureSize: (json['signatureSize'] as num?)?.toInt() ?? 0,
      padWithBlankPages: json['padWithBlankPages'] != false,
    );
  }
}

class PaperExportConfig {
  final PaperOutputMode outputMode;
  final ExportPageSize pageSize;
  final ExportOrientation orientation;
  final ExportColourMode colourMode;
  final double marginPoints;
  final String setLabel;
  final BookletSettings booklet;

  const PaperExportConfig({
    this.outputMode = PaperOutputMode.standard,
    this.pageSize = ExportPageSize.useTemplate,
    this.orientation = ExportOrientation.portrait,
    this.colourMode = ExportColourMode.colour,
    this.marginPoints = 32,
    this.setLabel = '',
    this.booklet = const BookletSettings(),
  });

  bool get includesAnswers =>
      outputMode == PaperOutputMode.answerKey ||
      outputMode == PaperOutputMode.teacherSolution;

  bool get includesSolutions => outputMode == PaperOutputMode.teacherSolution;

  bool get includesAnswerSpace =>
      outputMode == PaperOutputMode.withAnswerSpace ||
      outputMode == PaperOutputMode.questionAnswerBooklet ||
      outputMode == PaperOutputMode.worksheet;

  double get fontScale => outputMode == PaperOutputMode.largePrint ? 1.35 : 1;

  double get spacingScale =>
      outputMode == PaperOutputMode.compact ? 0.65 : 1;

  List<String> validate() {
    final errors = <String>[];
    if (marginPoints < 12 || marginPoints > 144) {
      errors.add('Page margin must be between 12 and 144 points.');
    }
    if (outputMode == PaperOutputMode.multipleSet && setLabel.trim().isEmpty) {
      errors.add('A set label is required for multiple-set output.');
    }
    errors.addAll(booklet.validate());
    return errors;
  }

  Map<String, dynamic> toJson() => {
    'outputMode': outputMode.name,
    'pageSize': pageSize.name,
    'orientation': orientation.name,
    'colourMode': colourMode.name,
    'marginPoints': marginPoints,
    'setLabel': setLabel,
    'booklet': booklet.toJson(),
  };

  factory PaperExportConfig.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, dynamic value, T fallback) {
      return values.firstWhere(
        (candidate) => candidate.name == value,
        orElse: () => fallback,
      );
    }

    return PaperExportConfig(
      outputMode: enumValue(
        PaperOutputMode.values,
        json['outputMode'],
        PaperOutputMode.standard,
      ),
      pageSize: enumValue(
        ExportPageSize.values,
        json['pageSize'],
        ExportPageSize.useTemplate,
      ),
      orientation: enumValue(
        ExportOrientation.values,
        json['orientation'],
        ExportOrientation.portrait,
      ),
      colourMode: enumValue(
        ExportColourMode.values,
        json['colourMode'],
        ExportColourMode.colour,
      ),
      marginPoints: (json['marginPoints'] as num?)?.toDouble() ?? 32,
      setLabel: json['setLabel']?.toString() ?? '',
      booklet: json['booklet'] is Map
          ? BookletSettings.fromJson(
              Map<String, dynamic>.from(json['booklet'] as Map),
            )
          : const BookletSettings(),
    );
  }
}
