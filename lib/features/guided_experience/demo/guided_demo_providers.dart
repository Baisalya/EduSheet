import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'guided_demo_session.dart';
import 'in_memory_paper_repository.dart';
import 'in_memory_teaching_planner_repository.dart';

final demoPaperRepositoryProvider = Provider<InMemoryPaperRepository>((ref) {
  return InMemoryPaperRepository();
});

final demoTeachingPlannerRepositoryProvider =
    Provider<InMemoryTeachingPlannerRepository>((ref) {
      return InMemoryTeachingPlannerRepository();
    });

bool isPaperDemoActive(GuidedDemoSession? session) =>
    session?.feature == GuidedDemoFeature.createPaper;

bool isSyllabusDemoActive(GuidedDemoSession? session) =>
    session?.feature == GuidedDemoFeature.createSyllabus;
