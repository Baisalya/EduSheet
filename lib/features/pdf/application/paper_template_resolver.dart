import 'package:edusheet/features/pdf/application/paper_style_catalog.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';

/// One resolution policy for editor preview, PDF, Word and saved papers.
class PaperTemplateResolver {
  const PaperTemplateResolver._();

  static PaperTemplate resolve(
    String? requestedId,
    Iterable<PaperTemplate> available,
  ) {
    final templates = available.toList(growable: false);
    if (requestedId != null && requestedId.trim().isNotEmpty) {
      for (final template in templates) {
        if (template.id == requestedId) return template;
      }
    }

    for (final template in templates) {
      if (template.id == PaperStyleCatalog.defaultTemplateId) return template;
    }

    final builtInDefault = PaperStyleCatalog.presets
        .firstWhere(
          (preset) => preset.template.id == PaperStyleCatalog.defaultTemplateId,
        )
        .template;
    return builtInDefault;
  }
}
