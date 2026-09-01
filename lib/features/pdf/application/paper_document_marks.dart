import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/application/paper_marks_resolver.dart';

/// Student/print-facing marks presentation.
///
/// Document surfaces (Flutter preview, PDF and Word) should use this adapter
/// instead of rebuilding marks labels independently. Teacher-only diagnostics
/// such as assigned-vs-declared mismatches deliberately live outside this
/// layer in the paper-composer application package.
abstract final class PaperDocumentMarks {
  static double maximumMarks(Paper paper) =>
      PaperMarksResolver.effectiveMaximumMarks(paper);

  static String maximumMarksValue(Paper paper) =>
      PaperMarksResolver.format(maximumMarks(paper));

  static String maximumMarksLabel(Paper paper) =>
      'Maximum Marks: ${maximumMarksValue(paper)}';
}
