import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/application/word_content_block_service.dart';
import 'package:edusheet/features/paper_composer/application/word_shape_service.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shape metadata round-trips through canonical Paper JSON', () {
    final question = Question(id: 'q1', text: 'Draw the process');
    final shape = WordShapeService.create(WordShapeKind.arrow).copyWith(
      x: 0.15,
      y: 0.20,
      width: 0.50,
      height: 0.12,
      wrapMode: WordTextWrapMode.squareRight,
      zIndex: 3,
    );
    final withShape = WordShapeService.append(question, shape);
    final paper = Paper(
      id: 'p1',
      title: 'Shapes',
      createdAt: DateTime.utc(2026, 9, 1),
      sections: [
        PaperSection(id: 's1', title: 'Section A', questions: [withShape]),
      ],
    );

    final restored = Paper.fromJson(paper.toJson());
    final restoredQuestion = restored.sections.single.questions.single;
    final restoredShapes = WordShapeService.shapesOf(restoredQuestion);

    expect(restoredQuestion.isWordContentBlock, isFalse);
    expect(restoredShapes, hasLength(1));
    expect(restoredShapes.single.kind, WordShapeKind.arrow);
    expect(restoredShapes.single.wrapMode, WordTextWrapMode.squareRight);
    expect(restoredShapes.single.zIndex, 3);
    expect(restoredShapes.single.x, closeTo(0.15, 0.0001));
    expect(restoredShapes.single.width, closeTo(0.50, 0.0001));
  });

  test('shape layer mutations preserve IDs and canonical ownership', () {
    final first = WordShapeService.create(WordShapeKind.rectangle);
    final second = WordShapeService.create(WordShapeKind.ellipse);
    var question = Question(id: 'q1', text: 'Question');
    question = WordShapeService.append(question, first);
    question = WordShapeService.append(question, second);

    question = WordShapeService.bringForward(question, first.id);
    final forward = WordShapeService.shapesOf(question);
    expect(
      forward.firstWhere((item) => item.id == first.id).zIndex,
      greaterThan(forward.firstWhere((item) => item.id == second.id).zIndex),
    );

    question = WordShapeService.sendBackward(question, first.id);
    final backward = WordShapeService.shapesOf(question);
    expect(
      backward.firstWhere((item) => item.id == first.id).zIndex,
      lessThan(backward.firstWhere((item) => item.id == second.id).zIndex),
    );

    final resized = first.copyWith(x: 0.2, y: 0.25, width: 0.4, height: 0.35);
    question = WordShapeService.replace(question, resized);
    expect(
      WordShapeService.shapesOf(
        question,
      ).firstWhere((item) => item.id == first.id).width,
      closeTo(0.4, 0.0001),
    );

    question = WordShapeService.remove(question, second.id);
    expect(WordShapeService.shapesOf(question).map((item) => item.id), [
      first.id,
    ]);
  });

  test('free Word shape block is non-assessment content', () {
    final block = WordContentBlockService.shape(
      WordShapeService.create(WordShapeKind.callout),
    );

    expect(block.isWordContentBlock, isTrue);
    expect(WordContentBlockService.kindOf(block), WordContentBlockKind.shape);
    expect(block.marks, 0);
    expect(WordShapeService.shapesOf(block), hasLength(1));
    expect(WordShapeService.shapesOf(block).single.kind, WordShapeKind.callout);
  });
}
