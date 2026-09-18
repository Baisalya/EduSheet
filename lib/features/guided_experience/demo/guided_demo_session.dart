import 'package:flutter/foundation.dart';

enum GuidedDemoFeature { createPaper, createSyllabus }

@immutable
class GuidedDemoSession {
  const GuidedDemoSession({
    required this.feature,
    required this.startedAt,
  });

  final GuidedDemoFeature feature;
  final DateTime startedAt;
}
