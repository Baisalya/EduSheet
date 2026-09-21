import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/paper_composer/application/question_print_content_projection.dart';
import 'package:edusheet/features/paper_composer/application/word_pagination_service.dart';
import 'package:edusheet/features/paper_composer/application/word_shape_service.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';

enum PaperFidelitySeverity { warning, blocking }

class PaperFidelityIssue {
  final String code;
  final String message;
  final PaperFidelitySeverity severity;
  final String? questionId;
  final String? objectId;

  const PaperFidelityIssue({
    required this.code,
    required this.message,
    required this.severity,
    this.questionId,
    this.objectId,
  });
}

class PaperExportFidelityReport {
  final List<PaperFidelityIssue> issues;

  const PaperExportFidelityReport(this.issues);

  bool get productionReady =>
      issues.every((issue) => issue.severity != PaperFidelitySeverity.blocking);

  List<PaperFidelityIssue> get blockingIssues => issues
      .where((issue) => issue.severity == PaperFidelitySeverity.blocking)
      .toList(growable: false);

  List<PaperFidelityIssue> get warnings => issues
      .where((issue) => issue.severity == PaperFidelitySeverity.warning)
      .toList(growable: false);
}

/// Model-level production certification shared by Preview/PDF/DOCX gates.
///
/// The audit does not try to predict automatic line wrapping performed by a
/// renderer. It validates the canonical invariants that every renderer depends
/// on: parseable rich content, unique floating-object identity, complete
/// geometry payloads, printable floating bounds and usable page/column space.
class PaperExportFidelityAudit {
  const PaperExportFidelityAudit._();

  static const double _minimumPrintableExtentPoints = 72;

  static PaperExportFidelityReport audit(Paper paper) {
    final issues = <PaperFidelityIssue>[];
    _auditPageLayout(paper, issues);

    final pagination = WordPaginationService.planFor(paper);
    final questionIds = <String>{};

    for (final section in paper.sections) {
      for (final question in section.questions) {
        _auditQuestionTree(
          question,
          ownerPage: pagination.pageOfQuestion(question.id),
          questionIds: questionIds,
          issues: issues,
        );
      }
    }

    return PaperExportFidelityReport(List.unmodifiable(issues));
  }

  static void _auditPageLayout(Paper paper, List<PaperFidelityIssue> issues) {
    final explicitSize = paper.pageLayout.explicitPageSizePoints;
    if (explicitSize == null) return;

    final margins = paper.pageLayout.margins;
    final printableWidth =
        explicitSize.width - margins.leftPoints - margins.rightPoints;
    final printableHeight =
        explicitSize.height - margins.topPoints - margins.bottomPoints;

    if (printableWidth < _minimumPrintableExtentPoints ||
        printableHeight < _minimumPrintableExtentPoints) {
      issues.add(
        const PaperFidelityIssue(
          code: 'printable-area-too-small',
          message:
              'Page size and margins leave too little printable document area.',
          severity: PaperFidelitySeverity.blocking,
        ),
      );
      return;
    }

    final columns = paper.pageLayout.columns.explicitCount;
    if (columns != null && columns > 1) {
      final gaps = paper.pageLayout.columnSpacingPoints * (columns - 1);
      final perColumn = (printableWidth - gaps) / columns;
      if (perColumn < _minimumPrintableExtentPoints) {
        issues.add(
          const PaperFidelityIssue(
            code: 'column-width-too-small',
            message:
                'Column count and spacing leave too little printable width.',
            severity: PaperFidelitySeverity.blocking,
          ),
        );
      }
    }
  }

  static void _auditQuestionTree(
    Question question, {
    required int ownerPage,
    required Set<String> questionIds,
    required List<PaperFidelityIssue> issues,
  }) {
    if (!questionIds.add(question.id)) {
      issues.add(
        PaperFidelityIssue(
          code: 'duplicate-question-id',
          message: 'Question id ${question.id} is duplicated.',
          severity: PaperFidelitySeverity.blocking,
          questionId: question.id,
        ),
      );
    }

    final trimmed = question.text.trimLeft();
    final prompt = QuestionPrintContentProjection.fromRichText(question.text);
    if (trimmed.startsWith('[') && !prompt.isStructuredRichText) {
      issues.add(
        PaperFidelityIssue(
          code: 'malformed-rich-text',
          message: 'Question rich-text payload cannot be parsed safely.',
          severity: PaperFidelitySeverity.blocking,
          questionId: question.id,
        ),
      );
    }

    final objectIds = <String>{};
    for (final object in WordShapeService.shapesOf(question)) {
      if (!objectIds.add(object.id)) {
        issues.add(
          PaperFidelityIssue(
            code: 'duplicate-floating-object-id',
            message: 'Floating object id ${object.id} is duplicated.',
            severity: PaperFidelitySeverity.blocking,
            questionId: question.id,
            objectId: object.id,
          ),
        );
      }

      if (object.kind == WordShapeKind.geometry &&
          object.geometryDiagram == null) {
        issues.add(
          PaperFidelityIssue(
            code: 'geometry-payload-missing',
            message: 'Floating geometry has no canonical diagram payload.',
            severity: PaperFidelitySeverity.blocking,
            questionId: question.id,
            objectId: object.id,
          ),
        );
      }

      if (object.exceedsNormalizedBounds) {
        issues.add(
          PaperFidelityIssue(
            code: 'floating-object-outside-printable-bounds',
            message:
                'Floating object ${object.id} extends outside printable bounds.',
            severity: PaperFidelitySeverity.blocking,
            questionId: question.id,
            objectId: object.id,
          ),
        );
      }

      if (object.isFixedOnPage && object.fixedPageIndex != ownerPage) {
        issues.add(
          PaperFidelityIssue(
            code: 'fixed-object-page-intent-differs-from-owner',
            message:
                'Fixed object ${object.id} is pinned to page '
                '${object.fixedPageIndex + 1} while its owner is on page '
                '${ownerPage + 1}.',
            severity: PaperFidelitySeverity.warning,
            questionId: question.id,
            objectId: object.id,
          ),
        );
      }
    }

    for (final child in question.subQuestions) {
      _auditQuestionTree(
        child,
        ownerPage: ownerPage,
        questionIds: questionIds,
        issues: issues,
      );
    }
    for (final choice in question.internalChoices) {
      _auditQuestionTree(
        choice,
        ownerPage: ownerPage,
        questionIds: questionIds,
        issues: issues,
      );
    }
  }
}
