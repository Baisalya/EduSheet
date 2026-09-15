import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import '../catalog/math_symbol_catalog.dart';
import '../models/math_symbol.dart';
import '../services/math_compatibility_service.dart';
import 'math_compatibility_audit.dart';

enum MathReleaseIssueSeverity { critical, high, medium, acceptedFallback }

enum MathReleaseIssueCode {
  catalogUnsafeSource,
  syntaxInvalid,
  persistenceMismatch,
  missingReadableFallback,
  visualSourceOnly,
  screenUnavailable,
  screenFallback,
  pdfUnavailable,
  pdfFallback,
  wordUnavailable,
  wordFallback,
  resourceLimited,
}

class MathReleaseCertificationCase {
  final String id;
  final String title;
  final MathSubject subject;
  final String latex;
  final String plainText;

  const MathReleaseCertificationCase({
    required this.id,
    required this.title,
    required this.subject,
    required this.latex,
    required this.plainText,
  });
}

class MathReleaseCertificationIssue {
  final MathReleaseIssueCode code;
  final MathReleaseIssueSeverity severity;
  final String caseId;
  final String message;

  const MathReleaseCertificationIssue({
    required this.code,
    required this.severity,
    required this.caseId,
    required this.message,
  });

  bool get blocksRelease =>
      severity == MathReleaseIssueSeverity.critical ||
      severity == MathReleaseIssueSeverity.high;
}

class MathReleaseCaseResult {
  final MathReleaseCertificationCase sample;
  final MathSourceCompatibilityReport compatibility;
  final List<MathReleaseCertificationIssue> issues;

  const MathReleaseCaseResult({
    required this.sample,
    required this.compatibility,
    required this.issues,
  });

  bool get hasBlocker => issues.any((issue) => issue.blocksRelease);
  bool get usesAcceptedFallback => issues.any(
    (issue) => issue.severity == MathReleaseIssueSeverity.acceptedFallback,
  );
}

class MathReleaseCertificationReport {
  final int catalogSemanticCount;
  final List<MathReleaseCaseResult> cases;
  final List<MathReleaseCertificationIssue> globalIssues;

  const MathReleaseCertificationReport({
    required this.catalogSemanticCount,
    required this.cases,
    required this.globalIssues,
  });

  Iterable<MathReleaseCertificationIssue> get issues sync* {
    yield* globalIssues;
    for (final result in cases) {
      yield* result.issues;
    }
  }

  int get caseCount => cases.length;
  int get blockerCount => issues.where((issue) => issue.blocksRelease).length;
  int get criticalCount => issues
      .where((issue) => issue.severity == MathReleaseIssueSeverity.critical)
      .length;
  int get highCount => issues
      .where((issue) => issue.severity == MathReleaseIssueSeverity.high)
      .length;
  int get mediumCount => issues
      .where((issue) => issue.severity == MathReleaseIssueSeverity.medium)
      .length;
  int get acceptedFallbackCount => issues
      .where(
        (issue) => issue.severity == MathReleaseIssueSeverity.acceptedFallback,
      )
      .length;
  int get acceptedFallbackCaseCount =>
      cases.where((result) => result.usesAcceptedFallback).length;

  bool get releaseReady => blockerCount == 0;

  Set<MathSubject> get coveredSubjects =>
      cases.map((result) => result.sample.subject).toSet();
}

/// Final Phase 12 release audit for representative mathematical expressions.
///
/// The auditor deliberately distinguishes a release blocker from an accepted
/// safe fallback. A formula can therefore remain releasable even when a
/// particular visual/export surface cannot typeset it natively, provided the
/// source persists exactly and every consumer has a readable, crash-safe route.
class MathReleaseCertificationAuditor {
  final MathCompatibilityService compatibilityService;

  const MathReleaseCertificationAuditor({
    this.compatibilityService = const MathCompatibilityService(),
  });

  MathReleaseCertificationReport certify(
    Iterable<MathReleaseCertificationCase> samples,
  ) {
    final compatibilityAudit = MathCompatibilityAuditor(
      service: compatibilityService,
    ).capture();
    final globalIssues = <MathReleaseCertificationIssue>[];

    if (compatibilityAudit.hasUnsafeCatalogSources) {
      globalIssues.add(
        MathReleaseCertificationIssue(
          code: MathReleaseIssueCode.catalogUnsafeSource,
          severity: MathReleaseIssueSeverity.critical,
          caseId: 'catalog',
          message:
              'Canonical catalogue contains unsafe source IDs: ${compatibilityAudit.syntaxInvalidIds.join(', ')}.',
        ),
      );
    }

    final results = <MathReleaseCaseResult>[];
    for (final sample in samples) {
      results.add(_certifyCase(sample));
    }

    return MathReleaseCertificationReport(
      catalogSemanticCount: MathSymbolCatalog.canonicalSymbols.length,
      cases: List.unmodifiable(results),
      globalIssues: List.unmodifiable(globalIssues),
    );
  }

  MathReleaseCaseResult _certifyCase(MathReleaseCertificationCase sample) {
    final expression = MathExpression(
      id: sample.id,
      latex: sample.latex,
      plainText: sample.plainText,
    );
    final restored = MathExpression.fromJson(expression.toJson());
    final compatibility = compatibilityService.inspectSource(
      sample.latex,
      plainFallback: sample.plainText,
    );
    final issues = <MathReleaseCertificationIssue>[];

    if (restored.id != expression.id ||
        restored.latex != expression.latex ||
        restored.plainText != expression.plainText ||
        restored.display != expression.display ||
        restored.formatVersion != expression.formatVersion) {
      issues.add(
        _issue(
          sample,
          MathReleaseIssueCode.persistenceMismatch,
          MathReleaseIssueSeverity.critical,
          'Canonical MathExpression JSON round-trip changed formula identity or source.',
        ),
      );
    }

    if (!compatibility.syntaxValid) {
      issues.add(
        _issue(
          sample,
          MathReleaseIssueCode.syntaxInvalid,
          MathReleaseIssueSeverity.critical,
          compatibility.syntaxMessage ??
              'Formula source is syntactically unsafe.',
        ),
      );
    }

    if (compatibility.readableFallback.trim().isEmpty) {
      issues.add(
        _issue(
          sample,
          MathReleaseIssueCode.missingReadableFallback,
          MathReleaseIssueSeverity.high,
          'Formula has no readable fallback for screen-reader or safe-failure output.',
        ),
      );
    }

    if (compatibility.resourceLimited) {
      issues.add(
        _issue(
          sample,
          MathReleaseIssueCode.resourceLimited,
          MathReleaseIssueSeverity.medium,
          compatibility.resourceMessage ??
              'Formula exceeds native production-processing budgets.',
        ),
      );
    }

    switch (compatibility.visualEditor.support) {
      case MathCompatibilitySupport.native:
        break;
      case MathCompatibilitySupport.sourceOnly:
      case MathCompatibilitySupport.fallback:
        issues.add(
          _issue(
            sample,
            MathReleaseIssueCode.visualSourceOnly,
            MathReleaseIssueSeverity.acceptedFallback,
            'Visual editor uses Advanced Source or a readable fallback for this expression.',
          ),
        );
      case MathCompatibilitySupport.unsupported:
        issues.add(
          _issue(
            sample,
            MathReleaseIssueCode.visualSourceOnly,
            MathReleaseIssueSeverity.high,
            'Expression has no usable authoring route.',
          ),
        );
    }

    _classifySurface(
      sample: sample,
      surface: compatibility.screenRenderer,
      unavailableCode: MathReleaseIssueCode.screenUnavailable,
      fallbackCode: MathReleaseIssueCode.screenFallback,
      unavailableSeverity: MathReleaseIssueSeverity.critical,
      issues: issues,
    );
    _classifySurface(
      sample: sample,
      surface: compatibility.pdfExport,
      unavailableCode: MathReleaseIssueCode.pdfUnavailable,
      fallbackCode: MathReleaseIssueCode.pdfFallback,
      unavailableSeverity: MathReleaseIssueSeverity.high,
      issues: issues,
    );
    _classifySurface(
      sample: sample,
      surface: compatibility.wordExport,
      unavailableCode: MathReleaseIssueCode.wordUnavailable,
      fallbackCode: MathReleaseIssueCode.wordFallback,
      unavailableSeverity: MathReleaseIssueSeverity.high,
      issues: issues,
    );

    return MathReleaseCaseResult(
      sample: sample,
      compatibility: compatibility,
      issues: List.unmodifiable(issues),
    );
  }

  void _classifySurface({
    required MathReleaseCertificationCase sample,
    required MathSurfaceCompatibility surface,
    required MathReleaseIssueCode unavailableCode,
    required MathReleaseIssueCode fallbackCode,
    required MathReleaseIssueSeverity unavailableSeverity,
    required List<MathReleaseCertificationIssue> issues,
  }) {
    if (!surface.isUsable) {
      issues.add(
        _issue(sample, unavailableCode, unavailableSeverity, surface.message),
      );
      return;
    }
    if (surface.support != MathCompatibilitySupport.native) {
      issues.add(
        _issue(
          sample,
          fallbackCode,
          MathReleaseIssueSeverity.acceptedFallback,
          surface.message,
        ),
      );
    }
  }

  MathReleaseCertificationIssue _issue(
    MathReleaseCertificationCase sample,
    MathReleaseIssueCode code,
    MathReleaseIssueSeverity severity,
    String message,
  ) {
    return MathReleaseCertificationIssue(
      code: code,
      severity: severity,
      caseId: sample.id,
      message: message,
    );
  }
}
