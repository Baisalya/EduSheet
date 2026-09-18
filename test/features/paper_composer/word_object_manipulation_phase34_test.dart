import 'package:edusheet/features/paper_composer/application/word_object_manipulation_service.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 3 floating object model round-trips professional properties', () {
    const original = WordShapeObject(
      id: 'textbox-1',
      kind: WordShapeKind.textBox,
      x: 0.18,
      y: 0.22,
      width: 0.44,
      height: 0.28,
      wrapMode: WordTextWrapMode.inFrontOfText,
      zIndex: 7,
      text: 'School note',
      locked: true,
      aspectRatioLocked: true,
      borderVisible: false,
      strokeColorArgb: 0xFF123456,
      strokeWidth: 2.4,
      fillColorArgb: 0xFFF4F4F4,
      fillOpacity: 0.65,
      padding: 12,
      textBoxSizing: WordTextBoxSizing.autoHeight,
    );

    final restored = WordShapeObject.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.kind, WordShapeKind.textBox);
    expect(restored.wrapMode, WordTextWrapMode.inFrontOfText);
    expect(restored.locked, isTrue);
    expect(restored.aspectRatioLocked, isTrue);
    expect(restored.borderVisible, isFalse);
    expect(restored.strokeColorArgb, 0xFF123456);
    expect(restored.fillColorArgb, 0xFFF4F4F4);
    expect(restored.fillOpacity, closeTo(0.65, 0.0001));
    expect(restored.padding, 12);
    expect(restored.textBoxSizing, WordTextBoxSizing.autoHeight);
  });

  test('smart move snaps object center and reports guide', () {
    const shape = WordShapeObject(
      id: 'a',
      kind: WordShapeKind.rectangle,
      x: 0.44,
      y: 0.2,
      width: 0.10,
      height: 0.20,
    );

    final moved = WordObjectManipulationService.moveWithSnap(
      shape,
      deltaX: 0.009,
      deltaY: 0,
      siblings: const [],
    );

    expect(moved.object.x, closeTo(0.45, 0.0001));
    expect(moved.verticalGuide, closeTo(0.5, 0.0001));
  });

  test('lock prevents move and resize', () {
    const locked = WordShapeObject(
      id: 'locked',
      kind: WordShapeKind.ellipse,
      x: 0.2,
      y: 0.2,
      width: 0.2,
      height: 0.2,
      locked: true,
    );

    final moved = WordObjectManipulationService.moveWithSnap(
      locked,
      deltaX: 0.3,
      deltaY: 0.3,
      siblings: const [],
    );
    final resized = WordObjectManipulationService.resizeBottomRight(
      locked,
      deltaWidth: 0.3,
      deltaHeight: 0.2,
    );

    expect(moved.object.x, locked.x);
    expect(moved.object.y, locked.y);
    expect(resized.width, locked.width);
    expect(resized.height, locked.height);
  });

  test('Phase 4 multi-select alignment and distribution stay normalized', () {
    final objects = [
      const WordShapeObject(
        id: 'a',
        kind: WordShapeKind.rectangle,
        x: 0.10,
        y: 0.10,
        width: 0.10,
        height: 0.10,
      ),
      const WordShapeObject(
        id: 'b',
        kind: WordShapeKind.rectangle,
        x: 0.35,
        y: 0.30,
        width: 0.10,
        height: 0.10,
      ),
      const WordShapeObject(
        id: 'c',
        kind: WordShapeKind.rectangle,
        x: 0.70,
        y: 0.55,
        width: 0.10,
        height: 0.10,
      ),
    ];
    const ids = {'a', 'b', 'c'};

    final aligned = WordObjectManipulationService.align(
      objects,
      ids,
      WordObjectAlignment.left,
    );
    expect(aligned.map((item) => item.x).toSet(), {0.10});

    final distributed = WordObjectManipulationService.distribute(
      objects,
      ids,
      WordObjectDistribution.horizontal,
    );
    expect(distributed.first.x, closeTo(0.10, 0.0001));
    expect(distributed.last.x, closeTo(0.70, 0.0001));
    expect(distributed[1].x, greaterThan(distributed[0].x));
    expect(distributed[1].x, lessThan(distributed[2].x));
  });

  test('copy/paste and duplicate create independent unlocked objects', () {
    const original = WordShapeObject(
      id: 'a',
      kind: WordShapeKind.textBox,
      text: 'Copy me',
      locked: true,
      zIndex: 2,
    );

    final duplicated = WordObjectManipulationService.duplicate(
      const [original],
      const {'a'},
    );
    final duplicate = duplicated.last;
    expect(duplicated, hasLength(2));
    expect(duplicate.id, isNot('a'));
    expect(duplicate.text, 'Copy me');
    expect(duplicate.locked, isFalse);

    final pasted = WordObjectManipulationService.paste(
      const [original],
      const [original],
    );
    expect(pasted, hasLength(2));
    expect(pasted.last.id, isNot('a'));
    expect(pasted.last.zIndex, greaterThan(original.zIndex));
  });

  test('layer commands support one-step and absolute front/back', () {
    const objects = [
      WordShapeObject(id: 'a', kind: WordShapeKind.rectangle, zIndex: 0),
      WordShapeObject(id: 'b', kind: WordShapeKind.rectangle, zIndex: 1),
      WordShapeObject(id: 'c', kind: WordShapeKind.rectangle, zIndex: 2),
    ];

    final forward = WordObjectManipulationService.bringForwardOne(
      objects,
      const {'a'},
    );
    expect(forward.firstWhere((item) => item.id == 'a').zIndex, 1);

    final front = WordObjectManipulationService.bringToFront(
      objects,
      const {'a'},
    );
    expect(front.firstWhere((item) => item.id == 'a').zIndex, 2);

    final back = WordObjectManipulationService.sendToBack(
      objects,
      const {'c'},
    );
    expect(back.firstWhere((item) => item.id == 'c').zIndex, 0);
  });

  test('auto-height text box grows deterministically with content', () {
    const box = WordShapeObject(
      id: 't',
      kind: WordShapeKind.textBox,
      textBoxSizing: WordTextBoxSizing.autoHeight,
      height: 0.14,
    );

    final short = WordObjectManipulationService.updateText(box, 'Short');
    final long = WordObjectManipulationService.updateText(
      box,
      'This is a much longer text box sentence that should wrap across several lines in the authoring surface.',
    );

    expect(short.height, greaterThanOrEqualTo(0.14));
    expect(long.height, greaterThan(short.height));
  });
}
