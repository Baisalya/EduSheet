import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/guide_catalog_entry.dart';
import '../guides/create_paper_guide.dart';
import '../guides/create_syllabus_guide.dart';

/// Completed feature guides available for replay from Settings.
///
/// Only feature guides with completed real-control integrations are registered.
final guideCatalogProvider = Provider<List<GuideCatalogEntry>>(
  (ref) => <GuideCatalogEntry>[
    GuideCatalogEntry(
      title: 'Create Paper guide',
      description: 'Setup, questions, Math/Geometry, Question Bank, preview and export.',
      definition: createPaperGuideDefinition,
    ),
    GuideCatalogEntry(
      title: 'Planner & Syllabus guide',
      description: 'Set up a class, subject and chapter, then learn the syllabus flow inside Teaching Planner.',
      definition: createSyllabusGuideDefinition,
    ),
  ],
);
