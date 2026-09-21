import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/application/question_print_content_projection.dart';
import 'package:edusheet/features/paper_composer/application/universal_question_adapter.dart';
import 'package:edusheet/features/paper_composer/application/word_shape_service.dart';
import 'package:edusheet/features/paper_composer/application/word_pagination_service.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/paper_composer/domain/universal_question_document.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';

/// Read-only document boundary used by editor/preview/export code.
///
/// [Question] remains EduSheet's persistence contract. This projection exposes
/// that stored question as independent document content, so editor decorations
/// and transient selection state never become printable data.
class QuestionDocumentProjection {
  final Question source;
  final QuestionPrintContentDocument prompt;
  final UniversalQuestionDocument structure;
  final QuestionAdvancedContent advancedContent;
  final List<WordShapeObject> wordShapes;

  const QuestionDocumentProjection._({
    required this.source,
    required this.prompt,
    required this.structure,
    required this.advancedContent,
    required this.wordShapes,
  });

  factory QuestionDocumentProjection.fromQuestion(Question question) {
    return QuestionDocumentProjection._(
      source: question,
      prompt: QuestionPrintContentProjection.fromRichText(question.text),
      structure: UniversalQuestionAdapter.fromQuestion(question),
      advancedContent: QuestionAdvancedContent.fromQuestion(question),
      wordShapes: List.unmodifiable(WordShapeService.shapesOf(question)),
    );
  }

  bool get hasGeometry => prompt.geometryEmbeds.isNotEmpty;

  bool get hasFloatingObjects => wordShapes.isNotEmpty;

  bool get hasFixedPageObjects => wordShapes.any((item) => item.isFixedOnPage);

  bool get hasFloatingGeometry =>
      wordShapes.any((item) => item.isGeometryObject);

  bool containsBlock(UniversalQuestionBlockKind kind) =>
      structure.contains(kind);
}

/// Logical paper projection with an explicit authoring pagination plan.
/// Manual page/section breaks and fixed-page object intent are canonical here;
/// measured automatic pagination remains the responsibility of the active
/// editor/export layout engine.
class PaperDocumentProjection {
  final Paper source;
  final List<PaperSectionDocumentProjection> sections;
  final WordPaginationPlan pagination;

  const PaperDocumentProjection._({
    required this.source,
    required this.sections,
    required this.pagination,
  });

  factory PaperDocumentProjection.fromPaper(Paper paper) {
    return PaperDocumentProjection._(
      source: paper,
      pagination: WordPaginationService.planFor(paper),
      sections: List.unmodifiable([
        for (final section in paper.sections)
          PaperSectionDocumentProjection(
            source: section,
            questions: List.unmodifiable([
              for (final question in section.questions)
                QuestionDocumentProjection.fromQuestion(question),
            ]),
          ),
      ]),
    );
  }
}

class PaperSectionDocumentProjection {
  final PaperSection source;
  final List<QuestionDocumentProjection> questions;

  const PaperSectionDocumentProjection({
    required this.source,
    required this.questions,
  });
}
