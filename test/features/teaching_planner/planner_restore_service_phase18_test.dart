import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'restoreWorkspace delegates canonical replacement to repository save',
    () async {
      final repo = _MemoryRepository();
      final service = TeachingPlannerService(repo);
      final replacement = TeachingPlannerWorkspace.empty();
      final result = await service.restoreWorkspace(replacement);
      expect(identical(result, replacement), isTrue);
      expect(identical(repo.workspace, replacement), isTrue);
      expect(repo.saveCount, 1);
    },
  );
}

class _MemoryRepository implements TeachingPlannerRepository {
  TeachingPlannerWorkspace workspace = TeachingPlannerWorkspace.empty();
  int saveCount = 0;

  @override
  Future<TeachingPlannerWorkspace> load() async => workspace;

  @override
  Future<void> save(TeachingPlannerWorkspace workspace) async {
    saveCount += 1;
    this.workspace = workspace;
  }

  @override
  Future<TeachingPlannerWorkspace> update(
    TeachingPlannerMutation mutation,
  ) async {
    workspace = mutation(workspace);
    return workspace;
  }
}
