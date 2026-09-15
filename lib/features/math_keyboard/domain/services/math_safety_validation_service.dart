import '../../../editor/domain/models/math_expression.dart';
import 'math_compatibility_service.dart';

enum MathValidationSeverity { info, warning, error }

enum MathValidationIssueCode {
  emptySource,
  malformedSyntax,
  missingReadableFallback,
  futureFormatVersion,
  resourceBudgetExceeded,
  screenFallback,
  pdfFallback,
  wordFallback,
}

enum MathSafeFailureAction {
  none,
  useReadableFallback,
  keepSourceOnly,
  dropEmptyExpression,
  preserveFutureSource,
}

class MathValidationIssue {
  final MathValidationIssueCode code;
  final MathValidationSeverity severity;
  final MathSafeFailureAction action;
  final String path;
  final String message;
  final bool blocksPersistence;

  const MathValidationIssue({
    required this.code,
    required this.severity,
    required this.action,
    required this.path,
    required this.message,
    this.blocksPersistence = false,
  });
}

class MathExpressionSafetyReport {
  final MathExpression expression;
  final MathSourceCompatibilityReport compatibility;
  final List<MathValidationIssue> issues;

  const MathExpressionSafetyReport({
    required this.expression,
    required this.compatibility,
    required this.issues,
  });

  bool get canPersist => !issues.any((issue) => issue.blocksPersistence);
  bool get hasErrors =>
      issues.any((issue) => issue.severity == MathValidationSeverity.error);
  bool get usesScreenFallback =>
      compatibility.screenRenderer.support == MathCompatibilitySupport.fallback;
  bool get usesPdfFallback =>
      compatibility.pdfExport.support == MathCompatibilitySupport.fallback;
  bool get usesWordFallback =>
      compatibility.wordExport.support == MathCompatibilitySupport.fallback;

  String get readableFallback => compatibility.readableFallback;
}

/// Typed validation policy shared by authoring, persistence and exports.
///
/// A malformed formula is not treated as permission to discard user source.
/// When a readable fallback exists the source remains persistable while unsafe
/// consumers are forced onto that fallback. Only an empty expression with no
/// source is considered non-persistable as a math object.
class MathSafetyValidationService {
  final MathCompatibilityService compatibilityService;
  final bool useSharedCompatibilityCache;

  const MathSafetyValidationService({
    this.compatibilityService = const MathCompatibilityService(),
    this.useSharedCompatibilityCache = true,
  });

  MathExpressionSafetyReport inspect(
    MathExpression expression, {
    String path = 'formula',
  }) {
    final compatibility = useSharedCompatibilityCache
        ? MathCompatibilityCache.shared.inspectSource(
            expression.latex,
            plainFallback: expression.plainText,
          )
        : compatibilityService.inspectSource(
            expression.latex,
            plainFallback: expression.plainText,
          );
    final issues = <MathValidationIssue>[];
    final source = expression.latex.trim();

    if (source.isEmpty) {
      issues.add(
        MathValidationIssue(
          code: MathValidationIssueCode.emptySource,
          severity: MathValidationSeverity.error,
          action: MathSafeFailureAction.dropEmptyExpression,
          path: path,
          message:
              'Formula source is empty and cannot be kept as a math object.',
          blocksPersistence: true,
        ),
      );
    } else if (compatibility.resourceLimited) {
      issues.add(
        MathValidationIssue(
          code: MathValidationIssueCode.resourceBudgetExceeded,
          severity: MathValidationSeverity.warning,
          action: MathSafeFailureAction.useReadableFallback,
          path: path,
          message:
              compatibility.resourceMessage ??
              'Formula exceeds native processing complexity limits.',
        ),
      );
    } else if (!compatibility.syntaxValid) {
      issues.add(
        MathValidationIssue(
          code: MathValidationIssueCode.malformedSyntax,
          severity: MathValidationSeverity.error,
          action: MathSafeFailureAction.useReadableFallback,
          path: path,
          message:
              compatibility.syntaxMessage ?? 'Formula syntax is malformed.',
        ),
      );
    }

    if (source.isNotEmpty && compatibility.readableFallback.trim().isEmpty) {
      issues.add(
        MathValidationIssue(
          code: MathValidationIssueCode.missingReadableFallback,
          severity: MathValidationSeverity.error,
          action: MathSafeFailureAction.keepSourceOnly,
          path: path,
          message: 'Formula has no readable fallback for safe failure.',
          blocksPersistence: true,
        ),
      );
    }

    if (expression.formatVersion > MathExpression.currentFormatVersion) {
      issues.add(
        MathValidationIssue(
          code: MathValidationIssueCode.futureFormatVersion,
          severity: MathValidationSeverity.warning,
          action: MathSafeFailureAction.preserveFutureSource,
          path: path,
          message:
              'Formula was written by a newer math format. Source is preserved without destructive conversion.',
        ),
      );
    }

    if (source.isNotEmpty &&
        compatibility.screenRenderer.support ==
            MathCompatibilitySupport.fallback) {
      issues.add(
        MathValidationIssue(
          code: MathValidationIssueCode.screenFallback,
          severity: MathValidationSeverity.warning,
          action: MathSafeFailureAction.useReadableFallback,
          path: path,
          message: 'Screen renderer will use the readable fallback.',
        ),
      );
    }
    if (source.isNotEmpty &&
        compatibility.pdfExport.support == MathCompatibilitySupport.fallback) {
      issues.add(
        MathValidationIssue(
          code: MathValidationIssueCode.pdfFallback,
          severity: MathValidationSeverity.info,
          action: MathSafeFailureAction.useReadableFallback,
          path: path,
          message: 'PDF export will use the readable fallback.',
        ),
      );
    }
    if (source.isNotEmpty &&
        compatibility.wordExport.support == MathCompatibilitySupport.fallback) {
      issues.add(
        MathValidationIssue(
          code: MathValidationIssueCode.wordFallback,
          severity: MathValidationSeverity.info,
          action: MathSafeFailureAction.useReadableFallback,
          path: path,
          message: 'Word export will use the readable fallback.',
        ),
      );
    }

    return MathExpressionSafetyReport(
      expression: expression,
      compatibility: compatibility,
      issues: List.unmodifiable(issues),
    );
  }

  /// Returns null only for an expression that cannot safely exist as math.
  /// Malformed-but-readable source is intentionally preserved verbatim.
  MathExpression? repairForPersistence(
    MathExpression expression, {
    String path = 'formula',
  }) {
    final report = inspect(expression, path: path);
    if (!report.canPersist) return null;
    return expression;
  }
}
