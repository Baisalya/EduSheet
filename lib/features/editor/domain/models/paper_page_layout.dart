/// Canonical page-layout settings shared by Smart Mode, Word Mode and export.
///
/// These values deliberately live in the editor domain instead of the PDF
/// feature so the paper remains the single source of truth. Old papers that do
/// not contain `pageLayout` deserialize to [PaperPageLayout.defaults].
enum PaperPageSize { useTemplate, a4, a5, a3, letter, legal }

enum PaperPageOrientation { portrait, landscape }

enum PaperPageNumberPosition { footerCenter, footerRight, headerRight }

class PaperPageMargins {
  final double topPoints;
  final double rightPoints;
  final double bottomPoints;
  final double leftPoints;

  const PaperPageMargins({
    this.topPoints = 36,
    this.rightPoints = 36,
    this.bottomPoints = 36,
    this.leftPoints = 36,
  });

  const PaperPageMargins.all(double points)
    : topPoints = points,
      rightPoints = points,
      bottomPoints = points,
      leftPoints = points;

  PaperPageMargins copyWith({
    double? topPoints,
    double? rightPoints,
    double? bottomPoints,
    double? leftPoints,
  }) {
    return PaperPageMargins(
      topPoints: topPoints ?? this.topPoints,
      rightPoints: rightPoints ?? this.rightPoints,
      bottomPoints: bottomPoints ?? this.bottomPoints,
      leftPoints: leftPoints ?? this.leftPoints,
    );
  }

  Map<String, dynamic> toJson() => {
    'topPoints': topPoints,
    'rightPoints': rightPoints,
    'bottomPoints': bottomPoints,
    'leftPoints': leftPoints,
  };

  factory PaperPageMargins.fromJson(Map<String, dynamic> json) {
    double value(String key) =>
        _bounded((json[key] as num?)?.toDouble() ?? 36, min: 12, max: 144);

    return PaperPageMargins(
      topPoints: value('topPoints'),
      rightPoints: value('rightPoints'),
      bottomPoints: value('bottomPoints'),
      leftPoints: value('leftPoints'),
    );
  }

  bool get isUniform =>
      (topPoints - rightPoints).abs() < 0.01 &&
      (topPoints - bottomPoints).abs() < 0.01 &&
      (topPoints - leftPoints).abs() < 0.01;
}

class PaperPageLayout {
  final PaperPageSize pageSize;
  final PaperPageOrientation orientation;
  final PaperPageMargins margins;
  final double headerDistancePoints;
  final double footerDistancePoints;
  final double lineSpacing;
  final double paragraphSpacingPoints;
  final PaperPageNumberPosition pageNumberPosition;

  const PaperPageLayout({
    this.pageSize = PaperPageSize.useTemplate,
    this.orientation = PaperPageOrientation.portrait,
    this.margins = const PaperPageMargins(),
    this.headerDistancePoints = 18,
    this.footerDistancePoints = 18,
    this.lineSpacing = 1.15,
    this.paragraphSpacingPoints = 6,
    this.pageNumberPosition = PaperPageNumberPosition.footerCenter,
  });

  static const defaults = PaperPageLayout();

  PaperPageLayout copyWith({
    PaperPageSize? pageSize,
    PaperPageOrientation? orientation,
    PaperPageMargins? margins,
    double? headerDistancePoints,
    double? footerDistancePoints,
    double? lineSpacing,
    double? paragraphSpacingPoints,
    PaperPageNumberPosition? pageNumberPosition,
  }) {
    return PaperPageLayout(
      pageSize: pageSize ?? this.pageSize,
      orientation: orientation ?? this.orientation,
      margins: margins ?? this.margins,
      headerDistancePoints: headerDistancePoints ?? this.headerDistancePoints,
      footerDistancePoints: footerDistancePoints ?? this.footerDistancePoints,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      paragraphSpacingPoints:
          paragraphSpacingPoints ?? this.paragraphSpacingPoints,
      pageNumberPosition: pageNumberPosition ?? this.pageNumberPosition,
    );
  }

  Map<String, dynamic> toJson() => {
    'pageSize': pageSize.name,
    'orientation': orientation.name,
    'margins': margins.toJson(),
    'headerDistancePoints': headerDistancePoints,
    'footerDistancePoints': footerDistancePoints,
    'lineSpacing': lineSpacing,
    'paragraphSpacingPoints': paragraphSpacingPoints,
    'pageNumberPosition': pageNumberPosition.name,
  };

  factory PaperPageLayout.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, dynamic raw, T fallback) {
      final name = raw?.toString();
      for (final value in values) {
        if (value.name == name) {
          return value;
        }
      }
      return fallback;
    }

    final marginJson = json['margins'];
    return PaperPageLayout(
      pageSize: enumValue(
        PaperPageSize.values,
        json['pageSize'],
        PaperPageSize.useTemplate,
      ),
      orientation: enumValue(
        PaperPageOrientation.values,
        json['orientation'],
        PaperPageOrientation.portrait,
      ),
      margins: marginJson is Map
          ? PaperPageMargins.fromJson(Map<String, dynamic>.from(marginJson))
          : const PaperPageMargins(),
      headerDistancePoints: _bounded(
        (json['headerDistancePoints'] as num?)?.toDouble() ?? 18,
        min: 0,
        max: 72,
      ),
      footerDistancePoints: _bounded(
        (json['footerDistancePoints'] as num?)?.toDouble() ?? 18,
        min: 0,
        max: 72,
      ),
      lineSpacing: _bounded(
        (json['lineSpacing'] as num?)?.toDouble() ?? 1.15,
        min: 0.8,
        max: 3,
      ),
      paragraphSpacingPoints: _bounded(
        (json['paragraphSpacingPoints'] as num?)?.toDouble() ?? 6,
        min: 0,
        max: 36,
      ),
      pageNumberPosition: enumValue(
        PaperPageNumberPosition.values,
        json['pageNumberPosition'],
        PaperPageNumberPosition.footerCenter,
      ),
    );
  }

  /// Returns fixed page dimensions in PDF points when [pageSize] is explicit.
  /// `useTemplate` intentionally returns null so the caller can resolve the
  /// current visual template without creating a dependency from editor -> PDF.
  ({double width, double height})? get explicitPageSizePoints {
    final portrait = switch (pageSize) {
      PaperPageSize.a4 => (width: 595.28, height: 841.89),
      PaperPageSize.a5 => (width: 419.53, height: 595.28),
      PaperPageSize.a3 => (width: 841.89, height: 1190.55),
      PaperPageSize.letter => (width: 612.0, height: 792.0),
      PaperPageSize.legal => (width: 612.0, height: 1008.0),
      PaperPageSize.useTemplate => null,
    };
    if (portrait == null) {
      return null;
    }
    if (orientation == PaperPageOrientation.landscape) {
      return (width: portrait.height, height: portrait.width);
    }
    return portrait;
  }
}

double _bounded(double value, {required double min, required double max}) {
  if (!value.isFinite) {
    return min;
  }
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}
