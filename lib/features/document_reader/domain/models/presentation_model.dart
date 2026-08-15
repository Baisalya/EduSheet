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

class PresentationDocument {
  final double slideWidth;
  final double slideHeight;
  final List<PresentationSlide> slides;

  const PresentationDocument({
    required this.slideWidth,
    required this.slideHeight,
    required this.slides,
  });

  double get aspectRatio => slideHeight == 0 ? 16 / 9 : slideWidth / slideHeight;
}

class PresentationSlide {
  final int number;
  final List<PresentationElement> elements;
  final PresentationTransition transition;
  final int? backgroundColor;
  final bool hasNativeAnimations;

  const PresentationSlide({
    required this.number,
    required this.elements,
    this.transition = const PresentationTransition(),
    this.backgroundColor,
    this.hasNativeAnimations = false,
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

class PresentationElement {
  final PresentationElementType type;
  final double left;
  final double top;
  final double width;
  final double height;
  final bool hasBounds;
  final String text;
  final Uint8List? imageBytes;
  final int? fillColor;
  final int? textColor;
  final double? fontSizePoints;
  final bool bold;
  final String? alignment;

  const PresentationElement({
    required this.type,
    this.left = 0,
    this.top = 0,
    this.width = 0,
    this.height = 0,
    this.hasBounds = false,
    this.text = '',
    this.imageBytes,
    this.fillColor,
    this.textColor,
    this.fontSizePoints,
    this.bold = false,
    this.alignment,
  });
}
