import 'dart:math' as math;

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/application/word_content_block_service.dart';
import 'package:edusheet/features/paper_composer/application/word_shape_service.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';

/// Explicit pagination/anchoring contract for Word Mode.
///
/// EduSheet already persists manual page breaks and section page-break intent.
/// This service turns that intent into stable logical page indices without
/// inventing a second document model. Automatic export pagination is still
/// performed by the PDF/DOCX engines; these indices are the authoring contract
/// used by fixed-page floating objects and editor page diagnostics.
class WordPaginationPlan {
  final Map<String, int> questionPageIndex;
  final int pageCount;

  const WordPaginationPlan({
    required this.questionPageIndex,
    required this.pageCount,
  });

  int pageOfQuestion(String questionId) => questionPageIndex[questionId] ?? 0;
}

class WordPaginationService {
  const WordPaginationService._();

  static WordPaginationPlan planFor(Paper paper) {
    var pageIndex = 0;
    var hasContentOnPage = false;
    final pages = <String, int>{};
    var highestFixedPage = 0;

    for (final section in paper.sections) {
      if (section.pageBreakBefore && hasContentOnPage) {
        pageIndex += 1;
        hasContentOnPage = false;
      }
      for (final question in section.questions) {
        final kind = WordContentBlockService.kindOf(question);
        if (question.isWordContentBlock && kind == WordContentBlockKind.pageBreak) {
          pageIndex += 1;
          hasContentOnPage = false;
          continue;
        }
        pages[question.id] = pageIndex;
        hasContentOnPage = true;
        for (final shape in WordShapeService.shapesOf(question)) {
          if (shape.isFixedOnPage) {
            highestFixedPage = math.max(highestFixedPage, shape.fixedPageIndex);
          }
        }
      }
    }

    final inferredCount = paper.sections.isEmpty ? 1 : pageIndex + 1;
    return WordPaginationPlan(
      questionPageIndex: Map.unmodifiable(pages),
      pageCount: math.max(inferredCount, highestFixedPage + 1),
    );
  }

  static int effectivePageIndex(
    WordShapeObject object, {
    required int ownerPageIndex,
  }) {
    return object.isFixedOnPage ? object.fixedPageIndex : ownerPageIndex;
  }

  static WordShapeObject setAnchorMode(
    WordShapeObject object,
    WordObjectAnchorMode mode, {
    required int ownerPageIndex,
  }) {
    return object.copyWith(
      anchorMode: mode,
      fixedPageIndex: mode == WordObjectAnchorMode.fixedOnPage
          ? ownerPageIndex
          : object.fixedPageIndex,
    );
  }

  static WordShapeObject fitInsidePrintableBounds(WordShapeObject object) {
    final width = object.width.clamp(0.08, 1.0).toDouble();
    final height = object.height.clamp(0.08, 1.0).toDouble();
    return object.copyWith(
      x: object.x.clamp(0.0, math.max(0.0, 1.0 - width)).toDouble(),
      y: object.y.clamp(0.0, math.max(0.0, 1.0 - height)).toDouble(),
      width: width,
      height: height,
    );
  }
}
