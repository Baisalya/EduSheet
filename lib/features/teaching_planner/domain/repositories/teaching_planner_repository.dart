import '../models/teaching_planner_workspace.dart';

typedef TeachingPlannerMutation =
    TeachingPlannerWorkspace Function(TeachingPlannerWorkspace current);

abstract interface class TeachingPlannerRepository {
  Future<TeachingPlannerWorkspace> load();

  Future<void> save(TeachingPlannerWorkspace workspace);

  Future<TeachingPlannerWorkspace> update(TeachingPlannerMutation mutation);
}
