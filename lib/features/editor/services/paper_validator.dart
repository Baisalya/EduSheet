import 'dart:convert';

import '../domain/models/paper_model.dart';

enum PaperIssueSeverity { info, warning, error }

class PaperIssue {
  final String code;
  final String message;
  final PaperIssueSeverity severity;
  final String? sectionId;
  final String? questionId;

  const PaperIssue({
    required this.code,
    required this.message,
    required this.severity,
    this.sectionId,
    this.questionId,
  });
}

class PaperValidationResult {
  final double calculatedMarks;
  final double? expectedMarks;
  final List<PaperIssue> issues;

  const PaperValidationResult({
    required this.calculatedMarks,
    required this.expectedMarks,
    required this.issues,
  });

  bool get hasErrors =>
      issues.any((issue) => issue.severity == PaperIssueSeverity.error);
  int get warningCount => issues
      .where((issue) => issue.severity == PaperIssueSeverity.warning)
      .length;
}

class PaperValidator {
  static final RegExp _templateVariable = RegExp(
    r'\{\{\s*([a-zA-Z0-9_]+)\s*\}\}',
  );

  const PaperValidator();

  PaperValidationResult validate(Paper paper) {
    final issues = <PaperIssue>[];
    final questionIds = <String>{};
    final duplicateQuestionIds = <String>{};

    if (paper.sections.isEmpty) {
      issues.add(
        const PaperIssue(
          code: 'paper.empty',
          message: 'Add at least one section.',
          severity: PaperIssueSeverity.error,
        ),
      );
    }

    for (final section in paper.sections) {
      if (section.title.trim().isEmpty) {
        issues.add(
          PaperIssue(
            code: 'section.title_missing',
            message: 'A section is missing its title.',
            severity: PaperIssueSeverity.warning,
            sectionId: section.id,
          ),
        );
      }
      final assessmentQuestionCount = section.questions
          .where((question) => !question.isWordContentBlock)
          .length;
      if (assessmentQuestionCount == 0) {
        issues.add(
          PaperIssue(
            code: 'section.empty',
            message: '${_sectionName(section)} has no questions.',
            severity: PaperIssueSeverity.warning,
            sectionId: section.id,
          ),
        );
      }
      final requiredCount = section.requiredCount;
      if (requiredCount != null &&
          (requiredCount <= 0 || requiredCount > assessmentQuestionCount)) {
        issues.add(
          PaperIssue(
            code: 'section.invalid_attempt_rule',
            message:
                '${_sectionName(section)} asks for $requiredCount of $assessmentQuestionCount questions.',
            severity: PaperIssueSeverity.error,
            sectionId: section.id,
          ),
        );
      }

      for (final question in section.questions) {
        if (!questionIds.add(question.id)) {
          duplicateQuestionIds.add(question.id);
        }
        if (question.isWordContentBlock) continue;
        if (question.plainTextAccessibility.trim().isEmpty &&
            question.mathExpressions.isEmpty) {
          issues.add(
            PaperIssue(
              code: 'question.empty',
              message: '${_sectionName(section)} contains an empty question.',
              severity: PaperIssueSeverity.error,
              sectionId: section.id,
              questionId: question.id,
            ),
          );
        }
        if (question.marks <= 0) {
          issues.add(
            PaperIssue(
              code: 'question.marks_missing',
              message: 'A question in ${_sectionName(section)} has no marks.',
              severity: PaperIssueSeverity.error,
              sectionId: section.id,
              questionId: question.id,
            ),
          );
        }
        if (question.type.usesOptions && question.options.length < 2) {
          issues.add(
            PaperIssue(
              code: 'question.options_missing',
              message: 'An option question needs at least two options.',
              severity: PaperIssueSeverity.error,
              sectionId: section.id,
              questionId: question.id,
            ),
          );
        }
        if (question.type == QuestionType.internalChoice &&
            question.internalChoices.length < 2) {
          issues.add(
            PaperIssue(
              code: 'question.internal_choice_incomplete',
              message: 'An internal choice needs at least two alternatives.',
              severity: PaperIssueSeverity.error,
              sectionId: section.id,
              questionId: question.id,
            ),
          );
        }
      }
    }

    if (duplicateQuestionIds.isNotEmpty) {
      issues.add(
        PaperIssue(
          code: 'question.duplicate_id',
          message: 'Duplicate question records were detected.',
          severity: PaperIssueSeverity.error,
          questionId: duplicateQuestionIds.first,
        ),
      );
    }

    if (paper.questionNumberStyle == QuestionNumberStyle.custom) {
      final labels = paper.customQuestionNumberLabels
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty)
          .toList();
      if (labels.toSet().length != labels.length) {
        issues.add(
          const PaperIssue(
            code: 'numbering.duplicate',
            message: 'Custom question numbering contains duplicate labels.',
            severity: PaperIssueSeverity.error,
          ),
        );
      }
    }

    final unresolved = _templateVariable
        .allMatches(jsonEncode(paper.toJson()))
        .map((match) => match.group(1)!)
        .toSet();
    if (unresolved.isNotEmpty) {
      issues.add(
        PaperIssue(
          code: 'template.unresolved',
          message: 'Complete template fields: ${unresolved.join(', ')}.',
          severity: PaperIssueSeverity.warning,
        ),
      );
    }

    final calculated = paper.totalMarks;
    final expected = paper.maximumMarks ?? _headerMaximumMarks(paper);
    if (expected != null && (calculated - expected).abs() > 0.001) {
      issues.add(
        PaperIssue(
          code: 'marks.mismatch',
          message:
              'Calculated marks ${_marks(calculated)} do not match maximum marks ${_marks(expected)}.',
          severity: PaperIssueSeverity.error,
        ),
      );
    }

    return PaperValidationResult(
      calculatedMarks: calculated,
      expectedMarks: expected,
      issues: issues,
    );
  }

  double? _headerMaximumMarks(Paper paper) {
    for (final field in paper.headerFields) {
      final label = field.label.toLowerCase().replaceAll(' ', '');
      if (label.contains('maximummarks') || label == 'marks') {
        final value = double.tryParse(field.value.trim());
        if (value != null) return value;
      }
    }
    return null;
  }

  String _sectionName(PaperSection section) {
    return section.title.trim().isEmpty ? 'Untitled section' : section.title;
  }

  String _marks(double value) {
    return value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }
}
