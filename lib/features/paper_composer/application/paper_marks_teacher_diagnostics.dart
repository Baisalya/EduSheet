import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/application/paper_marks_resolver.dart';

/// Teacher-workspace-only interpretation of [PaperMarksSummary].
///
/// This keeps validation language out of the printable paper model. A paper
/// may be under/over assigned while it is being authored, but that information
/// belongs in setup/inspection UI rather than in the student-facing document.
class PaperMarksTeacherDiagnostics {
  final PaperMarksSummary summary;

  const PaperMarksTeacherDiagnostics(this.summary);

  factory PaperMarksTeacherDiagnostics.fromPaper(Paper paper) =>
      PaperMarksTeacherDiagnostics(PaperMarksResolver.summarize(paper));

  bool get hasMismatch => summary.hasMismatch;

  String? get mismatchMessage {
    switch (summary.balance) {
      case PaperMarksBalance.automatic:
      case PaperMarksBalance.balanced:
        return null;
      case PaperMarksBalance.underAssigned:
        return '${PaperMarksResolver.format(summary.difference)} marks are not assigned yet.';
      case PaperMarksBalance.overAssigned:
        return 'Question marks exceed maximum marks by ${PaperMarksResolver.format(summary.difference)}.';
    }
  }

  String get inspectorStatus => mismatchMessage ?? 'Marks balanced';

  String get setupStatus {
    final mismatch = mismatchMessage;
    if (mismatch != null) return mismatch;
    if (summary.declaredMaximumMarks == null) {
      return 'Maximum marks will follow the current question total '
          '(${PaperMarksResolver.format(summary.assignedMarks)}).';
    }
    return 'Question marks match the declared maximum.';
  }
}
