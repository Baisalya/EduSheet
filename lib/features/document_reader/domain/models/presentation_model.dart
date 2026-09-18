import 'dart:typed_data';

enum PresentationElementType { text, image, placeholder }

enum PresentationTransitionKind {
  none,
  fade,
  push,
  wipe,
  split,
  cover,
  uncover,
  zoom,
}

enum PresentationAnimationTrigger { onClick, withPrevious, afterPrevious }

enum PresentationAnimationKind {
  appear,
  fadeIn,
  fadeOut,
  flyIn,
  flyOut,
  wipeIn,
  wipeOut,
  zoomIn,
  zoomOut,
  growShrink,
  pulse,
  disappear,
  unsupported,
}

class PresentationDocument {
  final double slideWidth;
  final double slideHeight;
  final List<PresentationSlide> slides;

  const PresentationDocument({
    required this.slideWidth,
    required this.slideHeight,
    required this.slides,
  });

  double get aspectRatio =>
      slideHeight == 0 ? 16 / 9 : slideWidth / slideHeight;
}

class PresentationSlide {
  final int number;
  final List<PresentationElement> elements;
  final PresentationTransition transition;
  final int? backgroundColor;
  final PresentationGradient? backgroundGradient;
  final bool hasNativeAnimations;
  final List<PresentationAnimationStep> animations;

  const PresentationSlide({
    required this.number,
    required this.elements,
    this.transition = const PresentationTransition(),
    this.backgroundColor,
    this.backgroundGradient,
    this.hasNativeAnimations = false,
    this.animations = const <PresentationAnimationStep>[],
  });

  List<String> get readableText => elements
      .where((element) => element.text.trim().isNotEmpty)
      .map((element) => element.text.trim())
      .toList();
}

class PresentationTransition {
  final PresentationTransitionKind kind;
  final String? direction;
  final Duration duration;

  const PresentationTransition({
    this.kind = PresentationTransitionKind.none,
    this.direction,
    this.duration = const Duration(milliseconds: 280),
  });
}


class PresentationAnimationStep {
  final String targetObjectId;
  final PresentationAnimationKind kind;
  final PresentationAnimationTrigger trigger;
  final Duration duration;
  final Duration delay;
  final String? direction;
  final double magnitude;
  final bool supported;
  final String? sourceEffect;

  const PresentationAnimationStep({
    required this.targetObjectId,
    required this.kind,
    required this.trigger,
    this.duration = const Duration(milliseconds: 400),
    this.delay = Duration.zero,
    this.direction,
    this.magnitude = 1.2,
    this.supported = true,
    this.sourceEffect,
  });

  bool get isEntrance => switch (kind) {
    PresentationAnimationKind.appear ||
    PresentationAnimationKind.fadeIn ||
    PresentationAnimationKind.flyIn ||
    PresentationAnimationKind.wipeIn ||
    PresentationAnimationKind.zoomIn => true,
    _ => false,
  };

  bool get isExit => switch (kind) {
    PresentationAnimationKind.fadeOut ||
    PresentationAnimationKind.flyOut ||
    PresentationAnimationKind.wipeOut ||
    PresentationAnimationKind.zoomOut ||
    PresentationAnimationKind.disappear => true,
    _ => false,
  };
}

class PresentationGradientStop {
  final double position;
  final int color;

  const PresentationGradientStop({required this.position, required this.color});
}

class PresentationGradient {
  final List<PresentationGradientStop> stops;
  final double angleDegrees;

  const PresentationGradient({
    required this.stops,
    this.angleDegrees = 0,
  });
}

class PresentationTextRun {
  final String text;
  final int? color;
  final double? fontSizePoints;
  final String? fontFamily;
  final bool bold;
  final bool italic;
  final bool underline;

  const PresentationTextRun({
    required this.text,
    this.color,
    this.fontSizePoints,
    this.fontFamily,
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });
}

class PresentationElement {
  final PresentationElementType type;
  final String? objectId;
  final double left;
  final double top;
  final double width;
  final double height;
  final bool hasBounds;
  final String text;
  final Uint8List? imageBytes;
  final int? fillColor;
  final PresentationGradient? fillGradient;
  final int? strokeColor;
  final double? strokeWidthPoints;
  final int? textColor;
  final double? fontSizePoints;
  final String? fontFamily;
  final bool bold;
  final bool italic;
  final bool underline;
  final String? alignment;
  final double rotationDegrees;
  final String? shapeKind;
  final List<PresentationTextRun> textRuns;

  const PresentationElement({
    required this.type,
    this.objectId,
    this.left = 0,
    this.top = 0,
    this.width = 0,
    this.height = 0,
    this.hasBounds = false,
    this.text = '',
    this.imageBytes,
    this.fillColor,
    this.fillGradient,
    this.strokeColor,
    this.strokeWidthPoints,
    this.textColor,
    this.fontSizePoints,
    this.fontFamily,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.alignment,
    this.rotationDegrees = 0,
    this.shapeKind,
    this.textRuns = const <PresentationTextRun>[],
  });
}
