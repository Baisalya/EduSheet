import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/question_math_content.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_production_policy.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_safety_validation_service.dart';
import 'package:edusheet/features/paper_composer/application/question_math_surface_service.dart';
import 'package:edusheet/features/paper_composer/application/question_rich_text_codec.dart';

import 'package:flutter_quill/flutter_quill.dart';

enum QuestionMathIntegrityIssueCode {
  malformedRichText,
  malformedMathEmbed,
  malformedSurfaceMetadata,
  futureSurfaceMetadataVersion,
  staleSurface,
  orphanSurface,
  emptyExpressionId,
  conflictingExpressionId,
  missingCanonicalExpression,
  duplicateCanonicalExpression,
  invalidFormula,
  futureFormulaVersion,
  validationDepthLimit,
  resourceBudgetExceeded,
}

enum QuestionMathRepairAction {
  none,
  normalizedRichText,
  replacedMalformedEmbedWithFallback,
  droppedInvalidSurfaceMetadata,
  preservedFutureSurfaceMetadata,
  droppedStaleSurface,
  droppedOrphanSurface,
  assignedExpressionId,
  reassignedConflictingExpressionId,
  rebuiltCanonicalExpressionIndex,
  preservedSourceWithFallback,
  preservedFutureFormula,
  stoppedAtResourceBoundary,
}

class QuestionMathIntegrityIssue {
  final QuestionMathIntegrityIssueCode code;
  final MathValidationSeverity severity;
  final QuestionMathRepairAction action;
  final String path;
  final String message;

  const QuestionMathIntegrityIssue({
    required this.code,
    required this.severity,
    required this.action,
    required this.path,
    required this.message,
  });
}

class QuestionMathValidationResult {
  final Question safeQuestion;
  final List<QuestionMathIntegrityIssue> issues;
  final int formulaCount;
  final int invalidFormulaCount;
  final int screenFallbackCount;
  final int pdfFallbackCount;
  final int wordFallbackCount;

  const QuestionMathValidationResult({
    required this.safeQuestion,
    required this.issues,
    required this.formulaCount,
    required this.invalidFormulaCount,
    required this.screenFallbackCount,
    required this.pdfFallbackCount,
    required this.wordFallbackCount,
  });

  bool get hasErrors =>
      issues.any((issue) => issue.severity == MathValidationSeverity.error);
  bool get hasWarnings =>
      issues.any((issue) => issue.severity == MathValidationSeverity.warning);
  bool get usedSafeFailure =>
      invalidFormulaCount > 0 ||
      screenFallbackCount > 0 ||
      pdfFallbackCount > 0 ||
      wordFallbackCount > 0 ||
      issues.any((issue) => issue.action != QuestionMathRepairAction.none);

  String get summary {
    if (issues.isEmpty && !usedSafeFailure) return 'Math validation passed.';
    final repaired = issues
        .where((issue) => issue.action != QuestionMathRepairAction.none)
        .length;
    return 'Math validation: $formulaCount formula(s), '
        '$invalidFormulaCount malformed, $repaired repair(s), '
        '$screenFallbackCount screen fallback(s), '
        '$pdfFallbackCount PDF fallback(s), '
        '$wordFallbackCount Word fallback(s).';
  }
}

class PaperMathValidationResult {
  final Paper safePaper;
  final List<QuestionMathIntegrityIssue> issues;
  final int formulaCount;
  final int invalidFormulaCount;
  final int screenFallbackCount;
  final int pdfFallbackCount;
  final int wordFallbackCount;

  const PaperMathValidationResult({
    required this.safePaper,
    required this.issues,
    required this.formulaCount,
    required this.invalidFormulaCount,
    required this.screenFallbackCount,
    required this.pdfFallbackCount,
    required this.wordFallbackCount,
  });
}

/// Strong integrity validation for every math representation owned by a
/// question. It validates and safely reconciles:
///
/// * Quill math embeds in the question body;
/// * Phase 7 Math Everywhere surface metadata;
/// * the canonical [Question.mathExpressions] mirror/index;
/// * nested sub-questions and internal choices.
///
/// Repairs never rewrite TeX. Malformed source stays preserved and consumers
/// use the Phase 6 readable fallback. Structural corruption (stale metadata,
/// malformed embeds, duplicate/conflicting IDs) is repaired on a copy so save
/// and export boundaries cannot silently propagate broken references.
class QuestionMathValidationService {
  final QuestionRichTextCodec richTextCodec;
  final QuestionMathSurfaceService surfaceService;
  final MathSafetyValidationService mathSafety;

  const QuestionMathValidationService({
    this.richTextCodec = const QuestionRichTextCodec(),
    this.surfaceService = const QuestionMathSurfaceService(),
    this.mathSafety = const MathSafetyValidationService(),
  });

  QuestionMathValidationResult validateAndRepair(
    Question question, {
    String path = 'question',
  }) {
    final accumulator = _ValidationAccumulator();
    final safe = _repairQuestion(question, path, accumulator, 0);
    return QuestionMathValidationResult(
      safeQuestion: safe,
      issues: List.unmodifiable(accumulator.issues),
      formulaCount: accumulator.formulaCount,
      invalidFormulaCount: accumulator.invalidFormulaCount,
      screenFallbackCount: accumulator.screenFallbackCount,
      pdfFallbackCount: accumulator.pdfFallbackCount,
      wordFallbackCount: accumulator.wordFallbackCount,
    );
  }

  PaperMathValidationResult validateAndRepairPaper(Paper paper) {
    final allIssues = <QuestionMathIntegrityIssue>[];
    var formulaCount = 0;
    var invalidFormulaCount = 0;
    var screenFallbackCount = 0;
    var pdfFallbackCount = 0;
    var wordFallbackCount = 0;

    final sections = paper.sections.asMap().entries.map((sectionEntry) {
      final section = sectionEntry.value;
      final questions = section.questions.asMap().entries.map((questionEntry) {
        final result = validateAndRepair(
          questionEntry.value,
          path: 'section[${sectionEntry.key}].question[${questionEntry.key}]',
        );
        allIssues.addAll(result.issues);
        formulaCount += result.formulaCount;
        invalidFormulaCount += result.invalidFormulaCount;
        screenFallbackCount += result.screenFallbackCount;
        pdfFallbackCount += result.pdfFallbackCount;
        wordFallbackCount += result.wordFallbackCount;
        return result.safeQuestion;
      }).toList();
      return section.copyWith(questions: questions);
    }).toList();

    return PaperMathValidationResult(
      safePaper: paper.copyWith(sections: sections),
      issues: List.unmodifiable(allIssues),
      formulaCount: formulaCount,
      invalidFormulaCount: invalidFormulaCount,
      screenFallbackCount: screenFallbackCount,
      pdfFallbackCount: pdfFallbackCount,
      wordFallbackCount: wordFallbackCount,
    );
  }

  Question _repairQuestion(
    Question question,
    String path,
    _ValidationAccumulator accumulator,
    int depth,
  ) {
    if (depth > MathProductionLimits.maxQuestionNestingDepth) {
      accumulator.issues.add(
        QuestionMathIntegrityIssue(
          code: QuestionMathIntegrityIssueCode.validationDepthLimit,
          severity: MathValidationSeverity.warning,
          action: QuestionMathRepairAction.stoppedAtResourceBoundary,
          path: path,
          message:
              'Nested question depth exceeds the production validation limit (${MathProductionLimits.maxQuestionNestingDepth}); the deeper subtree was preserved without recursive normalization.',
        ),
      );
      return question;
    }
    final canonicalizer = _ExpressionIdCanonicalizer(
      questionId: question.id,
      accumulator: accumulator,
    );

    final futureSurfaceMetadata = _inspectRawSurfaceMetadata(
      question,
      path,
      accumulator,
    );

    final inspection = richTextCodec.inspectQuestion(question);
    if (inspection.malformedRichText) {
      accumulator.issues.add(
        QuestionMathIntegrityIssue(
          code: QuestionMathIntegrityIssueCode.malformedRichText,
          severity: MathValidationSeverity.error,
          action: QuestionMathRepairAction.normalizedRichText,
          path: '$path.body',
          message:
              'Malformed rich-text JSON was converted to a safe readable Quill document.',
        ),
      );
    }
    if (inspection.malformedMathEmbedCount > 0) {
      accumulator.issues.add(
        QuestionMathIntegrityIssue(
          code: QuestionMathIntegrityIssueCode.malformedMathEmbed,
          severity: MathValidationSeverity.error,
          action: QuestionMathRepairAction.replacedMalformedEmbedWithFallback,
          path: '$path.body',
          message:
              '${inspection.malformedMathEmbedCount} malformed math embed(s) were replaced with [formula] fallback text.',
        ),
      );
    }

    final bodyRepair = _repairBody(
      inspection.document,
      path,
      canonicalizer,
      accumulator,
    );

    final rawContent = futureSurfaceMetadata
        ? QuestionMathContent.empty
        : QuestionMathContent.fromQuestion(question);
    final currentSurfaces = surfaceService.currentSurfaceTextForQuestion(
      question,
    );
    for (final entry in rawContent.surfaces.entries) {
      final current = currentSurfaces[entry.key];
      if (current == null) {
        accumulator.issues.add(
          QuestionMathIntegrityIssue(
            code: QuestionMathIntegrityIssueCode.orphanSurface,
            severity: MathValidationSeverity.warning,
            action: QuestionMathRepairAction.droppedOrphanSurface,
            path: '$path.surface[${entry.key}]',
            message:
                'Structured math surface no longer exists in the question and was safely detached.',
          ),
        );
      } else if (current != entry.value.fallbackText) {
        accumulator.issues.add(
          QuestionMathIntegrityIssue(
            code: QuestionMathIntegrityIssueCode.staleSurface,
            severity: MathValidationSeverity.warning,
            action: QuestionMathRepairAction.droppedStaleSurface,
            path: '$path.surface[${entry.key}]',
            message:
                'Structured math no longer matches the edited fallback text and was safely detached.',
          ),
        );
      }
    }

    final activeContent = rawContent.retainMatching(currentSurfaces);
    final mappedSurfaces = <String, QuestionMathInlineDocument>{};
    final originalOwnedKeys = <String>{...bodyRepair.originalExpressionKeys};
    final mappedOwned = <MathExpression>[...bodyRepair.expressions];

    for (final entry in activeContent.surfaces.entries) {
      var mathIndex = 0;
      final parts = <QuestionMathInlinePart>[];
      for (final part in entry.value.parts) {
        if (part.kind == QuestionMathInlinePartKind.text ||
            part.expression == null) {
          parts.add(QuestionMathInlinePart.text(part.text));
          continue;
        }
        final expression = part.expression!;
        originalOwnedKeys.add(_expressionMirrorKey(expression));
        final location = '$path.surface[${entry.key}].math[$mathIndex]';
        mathIndex += 1;
        final repaired = _inspectExpression(
          expression,
          location,
          canonicalizer,
          accumulator,
        );
        if (repaired == null) continue;
        parts.add(QuestionMathInlinePart.math(repaired));
        mappedOwned.add(repaired);
      }
      final document = QuestionMathInlineDocument(parts: parts).normalized();
      if (document.hasMath) mappedSurfaces[entry.key] = document;
    }

    final mappedContent = QuestionMathContent(surfaces: mappedSurfaces);
    final originalCanonicalCounts = <String, int>{};
    for (final expression in question.mathExpressions) {
      final key = _expressionMirrorKey(expression);
      originalCanonicalCounts[key] = (originalCanonicalCounts[key] ?? 0) + 1;
    }
    if (originalCanonicalCounts.values.any((count) => count > 1)) {
      accumulator.issues.add(
        QuestionMathIntegrityIssue(
          code: QuestionMathIntegrityIssueCode.duplicateCanonicalExpression,
          severity: MathValidationSeverity.warning,
          action: QuestionMathRepairAction.rebuiltCanonicalExpressionIndex,
          path: '$path.mathExpressions',
          message:
              'Duplicate canonical math entries were collapsed without removing placed formulas.',
        ),
      );
    }
    for (final ownedKey in originalOwnedKeys) {
      if (!originalCanonicalCounts.containsKey(ownedKey)) {
        accumulator.issues.add(
          QuestionMathIntegrityIssue(
            code: QuestionMathIntegrityIssueCode.missingCanonicalExpression,
            severity: MathValidationSeverity.warning,
            action: QuestionMathRepairAction.rebuiltCanonicalExpressionIndex,
            path: '$path.mathExpressions',
            message:
                'A placed formula was missing from the canonical math index; the index was rebuilt.',
          ),
        );
        break;
      }
    }

    final mappedUnplaced = <MathExpression>[];
    for (final entry in question.mathExpressions.asMap().entries) {
      final expression = entry.value;
      if (originalOwnedKeys.contains(_expressionMirrorKey(expression))) {
        continue;
      }
      final repaired = _inspectExpression(
        expression,
        '$path.mathExpressions[${entry.key}]',
        canonicalizer,
        accumulator,
      );
      if (repaired != null) mappedUnplaced.add(repaired);
    }

    final canonicalExpressions = _dedupeExactExpressions([
      ...mappedOwned,
      ...mappedUnplaced,
    ]);
    var metadata = futureSurfaceMetadata
        ? question.metadata
        : mappedContent.writeToMetadata(question.metadata);

    final subQuestions = question.subQuestions.asMap().entries.map((entry) {
      return _repairQuestion(
        entry.value,
        '$path.subQuestions[${entry.key}]',
        accumulator,
        depth + 1,
      );
    }).toList();
    final internalChoices = question.internalChoices.asMap().entries.map((
      entry,
    ) {
      return _repairQuestion(
        entry.value,
        '$path.internalChoices[${entry.key}]',
        accumulator,
        depth + 1,
      );
    }).toList();

    final shouldEncodeBody =
        !inspection.usedLegacyPlainText ||
        inspection.needsRepair ||
        bodyRepair.changed;
    final safeText = shouldEncodeBody
        ? jsonEncode(bodyRepair.operations)
        : question.text;

    if (!futureSurfaceMetadata &&
        !mappedContent.hasAny &&
        question.metadata.containsKey(QuestionMathContent.metadataKey)) {
      metadata = Map<String, dynamic>.from(metadata)
        ..remove(QuestionMathContent.metadataKey);
    }

    final bodyWasRepaired = inspection.needsRepair || bodyRepair.changed;

    return question.copyWith(
      text: safeText,
      richTextFormat: shouldEncodeBody
          ? 'quill-delta-json-v1'
          : question.richTextFormat,
      plainTextAccessibility: bodyWasRepaired
          ? richTextCodec.accessibleText(
              Document.fromJson(bodyRepair.operations),
            )
          : question.plainTextAccessibility,
      mathExpressions: canonicalExpressions,
      metadata: metadata,
      subQuestions: subQuestions,
      internalChoices: internalChoices,
      modifiedAt: question.modifiedAt,
    );
  }

  _BodyRepair _repairBody(
    Document document,
    String path,
    _ExpressionIdCanonicalizer canonicalizer,
    _ValidationAccumulator accumulator,
  ) {
    final operations = <Map<String, dynamic>>[];
    final expressions = <MathExpression>[];
    final originalKeys = <String>{};
    var mathIndex = 0;
    var changed = false;

    for (final raw in document.toDelta().toJson()) {
      final operation = Map<String, dynamic>.from(raw);
      final insert = operation['insert'];
      if (insert is Map && insert.containsKey(MathExpression.quillEmbedKey)) {
        final expression = richTextCodec.expressionFromInsert(insert);
        if (expression == null) {
          operation['insert'] = '[formula]';
          changed = true;
        } else {
          originalKeys.add(_expressionMirrorKey(expression));
          final repaired = _inspectExpression(
            expression,
            '$path.body.math[$mathIndex]',
            canonicalizer,
            accumulator,
          );
          mathIndex += 1;
          if (repaired == null) {
            operation['insert'] = '[formula]';
            changed = true;
          } else {
            final mappedInsert = Map<String, dynamic>.from(insert);
            mappedInsert[MathExpression.quillEmbedKey] = repaired
                .toQuillEmbedData();
            operation['insert'] = mappedInsert;
            expressions.add(repaired);
            changed = changed || repaired.id != expression.id;
          }
        }
      }
      operations.add(operation);
    }

    return _BodyRepair(
      operations: operations,
      expressions: expressions,
      originalExpressionKeys: originalKeys,
      changed: changed,
    );
  }

  MathExpression? _inspectExpression(
    MathExpression expression,
    String path,
    _ExpressionIdCanonicalizer canonicalizer,
    _ValidationAccumulator accumulator,
  ) {
    final safety = mathSafety.inspect(expression, path: path);
    accumulator.formulaCount += 1;
    if (safety.compatibility.resourceLimited) {
      accumulator.issues.add(
        QuestionMathIntegrityIssue(
          code: QuestionMathIntegrityIssueCode.resourceBudgetExceeded,
          severity: MathValidationSeverity.warning,
          action: QuestionMathRepairAction.preservedSourceWithFallback,
          path: path,
          message:
              '${safety.compatibility.resourceMessage ?? 'Formula exceeds native processing limits.'} Source was preserved and consumers will use the readable fallback.',
        ),
      );
    } else if (!safety.compatibility.syntaxValid) {
      accumulator.invalidFormulaCount += 1;
      accumulator.issues.add(
        QuestionMathIntegrityIssue(
          code: QuestionMathIntegrityIssueCode.invalidFormula,
          severity: MathValidationSeverity.error,
          action: QuestionMathRepairAction.preservedSourceWithFallback,
          path: path,
          message:
              '${safety.compatibility.syntaxMessage ?? 'Malformed formula.'} Source was preserved and unsafe consumers will use the readable fallback.',
        ),
      );
    }
    if (safety.usesScreenFallback) accumulator.screenFallbackCount += 1;
    if (safety.usesPdfFallback) accumulator.pdfFallbackCount += 1;
    if (safety.usesWordFallback) accumulator.wordFallbackCount += 1;
    if (expression.formatVersion > MathExpression.currentFormatVersion) {
      accumulator.issues.add(
        QuestionMathIntegrityIssue(
          code: QuestionMathIntegrityIssueCode.futureFormulaVersion,
          severity: MathValidationSeverity.warning,
          action: QuestionMathRepairAction.preservedFutureFormula,
          path: path,
          message:
              'Newer formula format was preserved without destructive conversion.',
        ),
      );
    }

    final persistable = mathSafety.repairForPersistence(expression, path: path);
    if (persistable == null) return null;
    return canonicalizer.canonicalize(persistable, path);
  }

  bool _inspectRawSurfaceMetadata(
    Question question,
    String path,
    _ValidationAccumulator accumulator,
  ) {
    if (!question.metadata.containsKey(QuestionMathContent.metadataKey)) {
      return false;
    }
    final raw = question.metadata[QuestionMathContent.metadataKey];
    if (raw is! Map || raw['surfaces'] is! Map) {
      accumulator.issues.add(
        QuestionMathIntegrityIssue(
          code: QuestionMathIntegrityIssueCode.malformedSurfaceMetadata,
          severity: MathValidationSeverity.error,
          action: QuestionMathRepairAction.droppedInvalidSurfaceMetadata,
          path: '$path.metadata.${QuestionMathContent.metadataKey}',
          message:
              'Malformed structured-math metadata was ignored; readable legacy field text was preserved.',
        ),
      );
      return false;
    }
    final version = _intValue(raw['version'], 1);
    if (version > 1) {
      accumulator.issues.add(
        QuestionMathIntegrityIssue(
          code: QuestionMathIntegrityIssueCode.futureSurfaceMetadataVersion,
          severity: MathValidationSeverity.warning,
          action: QuestionMathRepairAction.preservedFutureSurfaceMetadata,
          path: '$path.metadata.${QuestionMathContent.metadataKey}',
          message:
              'Structured-math metadata version $version is newer than this app. The unknown metadata was preserved and legacy field text is used safely.',
        ),
      );
      return true;
    }
    final surfaces = raw['surfaces'] as Map;
    final malformed = surfaces.values.any((value) {
      if (value is! Map) return true;
      final parts = value['parts'];
      if (parts != null && parts is! List) return true;
      if (parts is List) {
        for (final rawPart in parts) {
          if (rawPart is! Map) return true;
          if (rawPart['kind']?.toString() == 'math') {
            final rawExpression = rawPart['expression'];
            if (rawExpression is! Map) return true;
            try {
              final expression = MathExpression.fromJson(
                Map<String, dynamic>.from(rawExpression),
              );
              if (expression.latex.trim().isEmpty) return true;
            } catch (_) {
              return true;
            }
          }
        }
      }
      return false;
    });
    if (malformed) {
      accumulator.issues.add(
        QuestionMathIntegrityIssue(
          code: QuestionMathIntegrityIssueCode.malformedSurfaceMetadata,
          severity: MathValidationSeverity.error,
          action: QuestionMathRepairAction.droppedInvalidSurfaceMetadata,
          path: '$path.metadata.${QuestionMathContent.metadataKey}',
          message:
              'Malformed structured-math entries were discarded while their readable field text remained intact.',
        ),
      );
    }
    return false;
  }

  static List<MathExpression> _dedupeExactExpressions(
    Iterable<MathExpression> values,
  ) {
    final result = <MathExpression>[];
    final seen = <String>{};
    for (final expression in values) {
      final key = '${expression.id}\u0000${_payloadSignature(expression)}';
      if (seen.add(key)) result.add(expression);
    }
    return result;
  }

  static String _expressionMirrorKey(MathExpression expression) =>
      expression.persistentIdentity;

  static String _payloadSignature(MathExpression expression) =>
      expression.payloadIdentity;
}

int _intValue(dynamic value, int fallback) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

class _ExpressionIdCanonicalizer {
  final String questionId;
  final _ValidationAccumulator accumulator;
  final Map<String, String> _signatureById = <String, String>{};

  _ExpressionIdCanonicalizer({
    required this.questionId,
    required this.accumulator,
  });

  MathExpression canonicalize(MathExpression expression, String path) {
    final signature = QuestionMathValidationService._payloadSignature(
      expression,
    );
    var id = expression.id.trim();
    if (id.isEmpty) {
      id = _freshId(path, signature);
      accumulator.issues.add(
        QuestionMathIntegrityIssue(
          code: QuestionMathIntegrityIssueCode.emptyExpressionId,
          severity: MathValidationSeverity.warning,
          action: QuestionMathRepairAction.assignedExpressionId,
          path: path,
          message: 'Formula had no stable ID; a deterministic ID was assigned.',
        ),
      );
      _signatureById[id] = signature;
      return expression.copyWith(id: id);
    }

    final existing = _signatureById[id];
    if (existing == null) {
      _signatureById[id] = signature;
      return expression;
    }
    if (existing == signature) return expression;

    final repairedId = _freshId('$path:$id', signature);
    accumulator.issues.add(
      QuestionMathIntegrityIssue(
        code: QuestionMathIntegrityIssueCode.conflictingExpressionId,
        severity: MathValidationSeverity.error,
        action: QuestionMathRepairAction.reassignedConflictingExpressionId,
        path: path,
        message:
            'Formula ID "$id" referred to different formula payloads; the conflicting formula received a new stable ID.',
      ),
    );
    _signatureById[repairedId] = signature;
    return expression.copyWith(id: repairedId);
  }

  String _freshId(String path, String signature) {
    var attempt = 0;
    while (true) {
      final seed = '$questionId|$path|$signature|$attempt';
      var hash = 0x811C9DC5;
      for (final unit in seed.codeUnits) {
        hash ^= unit;
        hash = (hash * 0x01000193) & 0xFFFFFFFF;
      }
      final id = 'math.safe.${hash.toRadixString(16).padLeft(8, '0')}';
      if (!_signatureById.containsKey(id)) return id;
      attempt += 1;
    }
  }
}

class _ValidationAccumulator {
  final List<QuestionMathIntegrityIssue> issues = [];
  int formulaCount = 0;
  int invalidFormulaCount = 0;
  int screenFallbackCount = 0;
  int pdfFallbackCount = 0;
  int wordFallbackCount = 0;
}

class _BodyRepair {
  final List<Map<String, dynamic>> operations;
  final List<MathExpression> expressions;
  final Set<String> originalExpressionKeys;
  final bool changed;

  const _BodyRepair({
    required this.operations,
    required this.expressions,
    required this.originalExpressionKeys,
    required this.changed,
  });
}
