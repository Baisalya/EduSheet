import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/paper_composer/application/question_document_projection.dart';
import 'package:edusheet/features/paper_composer/application/word_content_block_service.dart';
import 'package:edusheet/features/paper_composer/application/word_pagination_service.dart';
import 'package:edusheet/features/paper_composer/application/word_shape_service.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 5 anchor intent round-trips and legacy objects stay content anchored', () {
    const fixed = WordShapeObject(
      id: 'fixed',
      kind: WordShapeKind.textBox,
      anchorMode: WordObjectAnchorMode.fixedOnPage,
      fixedPageIndex: 3,
    );

    final restored = WordShapeObject.fromJson(fixed.toJson());
    final legacy = WordShapeObject.fromJson({
      'id': 'legacy',
      'kind': 'rectangle',
      'x': 0.1,
      'y': 0.1,
      'width': 0.2,
      'height': 0.2,
    });

    expect(restored.isFixedOnPage, isTrue);
    expect(restored.fixedPageIndex, 3);
    expect(legacy.anchorMode, WordObjectAnchorMode.moveWithContent);
    expect(legacy.fixedPageIndex, 0);
  });

  test('explicit page breaks create deterministic authoring page indices', () {
    var q1 = Question(id: 'q1', text: 'One');
    q1 = WordShapeService.append(
      q1,
      const WordShapeObject(
        id: 'pin',
        kind: WordShapeKind.rectangle,
        anchorMode: WordObjectAnchorMode.fixedOnPage,
        fixedPageIndex: 4,
      ),
    );
    final breakBlock = WordContentBlockService.pageBreak();
    final paper = Paper(
      id: 'p',
      title: 'Pagination',
      createdAt: DateTime(2026, 9, 18),
      sections: [
        PaperSection(
          id: 's1',
          title: 'A',
          questions: [q1, breakBlock, Question(id: 'q2', text: 'Two')],
        ),
        PaperSection(
          id: 's2',
          title: 'B',
          pageBreakBefore: true,
          questions: [Question(id: 'q3', text: 'Three')],
        ),
      ],
    );

    final plan = WordPaginationService.planFor(paper);

    expect(plan.pageOfQuestion('q1'), 0);
    expect(plan.pageOfQuestion('q2'), 1);
    expect(plan.pageOfQuestion('q3'), 2);
    expect(plan.pageCount, 5);
  });

  test('anchor switch captures owner page and printable bounds can be repaired', () {
    const object = WordShapeObject(
      id: 'o',
      kind: WordShapeKind.rectangle,
      x: 0.86,
      y: 0.91,
      width: 0.30,
      height: 0.22,
    );

    final fixed = WordPaginationService.setAnchorMode(
      object,
      WordObjectAnchorMode.fixedOnPage,
      ownerPageIndex: 2,
    );
    final fitted = WordPaginationService.fitInsidePrintableBounds(fixed);

    expect(fixed.fixedPageIndex, 2);
    expect(
      WordPaginationService.effectivePageIndex(
        fixed,
        ownerPageIndex: 5,
      ),
      2,
    );
    expect(
      WordPaginationService.effectivePageIndex(
        object,
        ownerPageIndex: 5,
      ),
      5,
    );
    expect(fixed.exceedsNormalizedBounds, isTrue);
    expect(fitted.exceedsNormalizedBounds, isFalse);
    expect(fitted.x + fitted.width, lessThanOrEqualTo(1));
    expect(fitted.y + fitted.height, lessThanOrEqualTo(1));
  });

  test('Phase 6 floating geometry persists independently of inline geometry', () {
    const diagram = GeometryDiagram(id: 'geometry-1', name: 'Triangle');
    final object = WordShapeService.createGeometry(diagram).copyWith(
      anchorMode: WordObjectAnchorMode.fixedOnPage,
      fixedPageIndex: 1,
    );
    var question = Question(id: 'q', text: 'Find x.');
    question = WordShapeService.append(question, object);

    final restored = WordShapeService.shapesOf(question).single;
    final document = QuestionDocumentProjection.fromQuestion(question);

    expect(restored.kind, WordShapeKind.geometry);
    expect(restored.geometryDiagram?.id, 'geometry-1');
    expect(restored.borderVisible, isFalse);
    expect(restored.aspectRatioLocked, isTrue);
    expect(document.hasFloatingGeometry, isTrue);
    expect(document.hasFixedPageObjects, isTrue);
    expect(document.hasGeometry, isFalse);
  });
}
