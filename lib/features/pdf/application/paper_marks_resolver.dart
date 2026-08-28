import 'package:edusheet/features/editor/domain/models/paper_model.dart';

enum PaperMarksBalance { automatic, balanced, underAssigned, overAssigned }

class PaperMarksSummary {
  final double assignedMarks;
  final double effectiveMaximumMarks;
  final double? declaredMaximumMarks;
  final PaperMarksBalance balance;
  final double difference;

  const PaperMarksSummary({
    required this.assignedMarks,
    required this.effectiveMaximumMarks,
    required this.declaredMaximumMarks,
    required this.balance,
    required this.difference,
  });

  bool get hasMismatch =>
      balance == PaperMarksBalance.underAssigned ||
      balance == PaperMarksBalance.overAssigned;

  String? get teacherMessage {
    switch (balance) {
      case PaperMarksBalance.automatic:
      case PaperMarksBalance.balanced:
        return null;
      case PaperMarksBalance.underAssigned:
        return '${PaperMarksResolver.format(difference)} marks are not assigned yet.';
      case PaperMarksBalance.overAssigned:
        return 'Question marks exceed maximum marks by ${PaperMarksResolver.format(difference)}.';
    }
  }
}

class PaperMarksResolver {
  const PaperMarksResolver._();

  static double effectiveMaximumMarks(Paper paper) =>
      paper.maximumMarks ?? paper.totalMarks;

  static String format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  static PaperMarksSummary summarize(Paper paper) {
    final assigned = paper.totalMarks;
    final declared = paper.maximumMarks;
    if (declared == null) {
      return PaperMarksSummary(
        assignedMarks: assigned,
        effectiveMaximumMarks: assigned,
        declaredMaximumMarks: null,
        balance: PaperMarksBalance.automatic,
        difference: 0,
      );
    }

    final delta = declared - assigned;
    final balance = delta.abs() < 0.0001
        ? PaperMarksBalance.balanced
        : delta > 0
        ? PaperMarksBalance.underAssigned
        : PaperMarksBalance.overAssigned;
    return PaperMarksSummary(
      assignedMarks: assigned,
      effectiveMaximumMarks: declared,
      declaredMaximumMarks: declared,
      balance: balance,
      difference: delta.abs(),
    );
  }
}
