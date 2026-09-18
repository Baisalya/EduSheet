import 'package:flutter/foundation.dart';

import 'guide_definition.dart';

@immutable
class GuideCatalogEntry {
  const GuideCatalogEntry({
    required this.title,
    required this.description,
    required this.definition,
  });

  final String title;
  final String description;
  final GuideDefinition definition;
}
