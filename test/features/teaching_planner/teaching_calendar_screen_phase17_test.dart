import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_capabilities.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/teaching_calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [
    Size(360, 800),
    Size(412, 915),
    Size(900, 700),
    Size(1366, 768),
  ]) {
    testWidgets(
      'teaching calendar has no overflow at ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              teachingPlannerRepositoryProvider.overrideWithValue(
                _MemoryRepository(),
              ),
              teachingPlannerCapabilitiesProvider.overrideWithValue(
                TeachingPlannerCapabilities.pro(),
              ),
            ],
            child: const MaterialApp(home: TeachingCalendarScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Teaching Calendar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _MemoryRepository implements TeachingPlannerRepository {
  TeachingPlannerWorkspace workspace = TeachingPlannerWorkspace.empty();
  @override
  Future<TeachingPlannerWorkspace> load() async => workspace;
  @override
  Future<void> save(TeachingPlannerWorkspace workspace) async =>
      this.workspace = workspace;
  @override
  Future<TeachingPlannerWorkspace> update(
    TeachingPlannerMutation mutation,
  ) async {
    workspace = mutation(workspace);
    return workspace;
  }
}
