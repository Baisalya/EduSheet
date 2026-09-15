import 'package:edusheet/features/math_keyboard/domain/audit/math_release_certification.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_symbol.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/math_keyboard/universal_math_booklet_corpus.dart';

void main() {
  final samples = universalMathBookletCorpus
      .map(
        (item) => MathReleaseCertificationCase(
          id: item.id,
          title: item.title,
          subject: item.subject,
          latex: item.latex,
          plainText: item.plainText,
        ),
      )
      .toList(growable: false);

  test('universal booklet corpus satisfies the final release certification', () {
    final report = const MathReleaseCertificationAuditor().certify(samples);

    expect(report.catalogSemanticCount, 356);
    expect(report.caseCount, universalMathBookletCorpus.length);
    expect(report.caseCount, greaterThanOrEqualTo(49));
    expect(report.coveredSubjects, containsAll(MathSubject.values));
    expect(report.criticalCount, 0);
    expect(report.highCount, 0);
    expect(report.blockerCount, 0);
    expect(report.releaseReady, isTrue);

    for (final result in report.cases) {
      expect(
        result.hasBlocker,
        isFalse,
        reason:
            '${result.sample.id}: ${result.issues.map((issue) => issue.message).join(' | ')}',
      );
      expect(result.compatibility.screenRenderer.isUsable, isTrue);
      expect(result.compatibility.pdfExport.isUsable, isTrue);
      expect(result.compatibility.wordExport.isUsable, isTrue);
      expect(result.compatibility.readableFallback.trim(), isNotEmpty);
    }
  });

  test(
    'safe fallbacks are visible and non-blocking rather than hidden gaps',
    () {
      final report = const MathReleaseCertificationAuditor().certify(samples);
      final accepted = report.issues
          .where(
            (issue) =>
                issue.severity == MathReleaseIssueSeverity.acceptedFallback,
          )
          .toList(growable: false);

      expect(report.blockerCount, 0);
      expect(accepted, isNotEmpty);
      expect(
        accepted.every((issue) => issue.message.trim().isNotEmpty),
        isTrue,
      );
      expect(accepted.every((issue) => issue.caseId.trim().isNotEmpty), isTrue);
    },
  );

  test(
    'release severity contract keeps accepted fallbacks out of blocker count',
    () {
      const accepted = MathReleaseCertificationIssue(
        code: MathReleaseIssueCode.pdfFallback,
        severity: MathReleaseIssueSeverity.acceptedFallback,
        caseId: 'sample',
        message: 'Readable fallback is available.',
      );
      const blocker = MathReleaseCertificationIssue(
        code: MathReleaseIssueCode.persistenceMismatch,
        severity: MathReleaseIssueSeverity.critical,
        caseId: 'sample',
        message: 'Persistence changed the expression.',
      );

      expect(accepted.blocksRelease, isFalse);
      expect(blocker.blocksRelease, isTrue);
    },
  );
}
