import 'package:edusheet/features/pdf/application/paper_style_catalog.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';

class PaperHeaderSuggestion {
  final String label;
  final bool blankLine;

  const PaperHeaderSuggestion(this.label, {this.blankLine = false});
}

/// Teacher-facing metadata suggestions for a style family.
///
/// Profiles never mutate the paper automatically. They only surface useful
/// optional fields in Paper Setup, keeping appearance and document data
/// separate.
class PaperHeaderProfile {
  final List<PaperHeaderSuggestion> optionalFields;

  const PaperHeaderProfile({this.optionalFields = const []});

  static PaperHeaderProfile forTemplate(PaperTemplate template) {
    final preset = PaperStyleCatalog.presetForId(template.id);
    final category = preset?.category ?? switch (template.type) {
      TemplateType.school => PaperStyleCategory.school,
      TemplateType.board => PaperStyleCategory.board,
      TemplateType.college => PaperStyleCategory.college,
      TemplateType.coaching => PaperStyleCategory.coaching,
      TemplateType.kids => PaperStyleCategory.primary,
    };
    switch (category) {
      case PaperStyleCategory.board:
        return const PaperHeaderProfile(
          optionalFields: [
            PaperHeaderSuggestion('Set'),
            PaperHeaderSuggestion('Paper Code'),
            PaperHeaderSuggestion('Roll No', blankLine: true),
          ],
        );
      case PaperStyleCategory.college:
        return const PaperHeaderProfile(
          optionalFields: [
            PaperHeaderSuggestion('Semester'),
            PaperHeaderSuggestion('Course Code'),
            PaperHeaderSuggestion('Paper Code'),
          ],
        );
      case PaperStyleCategory.coaching:
        return const PaperHeaderProfile(
          optionalFields: [
            PaperHeaderSuggestion('Batch'),
            PaperHeaderSuggestion('Set'),
          ],
        );
      case PaperStyleCategory.primary:
        return const PaperHeaderProfile(
          optionalFields: [
            PaperHeaderSuggestion('Student Name', blankLine: true),
            PaperHeaderSuggestion('Date', blankLine: true),
          ],
        );
      case PaperStyleCategory.school:
        return const PaperHeaderProfile(
          optionalFields: [
            PaperHeaderSuggestion('Date', blankLine: true),
            PaperHeaderSuggestion('Student Name', blankLine: true),
            PaperHeaderSuggestion('Roll No', blankLine: true),
          ],
        );
    }
  }
}
