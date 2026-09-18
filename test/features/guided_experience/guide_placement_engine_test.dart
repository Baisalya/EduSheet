import 'package:edusheet/features/guided_experience/presentation/widgets/guide_placement_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = GuidePlacementEngine();
  const viewport = Rect.fromLTWH(0, 0, 800, 600);
  const card = Size(340, 180);

  void expectSafe(GuidePlacementResult result, Rect target) {
    expect(viewport.contains(result.rect.topLeft), isTrue);
    expect(viewport.contains(result.rect.bottomRight), isTrue);
    expect(result.rect.overlaps(target.inflate(6)), isFalse);
  }

  test('places coach above a lower-screen target without covering it', () {
    const target = Rect.fromLTWH(330, 500, 140, 48);
    final result = engine.place(viewport: viewport, target: target, childSize: card);
    expect(result.side, GuidePlacementSide.top);
    expectSafe(result, target);
  });

  test('places coach below a top-screen target', () {
    const target = Rect.fromLTWH(330, 24, 140, 48);
    final result = engine.place(viewport: viewport, target: target, childSize: card);
    expect(result.side, GuidePlacementSide.bottom);
    expectSafe(result, target);
  });

  test('keeps coach inside a narrow safe viewport', () {
    const narrow = Rect.fromLTWH(0, 0, 360, 640);
    const target = Rect.fromLTWH(145, 500, 70, 48);
    const narrowCard = Size(320, 160);
    final result = engine.place(viewport: narrow, target: target, childSize: narrowCard);
    expect(narrow.contains(result.rect.topLeft), isTrue);
    expect(narrow.contains(result.rect.bottomRight), isTrue);
    expect(result.rect.overlaps(target.inflate(6)), isFalse);
  });

  test('respects a reduced safe viewport such as an open keyboard', () {
    const keyboardSafe = Rect.fromLTWH(0, 0, 420, 390);
    const target = Rect.fromLTWH(140, 300, 140, 48);
    const compactCard = Size(360, 150);
    final result = engine.place(
      viewport: keyboardSafe,
      target: target,
      childSize: compactCard,
    );
    expect(keyboardSafe.contains(result.rect.topLeft), isTrue);
    expect(keyboardSafe.contains(result.rect.bottomRight), isTrue);
    expect(result.rect.overlaps(target.inflate(6)), isFalse);
  });
  test('keeps an accessibility-sized coach bounded in a very small viewport', () {
    const tiny = Rect.fromLTWH(0, 0, 280, 220);
    const target = Rect.fromLTWH(110, 150, 60, 42);
    const tinyCard = Size(240, 90);
    final result = engine.place(
      viewport: tiny,
      target: target,
      childSize: tinyCard,
    );
    expect(tiny.contains(result.rect.topLeft), isTrue);
    expect(tiny.contains(result.rect.bottomRight), isTrue);
    expect(result.rect.overlaps(target.inflate(6)), isFalse);
  });

}
